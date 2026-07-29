---
name: build
description: Use when implementing stories from `tasks/` end-to-end with TDD — one story inline, several independent stories at once in isolated worktrees, or a whole epic in dependency-ordered waves. Also implements a `status: bug` story handed off by `/ck-code:fix` (Bug-Fix Mode). Argument is an optional story path, space-separated story IDs, or `--epic NN`; with no argument, picks interactively.
argument-hint: "[story-path] | [story-ids...] | --epic NN"
effort: high
---

# Build — TDD Story Implementation

Implements stories from `tasks/` using Test-Driven Development, SOLID principles, and
automated QA. Cycle: plan → test (RED) → implement (GREEN) → refactor → QA → complete.

**One story** runs inline through Phases 0–8; **more than one** runs through
[PARALLEL MODE](#parallel-mode) (one worktree agent per story, dependency-ordered waves —
every gate below still applies); a `status: bug` story handed off by `/ck-code:fix` runs
in **Bug-Fix Mode** (Phase 1.3.5). Argument shapes: [INPUT](#input).

Story state lives in **story-file YAML frontmatter** (the single source of truth); the index
views are **generated read-only** — this skill changes frontmatter, then regenerates. See [`data-model.md`](../../references/data-model.md).

References: [output-blocks.md](references/output-blocks.md) (compact per-phase present templates) · [examples.md](references/examples.md) (worked dialogues: interactive menu, bug-fix loop) · [tdd-walkthrough.md](references/tdd-walkthrough.md) (SOLID templates, test mappings, quality checks, JUCE rules) · [story-template.md](references/story-template.md) (story-body blocks) · [completion.md](references/completion.md) (Phase 8 summary fields, Files Touched precision, bug-fix sub-loop) · [bug-fix-mode.md](references/bug-fix-mode.md) (implementing a `fix`-recorded bug — per-phase deltas) · [native-commands.md](../../references/native-commands.md) (`/goal`, `/fast`, `/code-review` pairings).

Parallel-mode references, read **only** when two or more stories are in scope: [parallel-mode.md](references/parallel-mode.md) (orchestration detail for P1–P9) · [agent-prompts.md](references/agent-prompts.md) (dispatch/resume prompts, return schema) · [wave-mode.md](references/wave-mode.md) (wave planning) · [conflict-format.md](references/conflict-format.md) (table/integrity/conflict/QA/summary formats).

**Read each reference at most once per run** — `output-blocks.md` and `tdd-walkthrough.md` are cited from many phases; load each once, keep it resident, and reuse it.

## ROUTING CHECK (do first)

This skill **TDD-implements stories** from `tasks/`. If the request is actually
something else, STOP and recommend the better skill:

- An **un-triaged** bug in shipped code → `/ck-code:fix` first (it diagnoses, writes the failing test + Fix Plan, and flips the story to `status: bug`). A story **already at `status: bug`** is triaged — implement it here in Bug-Fix Mode (Phase 1.3.5).
- No story exists for the work yet → `/ck-code:plan` first.

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:ship`.

## INPUT

`$ARGUMENTS` is empty, a story path, space-separated story IDs, or `--epic NN`:

- **A story path** (`tasks/<slug>/epics/02/stories/02-05-*.md`) — build that one story
  inline through Phases 1–8. Validate it before anything else (Phase 1.1).
- **Two or more story IDs** (`02-05 03-01`) — PARALLEL MODE, one wave.
- **`--epic NN`** — PARALLEL MODE over every non-`done` story of that epic, in
  dependency-ordered waves.
- **Empty** — interactive selection (Phase 1.2), which also offers the parallel set and
  whole-epic waves.

A dispatch prompt beginning `MODE: delegated` means this run **is** a worktree agent inside
someone else's parallel run — read [DELEGATED MODE](#delegated-mode) before Phase 1.

---

## PHASE 0: VERSION GATE (hard, before any project read/write)

Read `tasks/VERSION.md`. If it exists and reads `layout: v4` → **PASS**, proceed.
Otherwise run the shared [version gate](../../references/version-gate.md) (HARD GATE) —
it detects a pre-v4 layout, offers `/ck-code:migrate`, and stamps. Never read or write
project state before this PASSes.

---

## PHASE 1: STORY SELECTION

### 1.1 If Story Path Provided

Read the story at `$ARGUMENTS`. Validate its frontmatter (`id`, `title`, `epic`,
`status`, `size`) and that it has a body with Acceptance Criteria. If invalid or missing,
tell the user and stop.

Explicit **story IDs** or `--epic NN` instead of a path skip to
[PARALLEL MODE](#parallel-mode) P1 — resolve each ID against the index there, never here.

### 1.2 If No Story Path (Interactive — index-driven)

**1.2.0 Feature gate (read `tasks/FEATURE_INDEX.md` FIRST).** Before any story index, run
the feature-selection gate in [`feature-index.md`](../../references/feature-index.md) — it
owns the regenerate condition, the unfinished-set rule, and the 0/1/2/>2 branches; do not
restate them here. The chosen feature's `Plan` + `NN` scope the story index read below.
Interactive mode only — explicit `$ARGUMENTS` skips this.

1. Read the chosen feature's `tasks/<Plan>/STORIES_INDEX.md` and filter to its epic `NN`.
   Regenerate first if it is missing or lacks the `GENERATED` header
   ([`stories-index.md`](../../references/stories-index.md)), then re-read.
2. Filter to actionable rows: `Status: TODO` whose every `Blocked by` ID resolves to
   `Status: DONE`, **plus every `Status: BUG` row** (a triaged bug from `/ck-code:fix`,
   always actionable → Bug-Fix Mode). Surface `BUG` rows first with a 🐛 marker — an open
   bug in shipped code outranks new work.
3. Sort by epic, then story number, then size (S < M).
4. **Detect whole-epic options:** group ALL not-`DONE` rows by epic (`NN`); any epic with
   > 1 non-DONE story is a wave candidate.
5. **Detect the parallel-safe set:** if ≥ 2 stories are ready, build a **touched-files map**
   from **only** each ready story's frontmatter `files:` list, in one batched Bash call
   (`awk` one-liner in [examples.md](references/examples.md) § touched-files map) — never a
   full body `Read`, never a glob of all stories. The largest conflict-free group of ≥ 2 is
   the **recommended parallel set** — the preferred default. Keep this map: PARALLEL MODE P2
   reuses it instead of re-reading, and Phase 2 reuses the selected story's `files:` for
   skill matching. Only Phase 1.3 issues a full `Read` (for the one selected story).
6. **Present the menu and route the choice** per [examples.md](references/examples.md):
   recommended parallel set (⚡, when ≥ 2) → epics → single stories. The selection is the
   one confirmation — parallel and epic choices enter [PARALLEL MODE](#parallel-mode) at P1
   with the scope already resolved (P3 does not re-ask which stories); a single story
   proceeds to 1.3 (Phase 1.4 then skips its offer). If none ready, say so + which deps are
   missing (suggest `/ck-code:plan` if the index is empty).

### 1.3 Load Story Context

Once a story is selected, `Read` the full story file — this is the **only** full body
`Read` of the run. From **frontmatter**: `id`, `title`, `epic`, `size`, `blocked_by`,
`files` (the touched-files set Phase 2 matches skills against — from the 1.2 map if it ran),
`issue`, `status`, `prior_status`. From the **body**: `## Description`,
`## Acceptance Criteria`, `## Implementation Tasks` (if present), `## Technical Notes`. Read
these sections as authored prose — never awk-slice headings. Read `ROADMAP.md` ONLY if the
Technical Notes reference it explicitly.

### 1.3.5 Mode Detection — Story vs Bug-Fix

- **Bug-Fix Mode** — frontmatter `status: bug` (fix leaves a `## Bug Report` with
  `Status: DIAGNOSED` and a Fix Plan, and records the pre-bug status in `prior_status`).
  Follow [bug-fix-mode.md](references/bug-fix-mode.md) for the per-phase deltas: the recorded
  **Fix Plan** (not the acceptance criteria) is the work; the failing reproduction test `fix`
  left is the RED target; completion fills the Bug Report **Resolution** and restores
  `prior_status` instead of writing an Implementation Summary. If `status: bug` but there is
  no `DIAGNOSED` Bug Report, STOP — tell the user to run `/ck-code:fix <story>` (the tree
  drifted from diagnosis). Skip the epic-wave offer (1.4).
- **Story Mode** — normal fresh-story implementation. Continue below.

### 1.4 Epic-Wave Offer (explicit-path only, before status change)

Runs ONLY for an explicit `$ARGUMENTS` story path — **skip** when the 1.2 menu ran, in
Bug-Fix Mode, in DELEGATED MODE, or non-interactively. Never auto-pull parallel-safe peers:
an explicit single-story request is respected, and batch routing belongs to the 1.2 menu.

Count the selected story's epic (`NN`) rows in `STORIES_INDEX.md` whose `Status` ≠ `DONE`.
If only this story remains, skip silently → 1.5. Otherwise ask (`AskUserQuestion`):

- **Build the whole epic in dependency-ordered waves** — leave this story `status: todo`
  (do NOT run 1.6) and enter [PARALLEL MODE](#parallel-mode) at P1 with scope `--epic NN`.
- **Stay on this story** — proceed to 1.5.

### 1.5 Detect Linked GitHub Issue

The story's `issue:` frontmatter field is the linkage (v4 uses the number, never a
title-substring match). If `issue:` is set, present `Linked GitHub Issue: #<n>`; if empty,
present `No linked issue found`. No `gh` search needed — `/ck-code:ship` re-reads the
number from frontmatter itself.

### 1.6 Set Status → in-progress (frontmatter + regenerate)

**Bug-Fix Mode:** skip this phase — the story stays `bug` through the fix and is restored
to `prior_status` at Phase 8.6. Do NOT flip `bug → in-progress`.

Edit the story-file frontmatter: `status: todo` → `status: in-progress`. Then regenerate the
views in the same phase:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh" tasks/<slug>
```

That is the whole mutation — the generator recomputes every view from frontmatter, so there
is no index cell, `EPIC.md`, or rollup to touch. **DELEGATED MODE skips the regenerate** —
a worktree agent edits only its own story's frontmatter; the orchestrator regenerates once
on the target branch after merge.

### 1.7 Effort Route (from frontmatter `size:`)

Scale the *ceremony* to the story, never the guarantees. Read `size:` and fix the route now
— it governs Phases 3.3, 3.4, and 6.1 only:

| `size:` | Route | 3.3 SOLID | 3.4 Subtasks | 6.1 SOLID review |
|---|---|---|---|---|
| `S` | **LEAN** | 2–4 line note, only the principles actually in play | 3-task chain: tests → implement → QA | targeted spot-check of the principles named in 3.3 |
| `M` (or absent) | **FULL** | full SOLID Analysis template | full 6-task breakdown | full SOLID Compliance Check template |

**Bug-Fix Mode always uses LEAN** — its scope is the recorded Fix Plan, which is already
narrow. Announce the route in one line (`Route: LEAN (size S)`) so the user can override by
saying so; an explicit user request for a full pass wins over the table.

**The route NEVER skips:** the version gate (0), skill detection + report (2), the
plan+branch gate (3.5), failing-tests-before-implementation (4), the `## Unplanned Changes`
log (5.2/6.2), QA delegation and its cap (7), or the manual-test gate (8.5). A LEAN story
that grows past its `size:` during Phase 5 switches to FULL for 6.1 — say so when it happens.

---

## PHASE 2: SKILL DETECTION & CONTEXT LOADING (BLOCKING GATE)

**Mandatory — blocks Phase 3. Never plan or write code until it completes.** Done ONLY when
all three hold: (1) the `ls` of project skills ran, (2) every detected-and-present skill was
`Read`, and (3) the "Skills loaded for this implementation" block was shown to the user.
`expert-qa` and `expert-qa-project` are always detected (+ `expert-analyst` for bug-fix
flows), and `guide-conventions` always loads when present. If skills exist but you loaded none, stop and
re-run — a non-empty project must never reach Phase 3 with zero skills loaded, else Phases
5/6 "follow loaded skills" silently become no-ops.

Follow [`skill-detection.md`](../../references/skill-detection.md) end to end — it owns this
phase: the arch-doc reads (Step 1), manifest-driven detection (Steps 2–3), the `ls` +
**team gate** for a project with no skills (Step 4a / 4a.1 — `RUN TEAM FIRST` invokes
`Skill({ skill: "ck-code:team" })`, then redo this phase), the `Read`-only loading (Step 4b),
and the mandatory "Skills loaded" report (Step 5). Do not restate its gates here; run them.

Two build-specific bindings on top of that procedure:

- **Match against the selected story's `files:` set** already in context — prefer narrow
  `paths` matches over broad `keywords` matches so an unrelated body is never `Read` on a
  keyword coincidence (every body loaded here stays resident through Phases 5–6).
- **Batch every arch-doc read and skill load into parallel tool-call messages** — sequential
  reads are the largest avoidable latency in this phase.

---

## PHASE 3: IMPLEMENTATION PLANNING

Create a SOLID-compliant plan **before writing any code.**

**3.1 Research (only if needed).** context7 (MCP) for framework docs, WebSearch for uncommon
patterns — only when the story needs current docs, never for well-known basics.

**3.2 Clarify ambiguities.** If an acceptance criterion is vague, ask 1–2 targeted questions
— never about what the story or architecture docs already make clear.

### 3.3 Design with SOLID

Plan the implementation applying SOLID. Per the 1.7 route: **FULL** fills the SOLID Analysis
template in [tdd-walkthrough.md](references/tdd-walkthrough.md), every principle addressed
before moving on. **LEAN** writes a 2–4 line note naming only the principles actually at
stake in this story and how each is satisfied; principles with nothing to decide are stated
as such, never silently dropped. Either way the reasoning is explicit before any test is
written.

### 3.4 Create Subtasks

**Seed from the story's `## Implementation Tasks` section when present** (authored by
`plan`) — fold those ordered tasks in rather than inventing generic ones; if absent, use the
default breakdown. Track subtasks on **Claude Tasks** (TaskCreate; per-route chains in
[tdd-walkthrough.md](references/tdd-walkthrough.md)), each blocked by the previous. If Task
tools are unavailable, fall back to an in-session checklist (never written to the story file)
— never skip the breakdown. **Never persist the plan itself to the story file** — the file
records only frontmatter status, the final summary, and unplanned changes.

