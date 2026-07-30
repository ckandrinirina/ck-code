# Subagent Fan-Out — shared dispatch contract

How a ck-code skill dispatches a **team of parallel subagents**, each digging into one
independent unit, then converges the results. Skills reference this file instead of
redefining the pattern. The per-story execution variant lives in
[`../skills/build/references/agent-prompts.md`](../skills/build/references/agent-prompts.md);
this doc covers the generic case (read-only investigation **and** independent-artifact writes).

A fan-out this file already sanctions may optionally be *executed* as a scripted `Workflow` —
opt-in only, and never a new fan-out: see [`dynamic-workflows.md`](dynamic-workflows.md).

## When fan-out helps (and when it hurts)

Fan out only when **all** of these hold:

- **Independent** — units do not read each other's in-progress output; order doesn't matter.
- **Numerous** — at or above the skill's threshold. **The default threshold is 3 units**;
  a skill states its own only when it differs. Below it, stay sequential.
- **Non-interactive** — the unit's work needs no user prompt (subagents cannot ask the user).

Do **not** fan out sequential chains (TDD red→green→refactor), stateful/ordered writes
(git, GitHub issue links, numbered epics), cheap reads, or any step that prompts the user.

## The decision-first rule (non-negotiable)

**The dispatch decision is made BEFORE the first unit is produced, never after.** A step that
produces N independent units opens by counting them and branching — dispatch or inline — and
only then does any work. A fan-out described as a follow-on sub-step to an inline "write each
one" instruction is dead on arrival: read top to bottom, everything is already written by the
time the fan-out is reached, and it applies to zero remaining units.

So write the step as **count → branch → produce**, and never as **produce → (also, you could
have parallelized)**. Any skill hosting a fan-out states it in that order and names the
fan-out in its HARD GATES or RULES, so a silent skip is a gate failure rather than an
invisible one.

## The two variants

| Variant                       | Subagent does                                             | `model`                | `isolation`                                              | Writes?              |
| ----------------------------- | --------------------------------------------------------- | ---------------------- | -------------------------------------------------------- | -------------------- |
| **Investigation** (read-only) | Greps/reads/traces one slice, returns a typed schema      | `haiku`                | `none`                                                   | Never — reports only |
| **Artifact** (write)          | Produces ONE file in its own dedicated path               | `sonnet`               | `none` (or `worktree` only if units touch shared source) | Its own path only    |

## Prefer structured-output returns (typed schema, not a prose brief)

Every subagent returns a **typed schema** the orchestrator reads by field — not a text
brief it parses with regex. Define the return shape in the dispatch prompt (e.g.
`status`, `findings: [...]`, `path`, `remaining: [...]`) and collect fields, never
sentences. A schema return is machine-checkable — a missing or malformed field is caught
at collection instead of silently mis-parsed — and it keeps the orchestrator's context
lean because it never re-reads the subagent's working prose. The v3 "return a brief the
orchestrator scans" convention is replaced: state the schema, require the schema, read the
schema. This applies to every registered ck-code agent too — `story-implementer` returns
`{status, branch, commits, remaining, criteria_met}`, `qa-validator` returns a
`QA: PASS/FAIL` verdict line, `conflict-analyzer` returns `{order, report[]}`.

## Model tier (pass `model:` on every dispatch)

Match the model to the *reasoning* the unit needs, never to the unit's size. `model:` accepts
only these four literal aliases — a tier name like `balanced` is an invalid value:

- **`haiku`** — mechanical work: grep/trace/count, path extraction, token measurement,
  classifying output against fixed criteria. No design judgment.
- **`fable`** — the same mechanical shape, when the unit has enough steps or enough
  formatting constraints that `haiku` starts dropping them. Cheaper than `sonnet`.
- **`sonnet`** — filling a frozen template from an already-resolved slice of context.
  Fidelity to the input matters; the structure is given.
- **`opus`** — escalate here only when the unit itself must *decide* something the
  orchestrator could not pre-resolve: a novel algorithm, a security-sensitive trade-off, an
  ambiguous requirement. Escalation is the exception; state why in the dispatch prompt.

Omitting `model:` makes the subagent inherit the orchestrator's tier — the most expensive
model in play — for work that rarely needs it. Never omit it.

## The orchestrator-owns-shared-writes rule (non-negotiable)

The orchestrator (the skill thread) — never a subagent — does all of:

- **User interaction** — every prompt, confirmation, and refinement runs to completion
  _before_ dispatch and _after_ collection. Subagents get already-resolved context.
- **Shared writes** — in v5 the story-status indexes (`STORIES_INDEX.md`,
  `FEATURE_INDEX.md`) are **generated views**, so a shared-index write means running
  `ck-index` **once, in the orchestrator**, after it has
  merged the subagents' work and the story frontmatter is settled — never a subagent editing
  an index cell (see [`data-model.md`](data-model.md)). The stamp `tasks/VERSION.md`,
  `_shared.md`, and any append-target singleton are likewise authored/merged only by the
  orchestrator. A subagent writes only files unique to its own unit (its own story
  frontmatter, its own artifact path) and never runs the generator.
- **The version gate** — runs once, in the orchestrator (see [`version-gate.md`](version-gate.md)). Subagents never re-run or re-stamp it.
- **Convergence** — merging reports, resolving contradictions to a single decision, and the
  final summary stay with the orchestrator.

So before dispatch: finish all prompts, author every shared/global file (freeze `_shared.md`),
then pass each subagent its slice as **read-only** context. Generated indexes are the
exception — they are not authored up front; the orchestrator regenerates them once with
`ck-index` after convergence, when the merged story frontmatter is final.

## Dispatch shape

1. **Gate** — count the units and check the skill's threshold (default 3; also unit size and
   mode). Decide here, before producing anything. Below the threshold → inline, no fan-out.
2. **Freeze shared state** — author globals/`_shared.md`; finish user prompts. (Do NOT
   pre-author generated indexes — those are regenerated once at convergence.)
3. **Dispatch** — one `Agent` call per unit, in a single message so they run concurrently.
   Use `subagent_type: general-purpose` unless a registered ck-code agent fits the unit, and
   set `model:` from the tier table above. Give each: its unit id, its slice of frozen
   context, its template reference, the **return schema** it must fill, and an explicit
   "write only `<your path>`; do not prompt; do not touch shared files or run the generator"
   constraint.
4. **Collect** — gather every subagent's typed return by field; a failed/empty agent (a
   missing or malformed schema) is recovered or redone inline by the orchestrator, never left
   silently missing.
5. **Converge** — merge into shared files, resolve conflicts, verify each unit landed, then
   regenerate the indexes with `ck-index` once, and summarize.

## Announce + report

**Announcing the decision is mandatory, in both directions.** Print one line stating the
count, the threshold, and the branch taken — before any unit is produced:

```
Fan-out: 6 units ≥ 3 → dispatching 6 agents.      # or
Fan-out: 2 units < 3 → writing inline.
```

Then a one-line-per-unit launch announcement (informational, not a second gate — the
decision already happened at the skill's own confirmation step) and a result roster on
collection, mirroring
[`build/references/agent-prompts.md`](../skills/build/references/agent-prompts.md).
Never silently imply the whole set was parallelized, and never let a below-threshold run
pass without saying so — an unannounced decision is indistinguishable from a forgotten one.
