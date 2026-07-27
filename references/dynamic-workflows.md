# Dynamic Workflows — scripted execution backend for a sanctioned fan-out

When a skill runs a fan-out that [`subagent-fanout.md`](subagent-fanout.md) **already sanctions**,
the `Workflow` tool can execute it as a deterministic JS script instead of a one-message `Agent`
dispatch. This file is the shared contract; skills link it instead of restating the mechanics.

## Positioning — a backend, never a new fan-out

`Workflow`'s `parallel()` buys **nothing** over ck-code's existing dispatch: a single message of
`Agent` calls already runs concurrently. Adopt it only for the three things it adds:

| Delta | What it replaces |
|---|---|
| **Enforced schema** — subagent must call `StructuredOutput`, validated at the tool layer | a prose key list a subagent can silently violate |
| **Deterministic retry** — a scripted loop over the units that came back empty | "the orchestrator re-runs failed units inline" (model discretion, and it re-pays verbose output into orchestrator context) |
| **Resume** — `resumeFromRunId` replays the unchanged prefix from cache | a dead session re-paying the whole fan-out |

Everything in `subagent-fanout.md` still binds unchanged: the gate/freeze/dispatch/collect/converge
shape, the model-tier table, and **orchestrator-owns-shared-writes**.

**Adopt only where all five hold.** Large (well above the skill's own inline threshold), expensive
or network-dependent per unit, non-interactive, costly to lose halfway, and writing nothing shared.
Miss one → plain `Agent` fan-out.

## The opt-in gate

Calling `Workflow` can spend a large amount of the user's tokens, so a skill may reach for it only
when **all three** hold:

1. **Tool present** — `Workflow` is in your tool list this session. It is not in every build. If
   absent, take the inline path silently; never announce a workflow you cannot run.
2. **Explicit user signal** — `--workflow` in `$ARGUMENTS`, session-wide ultracode, or the user
   asking for it in their own words.
3. **Unit count above the skill's workflow threshold** — strictly higher than that skill's
   existing inline fan-out threshold, so the workflow path stays the exception.

**Never add an `AskUserQuestion` for this.** When 1 and 3 hold but the signal is absent, print one
hint line and proceed on the normal path:

```
18 technologies detected — /ck-code:team --workflow runs this research as a resumable background workflow.
```

That makes a silent 15-agent fan-out impossible and teaches the flag exactly when it pays.

**Announce around the call.** Before: unit count, model tier, agent count. After: the run id and
that results arrive as a task notification (the run is backgrounded, so the per-unit launch roster
the inline path streams is not visible while it runs).

## Fallback — the workflow path is never the only path

Adopting skills **keep their existing fan-out prose intact and add a branch, not a replacement.**
If the gate fails, if the run returns `null` for a unit, or if the script reports unresolved units,
the orchestrator recovers those units inline exactly as `subagent-fanout.md` step 4 already
requires. A partially-failed workflow is never left silently short.

## Script rules

Stated once here so no `SKILL.md` repeats them.

- **Shape** — `export const meta = {name, description, phases: [...]}` (a **pure literal**), then the
  body at top level. `agent`, `parallel`, `pipeline`, `log`, `phase`, `args`, `budget` are
  **globals**, not injected parameters — there is no `export default function`.
- **Plain JS, sandboxed** — no TypeScript annotations, no filesystem, no Bash, no Node APIs in the
  script body. `Date.now()`, `Math.random()`, and argless `new Date()` **throw**. Subagents still
  have full tools; only the script body is sandboxed.
- **Every `agent()` call passes `{label, model, schema}`.** The schema is the entire point over
  today's prose convention; the model tier comes from `subagent-fanout.md`.
- **No user interaction anywhere inside a script.** Every prompt, confirmation, and gate runs to
  completion in the orchestrator before the call, or after it. A gate between two fan-outs means
  **two separate `Workflow` calls**, never one fused script.
- **No shared or generated writes from a script's subagent** — `ck-index.sh`, `_shared.md`,
  `tasks/VERSION.md`, README index rows stay orchestrator-owned. A write subagent touches only its
  own unique path.
- **Cap every retry loop** (3 rounds) and `log()` each round, so the journal shows what was retried.
- **The script returns data only** — the orchestrator converges, merges, and summarizes.

## Resume never re-writes — verify against disk (verified)

`resumeFromRunId` replays a cached `agent()` result **without re-dispatching**, including for
agents that wrote files. Measured directly: a write agent's file was deleted between runs, the
resume returned its cached `{written: true, lines: 3}` unchanged, and the file was still missing.

**A resumed manifest is a claim, never proof.** For any fan-out that writes, the orchestrator's
verification step must `ls` the real paths and regenerate inline anything the manifest claims but
disk does not have. This is why the write variant keeps a central verify step.

## What a script's subagent actually gets (verified)

- **`$CLAUDE_PLUGIN_ROOT` is EMPTY.** Every path in a dispatch prompt must be **absolute** or
  repo-relative — a `${CLAUDE_PLUGIN_ROOT}/…` reference resolves to nothing and the agent fails
  silently. This is the single most likely authoring mistake.
- **Directly callable:** `Read`, `Write`, `Edit`, `Bash`, `Skill`, `ToolSearch`. Repo reads work.
- **`Skill` works** — a namespaced plugin skill (`ck-tools:bmad-guide`) loads normally, so a
  subagent can pull in a plugin reference instead of having it inlined.
- **`WebSearch`, `WebFetch`, and every `mcp__*` tool (including context7) are DEFERRED** — visible
  by name only. A prompt that needs them MUST say so explicitly:

  ```
  First run ToolSearch with query "select:WebSearch,mcp__context7__resolve-library-id,mcp__context7__query-docs"
  to load the schemas, then use them.
  ```

  Omit that line and the agent silently falls back to whatever it has. The `ctx7` CLI fallback in
  [`../skills/team/references/context7-research.md`](../skills/team/references/context7-research.md)
  works too, since `Bash` is available.

## File layout

Each script lives at `ck-code/skills/<skill>/references/<phase>.workflow.md` as exactly **one**
fenced ` ```js ` block. The orchestrator reads it and passes the block verbatim as the inline
`script` parameter, with per-run values in `args`. Keeping scripts as markdown references means
`update-skill` reviews them like any other reference file.