### 3.5 Confirm Plan + Branch (single gate)

Present the plan (template in [output-blocks.md](references/output-blocks.md)), then run
`git branch --show-current` and ask **one** `AskUserQuestion` that both confirms the plan and
chooses where the work lands:

- **New branch** — `git checkout -b story/<EE>-<SS>-<slug>` (or `fix/<EE>-<SS>-<slug>` for a
  bug story); slug = kebab-case of the title. Verify with `git branch --show-current`.
- **Current branch `<name>`** — ship will commit here. Omit this option when `<name>` is
  `main`/`develop` (implementation on protected branches is forbidden).
- **Adjust plan** — revise the plan, then re-ask.

Record the chosen branch — the ship phase reuses it (no second branch prompt). Nothing is
touched in Phase 4 until this gate returns a branch. **DELEGATED MODE skips the branch
question** — the harness already placed the run on its worktree branch — but still presents
the plan.

---

## PHASE 4: TDD — WRITE TESTS FIRST (RED PHASE)

Write failing tests that define expected behavior **before any implementation.**

**4.1 Start test task.** Mark the test-writing task `in_progress` (TaskUpdate).

**4.2 Determine test structure.** Read existing test files to learn conventions: naming
(`.test.ts`, `_test.rs`, `test_*.py`), location (co-located, `__tests__/`, `tests/`),
framework, assertion style, mock/stub patterns. Follow loaded guide skills.

