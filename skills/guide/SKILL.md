---
name: guide
description: Use when unsure which ck-code step or skill to run. No argument recommends the next workflow step from project state; a free-text task description routes to the best-fit skill (naming any missing prerequisite); `--command [name]` looks up command syntax. Read-only — recommends the command, never launches it.
argument-hint: "[task description | --command [name]]"
effort: low
model: haiku
context: fork
agent: Explore
background: false
allowed-tools: Bash(ck-view*) Bash(ls*) Bash(find*) Bash(git branch*) Bash(git status*)
disallowed-tools: Write, Edit, NotebookEdit
---

# Guide — ck-code Router (Read-Only)

One arg-aware entry point for "which ck-code thing do I run?". It **recommends and
stops** — it never invokes another skill, writes, or edits state. The full workflow
graph, hand-offs, and misuse-redirect matrix are the single source of truth in
[`../../references/workflow-map.md`](../../references/workflow-map.md); this skill
routes against it and never restates it.

## MODE DISPATCH

Pick the mode from `$ARGUMENTS`, then run only that section:

| `$ARGUMENTS` | Mode | Section |
|---|---|---|
| empty | **State routing** — recommend the next workflow step | A |
| starts with `--command` | **Syntax lookup** — print command reference | C |
| any other text | **Intent routing** — task description → best-fit skill | B |

## VERSION GATE (hint only — Tier 1)

Layout stamp: !`cat "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tasks/VERSION.md" 2>/dev/null || echo "ABSENT — no tasks/VERSION.md"`

