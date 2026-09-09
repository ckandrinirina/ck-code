---
name: guide
description: Use when unsure which ck-code step or skill to run. No argument recommends the next workflow step from project state; a free-text task description routes to the best-fit skill (naming any missing prerequisite); `--command [name]` looks up command syntax. Read-only — recommends the command, never launches it.
argument-hint: "[task description | --command [name]]"
effort: low
model: haiku
context: fork
agent: Explore
background: false
allowed-tools: Bash(ck-view*) Bash(ls*) Bash(git branch*) Bash(git status*)
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

## VERSION GATE (hint only)

Read `tasks/VERSION.md`. If `layout: v6` → proceed silently. Otherwise emit one line —
`ℹ pre-v6 layout — run /ck-code:migrate` — and **continue read-only**. Never block. See
[`../../references/version-gate.md`](../../references/version-gate.md).

## The Ready rule

The single dependency-resolution rule shared with `track` (stated here once; `track`
references it). A story is **READY** iff:

- its `status` is `todo` **AND** every id in `blocked_by` resolves to `done` in
  `STORIES_INDEX.md`; **OR**
- its `status` is `bug` — a triaged bug from `/ck-code:fix` is always actionable
  (`build` implements its recorded fix in Bug-Fix Mode). Surface it distinctly (🐛).

Anything else (`todo` with an unmet dependency, `in-progress`, `done`, `skip`) is
**not ready**.

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
table this skill has always used, now implemented once in `scripts/ck-view.sh` instead of
re-derived per run. It **writes nothing** (unlike the other `ck-view` modes it never
regenerates an index), which is what keeps this skill read-only.

It prints the rendered `## ck-code: project state` table, then three machine lines:

```
FLAGS: specs=2 architecture=1 team_skills=7 tasks=1 indexes=1 ds_linked=0 ds_pending=1
COUNTS: ready=4 bug=1 blocked=2 in_progress=1 done=12 unshipped=1 in_review=2 merged=9
RECOMMEND: /ck-code:track next
WHY: 1 open bug(s) — a diagnosed bug outranks new work (Bug-Fix Mode)
```

**Never re-derive `RECOMMEND`.** Do not read `STORIES_INDEX.md`, `FEATURE_INDEX.md` or any
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

Pick the **single best** fit; if two are plausible, the higher row wins and the other
becomes the "Alternative".

| The user is describing… | Recommend |
|---|---|
| Aligning stakeholders, a non-technical spec, "what should this feature do" | `/ck-code:spec` |
| Architecture, tech choices, "how should this be built", data/flow design | `/ck-code:design` |
| Architecture docs are bloated or stale and need slimming/refreshing | `/ck-code:design optimize` |
| Tailoring expert/guide skills, or capturing the project's house conventions | `/ck-code:team` |
| Breaking work into epics, stories, a roadmap; "plan the project/feature" | `/ck-code:plan` |
| Adding one small story or a quick tweak to an existing plan | `/ck-code:plan --quick` |
| Project status, progress, "which story is next" | `/ck-code:track` |
| Implementing a story that already exists | `/ck-code:build` |
| Building several independent ready stories at once | `/ck-code:build <ids>` |
| A bug, crash, regression, "something is broken" in built code | `/ck-code:fix` |
| Committing, opening a PR, publishing to GitHub Issues, "ship it", delivering work | `/ck-code:ship` |
| Explaining what was just built or how to verify it | `/ck-code:explain` |
| Something is wrong with the project itself — stale indexes, a story that vanished, "why is this broken" | `/ck-code:doctor` |
| Setting up or changing issue tracking, the GitHub Project board, or board columns | `/ck-code:config` |
| The project is on an old (pre-v6) layout and needs upgrading | `/ck-code:migrate` |
| "I don't have a task — just tell me what's next" | run `/ck-code:guide` with no argument (Mode A) |

If nothing matches, say so plainly and point to Mode A (state routing) or
`--command` (full command list). Never invent a skill not in this table.

### B.2 Prerequisite check (only for `build` / `plan --quick` / `plan` / `team` / `ship` / `fix`)

A recommendation is wrong if its prerequisite is missing. Probe read-only, then adjust:

```bash
echo "== architecture =="; find docs/architecture -name '*.md' 2>/dev/null | head -1
echo "== tasks =="; ls -d tasks/*/ 2>/dev/null | head -1
echo "== indexes =="; ls tasks/FEATURE_INDEX.md 2>/dev/null
```

First matching rule:

| Intent | If… | Recommend instead (prerequisite first) |
|---|---|---|
| `build` / `plan --quick` | no `tasks/` plan exists | `/ck-code:plan` (then build) |
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
- **Never** write, edit, or generate any file (including running `ck-index`) —
  Bash is for read-only probes only.
- **Never** reference retired skills (`start`, `advise`, `help`, `sync`,
  `doc-optimizer`, `quick-story`, `to-issues`, `pre-spec`, `convention`,
  `parallel-build`) — route only to the current roster in
  [`../../references/workflow-map.md`](../../references/workflow-map.md).
- **Never** duplicate the workflow graph or misuse matrix — route against `workflow-map.md`.
- **Always** apply the Mode A / Mode B tables top-to-bottom; the first match wins.
- **Always** name the prerequisite when a routed skill has an unmet one (Mode B.2).
- **Always** print the state table in Mode A, even when the recommendation is obvious.
- **Always** output in English.