**4.3 Write tests from acceptance criteria.** At least one test per criterion (worked mapping
in [tdd-walkthrough.md](references/tdd-walkthrough.md)), plus **edge cases** (empty input,
boundaries, max limits), **error scenarios** (invalid input, connection failures, timeouts),
and **integration points** when the story connects two components.

**4.4 Run tests — confirm RED.** **Expected: ALL new tests FAIL.** A new test that passes
without implementation is likely wrong (it tests something that already exists or is trivially
true) — fix it. Report RED as **one line** (output-blocks); mark the test task `completed`.

---

## PHASE 5: IMPLEMENTATION (GREEN PHASE)

Write the **minimum** code to make ALL tests pass.

**5.1 Start implementation tasks.** Mark the first implementation task `in_progress`.
**Guard:** confirm the Phase 2 "Skills loaded" block was shown this run. If not, stop and run
Phase 2 now — implementation must apply the loaded experts/guides.

**5.2 Implement.** Order: (1) create new files from the story's `files:`; (2) modify existing
files; (3) run tests after each significant change; (4) stop as soon as all tests pass — don't
over-engineer. **Rules:** follow the Phase 3 SOLID plan + loaded guide/expert standards; reuse
existing code (check `docs/architecture/`, scan files); simplest code that passes; comment
only non-obvious logic. **Log unplanned changes incrementally** — any file touched outside the
story's `files:` set gets one line in a `## Unplanned Changes` body section in the same Edit
pass: `- <path> — <what> — <why>`. Record at the moment of change; empty section = omit the
heading.