Read the injected stamp; never spend a `Read` call on `tasks/VERSION.md`. `layout: v7` →
proceed silently. A newer layout → emit `ℹ newer ck-code layout — update the plugin`;
anything else (older, or `ABSENT` with a `tasks/` folder) → emit
`ℹ older ck-code layout — run /ck-code:migrate`. Then **continue read-only**. Never run
Tier 2, never block, never stamp. See
[`../../references/version-gate.md`](../../references/version-gate.md#scope).

## The Ready rule

The single dependency-resolution rule shared with `track` (stated here once; `track`
references it). A story is **ready** when `status: todo` and every `blocked_by` story is
`done` or `skip`, or when `status: bug`.

- A `bug` story is a triaged bug from `/ck-code:fix` and is always actionable (`build`
  implements its recorded fix in Bug-Fix Mode). Surface it distinctly (🐛).
- An `in-progress` story is not "ready"; `build` may RESUME it when named explicitly.
- Anything else (`todo` with an unmet dependency, `done`, `skip`) is **not ready**.

**Readiness reads `status` only, never `delivery`.** A dependency is satisfied the moment
its work is `done` — waiting for it to reach the trunk would deadlock every epic-level
plan, whose stories merge into an epic branch and never touch the trunk at all
([`../../references/data-model.md`](../../references/data-model.md#two-axes-status-is-work-delivery-is-integration)).

---

## MODE A — STATE ROUTING (no argument)

### A.1 Probe the project (one call)

```bash
ck-view state
```

`ck-view state` is the whole of A.1–A.3: it probes the layout, counts every story row
across every plan applying **The Ready rule** above, and applies the routing table in
[`references/state-routing.md`](references/state-routing.md) — the same first-match-wins
table, implemented once in `scripts/ck-view.sh` instead of re-derived per run. Like every
`ck-view` mode it first regenerates a missing or stale view; the views are gitignored and
disposable, so this touches nothing git tracks and the skill stays read-only.

It prints the rendered `## ck-code: project state` table, then three machine lines:

```
FLAGS: specs=2 architecture=1 team_skills=7 tasks=1 indexes=1 ds_linked=0 ds_pending=1
COUNTS: ready=4 bug=1 blocked=2 in_progress=1 done=12 unshipped=1 in_review=2 merged=9
RECOMMEND: /ck-code:track next
WHY: 1 open bug(s) — a diagnosed bug outranks new work (Bug-Fix Mode)
```

**Never re-derive `RECOMMEND`.** Do not read `STORIES_INDEX.md`, `EPICS_INDEX.md` or any
story file to second-guess a count or pick a different command — the table is mechanical
and the script is its only implementation. Consult
[`references/state-routing.md`](references/state-routing.md) only to *explain* a verdict.

If `ck-view: command not found` appears, the plugin is disabled or predates `bin/ck-view`
— fall back to `"${CLAUDE_PLUGIN_ROOT}"/scripts/ck-view.sh` and say so in one line.

### A.2 Add the judgement the script cannot

Two things stay with the model:

- **The one-sentence "why this fits"** — ground `WHY` in the state the table shows; never
  restate the command back as its own reason.
- **The parallel offer.** When `COUNTS: ready=` is 3 or more and the recommendation is
  `/ck-code:track next`, use **AskUserQuestion** to offer `build <story-path>` (one story,
  sequential) vs `build <ids>` / `build --epic NN` (PARALLEL MODE, worktrees) — never
  launch either.

### A.3 Output format

Relay `ck-view state`'s `## ck-code: project state` table verbatim (drop the `FLAGS:` /
`COUNTS:` / `RECOMMEND:` / `WHY:` lines — they are for you, not the user), then:

```
## Recommended next step

**`<command>`** — <one-sentence why>

Why this fits: <1–2 sentences tied to the state above>

<Only when ds_pending > 0 and not ds_linked — one line, after the recommendation and never
instead of it, because a pending link blocks nothing:
Also pending: a Claude Design brief is waiting — run `/ck-code:design ds <url>` once the
design system is ready at claude.ai/design.>

(Full workflow graph + misuse matrix: references/workflow-map.md.)
```

---

## MODE B — INTENT ROUTING (free-text argument)

`$ARGUMENTS` is a plain-language task. If it is empty here, ask exactly one question —
*"In one or two sentences, what do you want to do?"* — then continue.

### B.1 Classify the intent

Read [`../../references/prompt-routing.md`](../../references/prompt-routing.md) — the
single intent → skill table, the same one the `UserPromptSubmit` hook injects on every
free-text prompt. This skill keeps no copy of it. Apply it with guide's own behaviour, not
the hook's:

- Pick the **single best** fit; the first matching row wins. If a second row is also
  plausible, it becomes the "Alternative" in B.3.
- **Recommend and stop.** The table's "invoke it" instruction is for the main session;
  guide only names the command.
- A task with no work to do ("just tell me what's next") → Mode A.

If nothing matches, say so plainly and point to Mode A (state routing) or
`--command` (full command list). Never invent a skill the table does not name.

### B.2 Prerequisite check (only for `build` / `plan --quick` / `plan` / `team` / `ship` / `fix`)

A recommendation is wrong if its prerequisite is missing. Probe read-only, then adjust:

```bash
find docs/architecture -name '*.md' -print -quit 2>/dev/null
find tasks -mindepth 2 -maxdepth 2 -name OVERVIEW.md -print -quit 2>/dev/null
```

Read the output by path: a `docs/architecture/…` line means the architecture exists, a
`…/OVERVIEW.md` line means a plan exists; a missing one means that prerequisite is missing.

First matching rule:

| Intent | If… | Recommend instead (prerequisite first) |
|---|---|---|
| `build` / `plan --quick` | no `tasks/<plan>/OVERVIEW.md` exists | `/ck-code:plan` (then build) |
| `plan` | no `docs/architecture/` exists | `/ck-code:design` (then plan) |
| `team` | no `docs/architecture/` exists | `/ck-code:design` (then team) |
| `ship` | no implemented work on the branch | `/ck-code:build` or `/ck-code:fix` (then ship) |
| `fix` | the "bug" is actually new functionality | `/ck-code:plan --quick` (add a story), then `build` |

Skip this step for read-only intents (`track`, `explain`, `doctor`, `migrate`, `spec`, `design`).

### B.3 Output

```
## ck-code: what to run

You want to: <one-line restatement of the task>

→ **`<recommended command>`**
  <one-sentence why this skill fits>

Prerequisite: <command + why, or "none — you're ready">
Next step:    <the skill that typically follows, per workflow-map>
Alternative:  <second-best command + when it fits, or omit if unambiguous>
```

No extra prose. The user runs the command themselves.

---

## MODE C — SYNTAX LOOKUP (`--command [name]`)

Read [`references/commands.md`](references/commands.md).

- `--command <name>` → print only that command's table row plus its examples.
- `--command` (no name) → print the whole command table.

If `<name>` is not a current command, say so and list the valid command names.

---

## RULES

- **Never** invoke another skill via the `Skill` tool — this skill runs forked and
  read-only, and an Explore fork has no write tools, so the callee would fail at its first
  file write.
- **Always** end Mode A and Mode B with one directive line and nothing after it, per
  [`../../references/skill-invocation.md`](../../references/skill-invocation.md) —
  `NEXT: /ck-code:<skill> <resolved args>`. The main session offers it as a one-click run,
  so the user never retypes the command this skill just chose for them. Emit none in Mode C
  (syntax lookup), and none when the routing is genuinely ambiguous — list the candidates
  as prose instead.
- **Never** write, edit, or generate any file — Bash is for read-only probes and
  `ck-view`, whose view regeneration touches only gitignored files. Never run `ck-index`
  directly.
- **Never** reference retired skills or flags (`sync`, `start`, `advise`, `help`,
  `doc-optimizer`, `quick-story`, `to-issues`, `pre-spec`, `convention`,
  `parallel-build`, `ship --to-issues`, `ship --integration`) — route only to the current
  roster in
  [`../../references/workflow-map.md`](../../references/workflow-map.md).
- **Never** duplicate the workflow graph or misuse matrix — route against `workflow-map.md`.
- **Never** keep or restate an intent table here — Mode B reads
  [`../../references/prompt-routing.md`](../../references/prompt-routing.md).
- **Always** apply the Mode A / Mode B tables top-to-bottom; the first match wins.
- **Always** name the prerequisite when a routed skill has an unmet one (Mode B.2).
- **Always** print the state table in Mode A, even when the recommendation is obvious.
- **Always** output in English.
