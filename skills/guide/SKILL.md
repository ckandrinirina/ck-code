---
name: guide
description: Use when unsure which ck-code step or skill to run. No argument recommends the next workflow step from project state; a free-text task description routes to the best-fit skill (naming any missing prerequisite); `--command [name]` looks up command syntax. Read-only — recommends the command, never launches it.
argument-hint: "[task description | --command [name]]"
effort: low
context: fork
background: false
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

Read `tasks/VERSION.md`. If `layout: v5` → proceed silently. Otherwise emit one line —
`ℹ pre-v5 layout — run /ck-code:migrate` — and **continue read-only**. Never block. See
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

---

## MODE A — STATE ROUTING (no argument)

### A.1 Probe project state (read-only)

Run once, in parallel; record what each block shows:

```bash
echo "== specs =="; ls -d docs/specs/*/ 2>/dev/null | head -5
echo "== architecture =="; find docs/architecture -name '*.md' 2>/dev/null | head -3
echo "== team skills =="; ls -d .claude/skills/expert-*/ .claude/skills/guide-*/ 2>/dev/null | head -3
echo "== tasks =="; ls -d tasks/*/ 2>/dev/null | head -5
echo "== feature index =="; ls tasks/FEATURE_INDEX.md 2>/dev/null
echo "== stories index =="; ls tasks/*/STORIES_INDEX.md 2>/dev/null | head -5
echo "== version =="; head -5 tasks/VERSION.md 2>/dev/null
```

Derive: `has_specs`, `has_architecture`, `has_team_skills`, `has_tasks`,
`has_indexes` (a `FEATURE_INDEX.md` **and** at least one `STORIES_INDEX.md`).

### A.2 Story status snapshot (only if `has_indexes`)

Read each `tasks/*/STORIES_INDEX.md` (the generated view — never glob story files) and
count rows by the `Status` column, applying **The Ready rule**:

- `n_ready` — `todo` and every `Blocked by` id is `done`
- `n_bug` — `bug`
- `n_blocked` — `todo` with an unmet `Blocked by`
- `n_in_progress` — `in-progress`
- `n_done` — `done`

Do **not** run `ck-index.sh` here (this skill writes nothing). If `tasks/` exists but
`has_indexes` is false, the views just need regenerating — row 5 below routes to `track`.

### A.3 Recommend

First matching row wins; print only that recommendation.

| State | Recommend |
|---|---|
| `!has_architecture && !has_specs` | **`/ck-code:spec "<feature description>"`** — start with a stakeholder-friendly spec; or skip to `/ck-code:design <spec-file>` if you already have a written spec. |
| `!has_architecture` | **`/ck-code:design <spec-file>`** — refine the spec into architecture docs. |
| `has_architecture && !has_team_skills` | **`/ck-code:team`** — generate project-tailored expert + guide skills. |
| `has_architecture && has_team_skills && !has_tasks` | **`/ck-code:plan <spec-file>`** — break the architecture into epics, stories, and a roadmap. |
| `has_tasks && !has_indexes` | **`/ck-code:track`** — regenerates the missing generated views, then re-run `/ck-code:guide`. |
| `n_bug > 0` | **`/ck-code:track next`** → **`/ck-code:build <path>`** — an open bug outranks new work (Bug-Fix Mode). |
| `n_ready > 0` | **`/ck-code:track next`** → **`/ck-code:build [path]`** — implement the next ready story. |
| `n_in_progress > 0 && n_ready == 0` | **`/ck-code:ship <story-path>`** — ship the in-progress story, or **`/ck-code:build`** to keep going. |
| `n_done > 0 && n_ready == 0 && n_in_progress == 0 && n_bug == 0` | **`/ck-code:track progress`** — review the milestone tracker, or plan the next feature with **`/ck-code:plan`** / **`/ck-code:spec`**. |
| `has_tasks && all counts == 0` | **`/ck-code:plan`** appears not to have produced stories — re-check `tasks/<slug>/`. |

Where two ready paths fit and the choice matters (e.g. 3+ independent ready stories),
use **AskUserQuestion** to offer `build <story-path>` (one story, sequential) vs
`build <ids>` / `build --epic NN` (PARALLEL MODE, worktrees) — never launch either.

### A.4 Output format

```
## ck-code: project state

| Check | Value |
|---|---|
| docs/specs/        | <has or — > |
| docs/architecture/ | <has or — > |
| .claude/skills/    | <count of expert-*/guide-* or — > |
| tasks/             | <has or — > |
| generated indexes  | <has or — > |
| Stories            | <n_ready ready · n_bug bug · n_blocked blocked · n_in_progress IP · n_done done> |

## Recommended next step

**`<command>`** — <one-sentence why>

Why this fits: <1–2 sentences tied to the state above>

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
| The project is on an old (pre-v5) layout and needs upgrading | `/ck-code:migrate` |
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

- **Never** invoke another skill via the `Skill` tool — this skill recommends only.
- **Never** write, edit, or generate any file (including running `ck-index.sh`) —
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