**5.3 Run tests — confirm GREEN.** **Expected: ALL tests PASS.** On failure read the output
and fix the implementation (NOT the tests, unless a test itself has a bug); re-run until
green. Report GREEN as **one line** (output-blocks); mark implementation task(s) `completed`.

---

## PHASE 6: REFACTOR PHASE

Improve quality without changing behavior. **Tests stay green throughout.**

**6.1 SOLID review.** Per the 1.7 route: **FULL** reviews all new/modified code with the SOLID
Compliance Check template in [tdd-walkthrough.md](references/tdd-walkthrough.md), every
principle checked. **LEAN** spot-checks the principles named in the 3.3 note plus any the diff
newly put at stake. Either way, record every violation as an ISSUE to fix in 6.2 — a LEAN
review that uncovers a structural problem escalates to the FULL template before continuing.

**6.2 Apply refactorings.** For each issue: apply the refactoring, run tests (must stay green),
revert and reconsider if they break. Common refactorings: extract function, rename, introduce
interface/trait for dependency inversion, split large functions, move code to the correct
module per `folder-structure.md`. Refactors touching files outside the story's `files:` set
also log to `## Unplanned Changes` (same `- <path> — <what> — <why>` format as 5.2).

**6.3 Final green check.** Run the full suite once more; report REFACTOR as **one line**
(output-blocks).

---

## PHASE 7: QA VALIDATION

QA reviews the work — this is **not** a self-review.

**Always delegate to the `ck-code:qa-validator` agent** (Haiku) — it absorbs the verbose
suite/build/lint output in its own context and returns a compact verdict. Run the heavy
commands inline **only** when that subagent_type is unregistered, or in DELEGATED MODE
(where the orchestrator runs `qa-validator` per branch instead).

Mark the QA task `in_progress`, then follow [`qa-validation.md`](../../references/qa-validation.md)
— it loads the QA experts, validates every acceptance criterion, runs the suite +
code-quality checks (commands per stack in [tdd-walkthrough.md](references/tdd-walkthrough.md)),
and checks architecture compliance against the feature doc. Present the QA Report
(output-blocks).

**Gate — iteration cap = 3.** At iteration 3, escalate `FIX MANUALLY / ACCEPT AS-IS / ABORT`
via `AskUserQuestion` (wording in output-blocks); never silently continue past 3. On NEEDS
FIXES inside the loop: fix each issue → re-run Phase 6 → re-run this phase with a fresh QA
check.

---

## PHASE 8: COMPLETION

### 8.1 Update Story Body — Implementation Summary

**Bug-Fix Mode:** do NOT append an Implementation Summary. Instead fill the Bug Report
`### Resolution` + `### Files Touched` and flip its `Status: DIAGNOSED → FIXED` (templates in
[../fix/references/bug-section-template.md](../fix/references/bug-section-template.md) Phase
8.1), then continue to 8.6 for the status restore. Full deltas:
[bug-fix-mode.md](references/bug-fix-mode.md).

Append the Implementation Summary block (template in
[story-template.md](references/story-template.md)) to the story body. Required fields and the
**mandatory Files Touched precision** (CREATED = path; MODIFIED = `path:lines` via `git diff`)
are in [completion.md](references/completion.md).

### 8.2–8.4 Checklist, Subtasks, Summary

- **8.2** — mark all acceptance criteria `[x]` in the story body.
- **8.3** — mark every implementation subtask `completed` on Claude Tasks (TaskUpdate);
  subtasks live on Claude Tasks, never the story file.
- **8.4** — `TaskList` to show the completed summary of all tasks.

### 8.5 User Manual Testing — REQUIRED GATE

Story stays `in-progress` until the user confirms PASS here. Never set `done` before that.
**DELEGATED MODE skips this phase** — the orchestrator runs the manual gate once on the
target branch after merge, where every merged story sits together.

**8.5.1** Present the manual-testing prompt (template in
[output-blocks.md](references/output-blocks.md)) — scenarios from acceptance criteria + an
edge case. Then ask **both** gate questions in a **single `AskUserQuestion` call** (the 8.7
ship choice is already known here, so asking it separately costs a needless round-trip):

1. "Manual test result?" → `PASS` / `ISSUES`.
2. "If it passes, ship now?" → `SHIP` / `SKIP`.

Q2's answer is **used only when Q1 is `PASS`** — on `ISSUES` discard it and go to 8.5.3
(re-ask both after the fix loop). This is the only place the two gates merge; never
pre-ask a gate whose outcome could change the work in between.

**8.5.2** On `PASS` → proceed to 8.6, then apply the Q2 answer at 8.7 without re-asking.

**8.5.3** On `ISSUES` → enter the Bug-Fix Sub-Loop (eight ordered steps in
[completion.md](references/completion.md) § 8.5.3): regression test (red) → minimum fix
(green) → **mandatory** re-run of Phase 6 + Phase 7 → mark the `## Manual-Test Bugs` entry
`FIXED` → re-prompt at 8.5.1. **Cap = 3 cycles**; on the 3rd, escalate `FIX MANUALLY / ACCEPT
AS-IS / ABORT` (template in [examples.md](references/examples.md)). Never continue past 3.

### 8.6 Set Status → done (frontmatter + regenerate)

**Bug-Fix Mode:** restore `prior_status` (from the Bug Report — normally `done`) instead of
`done`: frontmatter `status: bug` → `status: <prior_status>`, then clear `prior_status`. Then
8.7 as usual (`fix/` branch, Bug ID in commit).

**Story Mode:** Edit the frontmatter: `status: in-progress` → `status: done`.

Then regenerate the views in the same phase — one call recomputes `STORIES_INDEX.md` and the
`FEATURE_INDEX.md` rollup (a feature whose stories are all `done` rolls up to `DONE`
automatically):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh" tasks/<slug>
```

No index cell-edit, no `EPIC.md` story-table edit — those artifacts do not exist in v4.
**DELEGATED MODE skips the regenerate** (see 1.6).

### 8.7 Ship (Commit + PR + Issue Updates)

Apply the ship answer already collected at 8.5.1 Q2 — **do not ask again**: **SHIP** —
invoke `/ck-code:ship` with the story file path (handles branch, staging, commit, PR, and
GitHub Issue updates); **SKIP** — don't commit yet; remind the user they can run
`/ck-code:ship [story-path]` later. Only ask here if 8.5.1 ran without Q2 (e.g. a
non-interactive caller). **DELEGATED MODE never ships** — it commits inside its worktree and
returns its verdict.

---

## PARALLEL MODE

Two or more stories of **one epic** at a time, each in its own git worktree. This context
**decides, verifies, and merges** — it never builds, tests, or reads source itself; a
sub-agent's context is discarded on return, this one is re-paid every turn.

**Scope is exactly one epic — never a feature.**

**First action of this mode: `Read` [parallel-mode.md](references/parallel-mode.md).** It owns
P1–P9 — the P-step map with each step's non-negotiable, the exact commands, the resume prompt,
the stack-command table, the classification rules, the cleanup contract — and is mandatory,
not a lookup: nothing here substitutes for it. It pulls in its own companions as needed
([agent-prompts.md](references/agent-prompts.md) dispatch/resume prompts + return schema ·
[wave-mode.md](references/wave-mode.md) wave planning ·
[conflict-format.md](references/conflict-format.md) report shapes). Dispatches also follow the
shared contract in [subagent-fanout.md](../../references/subagent-fanout.md) — single-message
dispatch, explicit `model:` on every call, typed-schema returns — and P4 **announces the
decision** (`Fan-out: N stories → dispatching N agents.`) before the first dispatch.

The three gates that bind even before that read: **P3** never dispatches into a project with
zero skills without asking (agents cannot prompt) · **P5** derives "done" from git, never from
an agent's self-report · **P7/P8** never merge a branch that has not returned `QA: PASS`.

---

## DELEGATED MODE

Active only when the dispatch prompt begins `MODE: delegated`. The harness has already placed
this run in its own worktree on its own branch, and there is no user to ask.

| Phase | Change |
|---|---|
| 1.1–1.2 | Skipped — the story path is given. |
| 1.4 | Skipped — never offer waves from inside a wave. |
| 1.6 / 8.6 | Edit **this story's frontmatter only**; never run `ck-index.sh` and never touch a generated index — the orchestrator regenerates once on the target after merge. |
| 3.5 | Present the plan; no branch question — the harness owns the branch. An ambiguity that blocks progress returns `status: blocked`; never guess. |
| 4–6 | Unchanged. RED still gates GREEN. |
| 7 | Run the QA commands inline; never delegate to `qa-validator` — the orchestrator runs one per branch. |
| 8.5 | Skipped — manual sign-off happens once on the target after merge. |
| 8.7 | No ship. Commit after **every** TDD cycle so an early stop still leaves resumable work, then return `{status, branch, commits, remaining, criteria_met}` ([agent-prompts.md](references/agent-prompts.md)). |

Uncommitted work cannot be merged and cannot be resumed. Commit messages are conventional
(`test(EE-SS):`, `feat(EE-SS):`) with **no AI references** — full rule:
[`no-ai-references.md`](../../references/no-ai-references.md).

---

## HARD GATES (cross-phase contract, in phase order)

- **0** — version gate PASSes (`layout: v4`) before any project read/write.
- **1.2.0** — feature index read first; ask when > 2 features unfinished.
- **1.2** — interactive selection prefers the parallel set; an explicit path is single-story.
- **2** — skills detected, `Read`, and reported BEFORE any planning or code; zero project
  skills → warn + ask (`/ck-code:team` first) rather than proceed silently.
- **1.7** — effort route fixed from `size:` and announced; it scales ceremony only, never a
  guarantee, and escalates LEAN → FULL when the work outgrows its size.
- **3.5** — plan + branch confirmed in one gate before any code; never `main`/`develop`.
- **3.3 + 6.1** — SOLID applied at design, verified after refactor (lean or full per 1.7).
- **4** — failing tests before implementation (trivial boilerplate exempt).
- **5.2 / 6.2** — off-plan touches logged to `## Unplanned Changes` in the same Edit pass.
- **7** — QA delegated to `qa-validator`; iteration cap = 3, then escalate.
- **8.5** — manual-test gate; bug-fix loop cap = 3.
- **1.3.5 (Bug-Fix Mode)** — implement only the recorded Fix Plan; the failing repro test is
  the RED target; restore `prior_status`, never an Implementation Summary. `status: bug`
  without a `DIAGNOSED` Bug Report → STOP (run `/ck-code:fix`).
- **P3 / P5 / P7 (PARALLEL MODE)** — team gate asked once per batch; "done" derived from git;
  no branch merges without `QA: PASS`.

## RULES

- **Never store status anywhere but story frontmatter**, and never hand-edit `STORIES_INDEX.md`,
  `FEATURE_INDEX.md`, or `EPIC.md` — change `status:`, then run `ck-index.sh` in the same phase
  (the two are one atomic mutation).
- **Never write a delta/journal doc** — commits are the history. The story body carries only
  the Implementation Summary, Unplanned Changes, and (bug flow) the Bug Report.
- **Never reference AI, Claude, or generated-by notes** in a commit, branch name, or any git artefact — [full rule](../../references/no-ai-references.md).
- **Never derive "done" from an agent's self-report** — derive it from git + the QA verdict.
- **Never let the 1.7 effort route skip a guarantee** — it shortens the SOLID write-up, the subtask chain, and the SOLID re-review, and nothing else.
- **Never edit a test to force GREEN.**
- **Never widen a bug fix beyond its recorded Fix Plan** (Bug-Fix Mode).
- Story frontmatter is the source of truth. All output is English regardless of story language.

### Parallel mode

The "Non-negotiable" column of the P-step map ([parallel-mode.md](references/parallel-mode.md))
is the rest of this contract; these four are the traps it does not carry.

- **Never orchestrate a single story** — one story in scope takes Phases 1–8 inline.
- **Never build, test, lint, or read source in the orchestrator context** — it sees counts,
  names, statuses, SHAs, and structured returns only. Every implementation is a sub-agent.
- **Never let a dispatched agent run `ck-index.sh` or edit a generated index** — it changes
  only its own story's frontmatter; this context regenerates once per wave after merge.
- **Never span epics in one run** — every wave and every batch is scoped to a single epic.

## NEXT

After manual-test PASS (8.5), run `/ck-code:ship <story-path>` to commit, open the PR, and
update the linked GitHub Issue — once per story, or per merged branch after a parallel run.
If more stories remain, follow with `/ck-code:track next`.

**Native speed-ups (optional, user-driven — see [native-commands.md](../../references/native-commands.md)):**
`/goal "all acceptance criteria in <story> pass and the suite is green"` autonomises the
Phase 7–8 loops; `/fast` suits **`S`** stories (off for `M`/SOLID-heavy); `/code-review --fix`
is a deeper pre-ship diff pass.
