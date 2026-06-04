---
name: build
description: Use to implement a single story from `tasks/` end-to-end. Argument is an optional story file path; if omitted, picks the next ready story interactively.
argument-hint: "[path-to-story.md]"
---

# Implement Story — TDD Story Implementation Orchestrator

Implements a single story from `tasks/` using Test-Driven Development, SOLID principles,
and automated QA validation. Cycle: plan → test → implement → refactor → QA → commit.

References: [output-blocks.md](references/output-blocks.md) (compact per-phase present templates) · [examples.md](references/examples.md) (worked dialogues: interactive menu, bug-fix loop) · [tdd-walkthrough.md](references/tdd-walkthrough.md) (SOLID templates, test mappings, quality checks, JUCE rules) · [story-template.md](references/story-template.md) (story-file blocks) · [completion.md](references/completion.md) (Phase 8 summary fields, Files Touched precision, bug-fix sub-loop) · [parallel-switch.md](references/parallel-switch.md) (Phase 1.4 explicit-path epic-wave offer) · [native-commands.md](../../references/native-commands.md) (`/goal`, `/fast`, `/code-review` pairings).

**Read each reference at most once per run.** `output-blocks.md` and `tdd-walkthrough.md` are cited from many phases — load each once, keep it in working context, and reuse it for every later phase. Never re-`Read` a reference for a block you already loaded this run.

## INPUT

`$ARGUMENTS` is an optional path to a story markdown file. If provided: read and
validate. If empty: enter interactive selection (Phase 1.2).

---

## PHASE 1: STORY SELECTION

### 1.1 If Story Path Provided

Read the story at `$ARGUMENTS`. Validate it has the expected format (title,
description, acceptance criteria, status). If invalid or missing, tell the user and stop.

### 1.2 If No Story Path (Interactive — index-driven)

**1.2.0 Feature gate (read the top-level feature index FIRST).** Before any story index, Read `tasks/FEATURE_INDEX.md` and apply the feature-selection gate in [`../../references/feature-index.md`](../../references/feature-index.md): bootstrap it if missing; compute the unfinished set (`Status` ≠ `DONE`); **0** → all features done, suggest `/ck-code:plan`, stop; **1** → auto-select and announce it; **2** → fall through (no prompt); **> 2** → AskUserQuestion "Which feature do you want to build?" (single-select, one option per unfinished feature). The chosen feature's `Plan` + `NN` scope the story index read below to that one epic. Backfill a blank `Description` from `EPIC.md` in this pass. This phase runs ONLY in interactive mode — an explicit `$ARGUMENTS` story path skips it.

1. Read the chosen feature's `tasks/<Plan>/STORIES_INDEX.md` and filter to its epic `NN` (the project-level index — one Read covers every story).
2. **Bootstrap check:** if the index is missing or its header is not `<!-- Schema: v1 -->`, follow the bootstrap procedure in [`../../references/stories-index.md`](../../references/stories-index.md), then re-read.
3. Filter to `Status: TODO` AND every ID in `Blocked by` resolves to `Status: DONE` in the same table.
4. Sort by epic, then story number, then size (S < M < L < XL).
5. **Detect whole-epic options:** group ALL not-`DONE` rows by epic (`NN`); any epic with > 1 non-DONE story is a wave candidate (a partly-blocked epic is the dependency-order case wave mode exists for).
6. **Detect the parallel-safe set:** if ≥ 2 stories are ready, read each ready story's `Files to Create/Modify` table (deliberate cross-check via the index `File` column — NOT a glob of all stories) and group so no two share a file path. The largest conflict-free group of ≥ 2 is the **recommended parallel set** — the preferred default.
7. **Present the menu and route the choice** per [references/examples.md](references/examples.md): recommended parallel set (⚡, when ≥ 2) → epics → single stories. The selection is the one confirmation — the parallel/epic routes hand off to `parallel-build` (which does not re-prompt); a single story proceeds to 1.3 (Phase 1.4 then skips its offer). If none ready, say so + which deps are missing (suggest `/ck-code:plan` if the index is empty).

### 1.3 Load Story Context

Once a story is selected, **batch the story file and parent `EPIC.md` in a single parallel tool-call message** — the index row's `File` column already encodes the epic folder, so EPIC.md is computable without reading the story first. From the story file extract: **Title**, **Description**, **Acceptance Criteria**, **Technical Notes**, **Files to Create/Modify**, **Implementation Tasks** (if present), **Dependencies**, **Epic**, **Size**. Read `ROADMAP.md` ONLY if the story's Technical Notes reference it explicitly — otherwise skip (separate read, after parsing).

### 1.4 Epic-Wave Offer (explicit-path only, before status mutation)

Runs ONLY for an explicit `$ARGUMENTS` story path — **skip** when the 1.2 menu ran or
non-interactively. Never auto-pull parallel-safe peers. If the story's epic still has > 1
non-DONE story, ask (AskUserQuestion): build-whole-epic-in-waves (`B → Skill("ck-code:parallel-build",
"--epic NN")`, status stays `TODO`, exit) vs stay on this story (`C → 1.5`); if only this
story remains, skip silently. Detail: [parallel-switch.md](references/parallel-switch.md).

### 1.5 Detect Linked GitHub Issues

Search for story and epic issues in **a single parallel Bash tool-call message** (the two queries are independent); store the numbers for `/ck-code:ship`:

```bash
gh issue list --label "story" --state open --json number,title
gh issue list --label "epic"  --state open --json number,title
```

Present the linked issue (or "No linked issue found").

### 1.6 Update Story Status (story file + index, same phase)

Edit the story file: `Status: TODO` → `Status: IN PROGRESS`. See [references/story-template.md](references/story-template.md) for the exact transition.

Then Edit `tasks/<slug>/STORIES_INDEX.md`: locate the row with this story's `ID` and change the `Status` cell from `TODO` to `IN PROGRESS`. The story file and the index must never disagree — see the mutation protocol in [`../../references/stories-index.md`](../../references/stories-index.md).

If this is the first story of its feature to start (the feature was `TODO`), also Edit `tasks/FEATURE_INDEX.md`: set that feature's `Status` cell `TODO` → `IN PROGRESS` (per [`../../references/feature-index.md`](../../references/feature-index.md)).

---

## PHASE 2: SKILL DETECTION & CONTEXT LOADING (BLOCKING GATE)

**Mandatory — blocks Phase 3. Never plan or write code until it completes.** Done
ONLY when all three hold: (1) the 4a `ls` ran, (2) every detected-and-present skill
was `Read`, and (3) the "Skills loaded for this implementation" block was shown to the
user. `expert-qa` is always detected (+ `expert-analyst` for bug-fix flows), and
`guide-conventions` always loads when present. If 4a
lists skills but you loaded none, stop and re-run Step 4 — a non-empty project must
never reach Phase 3 with zero skills loaded, else Phases 5/6 "follow loaded skills"
silently become no-ops.

**Skip-fast:** if `.claude/skills/experts/` and `.claude/skills/guides/` are both absent there are no project skills to load — read `docs/architecture/folder-structure.md` + the story's feature doc (+ `_shared.md` when cross-cutting), tell the user "No project skills — run `/ck-code:team` to generate them", show the "Skills loaded" block as empty, and proceed to Phase 3 without reading `skill-detection.md`.

Otherwise, follow the full procedure in [`../../references/skill-detection.md`](../../references/skill-detection.md): read the story's **feature doc** (always `folder-structure.md` + the feature doc named in the story's `FEATURE_INDEX` `Docs` column, + `_shared.md` when the work is cross-cutting; never the retired layer docs — fall back + suggest `/ck-code:doc-optimizer sync` if it's missing), detect required experts (by each present skill's `paths`/`keywords` frontmatter, anchor table as fallback; `expert-qa` **always** loaded, `guide-conventions` always loaded when present) and guides (by their `paths` frontmatter / file extension), load each (filesystem check → warn on truly-missing with `Continue without these? YES / GENERATE FIRST`, template in [references/output-blocks.md](references/output-blocks.md)), and **report the loaded experts/guides to the user before Phase 3 — never load skills silently**. All arch-doc reads and skill loads inside that procedure **must be batched into parallel tool-call messages** (Steps 1 and 4b).

---

## PHASE 3: IMPLEMENTATION PLANNING

Create a SOLID-compliant plan **before writing any code.**

### 3.1 Research (if needed)

Only when the story needs current docs: use context7 (MCP tools, else `npx -y @upstash/context7`)
for framework docs and WebSearch for uncommon patterns in the technical notes. Don't research
well-known basics.

### 3.2 Clarify Ambiguities

If any acceptance criterion is vague or incomplete, ask the user 1-2 targeted questions —
never about things already clear in the story or architecture docs.

### 3.3 Design with SOLID

Plan the implementation applying each SOLID principle (S, O, L, I, D). Fill out
the SOLID Analysis template in [references/tdd-walkthrough.md](references/tdd-walkthrough.md)
for: single responsibility per file/class, open/closed extension points, Liskov-substitutable
new types, focused interfaces, and dependency inversion via injection. Every
principle must be addressed before moving on.

### 3.4 Create Subtasks

**Seed from the story's `## Implementation Tasks` section when present** (authored by
`plan`) — fold those ordered tasks into the implementation steps rather than inventing
generic ones; if absent/empty, use the default breakdown. Never block on a missing list.

Track subtasks on **Claude Tasks** (TaskCreate; template in
[tdd-walkthrough.md](references/tdd-walkthrough.md)), updated as each phase runs
(4.1 / 5.1 / 6 / 7 / 8.4). Mandatory ordering — each step blocked by the previous:
tests → implementation → refactor → QA → completion. If Task tools are unavailable,
fall back to an in-session checklist held in working context (never written to the story file) — never skip the breakdown.

### 3.5 Keep the Plan in Session — Do Not Write It to the Story File

**Never persist the implementation plan to the story file.** Hold it in the session:
subtasks live on Claude Tasks (Phase 3.4) and the plan is presented to the user in
Phase 3.6. The story file records only status, the final summary, and unplanned
changes — not the plan. Proceed straight to 3.6.

### 3.6 Confirm Plan

Present the plan to the user (template in
[references/output-blocks.md](references/output-blocks.md)) and **wait for user confirmation**
(`YES / ADJUST`) before proceeding.

### 3.7 Confirm Branch Strategy

**Before any file is touched in Phase 4**, ask the user where the work should land:

```bash
git branch --show-current
```

Use AskUserQuestion with two options:

- **A) Create new branch** — `story/<EE>-<SS>-<slug>` (or `fix/<EE>-<SS>-<slug>` for bug stories); slug = kebab-case from story title.
- **B) Stay on current branch** — `<current-branch>`; ship will commit and push here.

On **A**: `git checkout -b story/<EE>-<SS>-<slug>` (or `fix/...`), then verify with `git branch --show-current`.
On **B**: if `<current-branch>` is `main` or `develop`, refuse and re-prompt — implementation on protected branches is forbidden; force option A.

Record the chosen branch — the ship phase reuses it (no second branch prompt).

---

## PHASE 4: TDD — WRITE TESTS FIRST (RED PHASE)

Write failing tests that define expected behavior **before any implementation.**

### 4.1 Start Test Task

Mark the test-writing task as `in_progress` using TaskUpdate.

### 4.2 Determine Test Structure

Read existing test files to learn project conventions: file naming
(`.test.ts`, `_test.rs`, `test_*.py`), location (co-located, `__tests__/`, `tests/`),
framework (Jest, cargo test, pytest, Catch2), assertion style, mock/stub patterns.
Follow the patterns from loaded guide skills.

### 4.3 Write Tests from Acceptance Criteria

For EACH acceptance criterion, write at minimum one test (worked criteria → test-name
mapping in [tdd-walkthrough.md](references/tdd-walkthrough.md)). Also cover **edge cases**
(empty input, boundary values, max limits), **error scenarios** (invalid input, connection
failures, timeouts), and **integration points** when the story connects two components.

### 4.4 Run Tests — Confirm RED

Run the test suite (cargo test, npm test, pytest, etc.).
**Expected result: ALL new tests FAIL.** If any new test passes without
implementation, the test is likely wrong (testing something that already exists
or is trivially true) — review and fix.

Present the RED Phase Complete block (see output-blocks). Mark test task as `completed`.

---

## PHASE 5: IMPLEMENTATION (GREEN PHASE)

Write the **minimum** code necessary to make ALL tests pass.

### 5.1 Start Implementation Tasks

Mark the first implementation task as `in_progress`. **Guard:** before writing any
code, confirm the Phase 2 "Skills loaded" block was shown this run. If it was not
(Phase 2 skipped), stop and run Phase 2 now — implementation must apply the loaded
experts/guides, not proceed without them.

### 5.2 Implement

Order: (1) create new files from the story's "Files to Create/Modify";
(2) modify existing files as specified; (3) run tests after each significant
change; (4) stop as soon as all tests pass — don't over-engineer.

**Rules:** follow the Phase 3 SOLID plan + loaded guide/expert standards; reuse existing
code (check `docs/architecture/`, scan files); write the simplest code that passes; comment
only non-obvious logic. **Log unplanned changes incrementally** — any file touched outside
the story's "Files to Create/Modify" table (bug fixed in passing, helper/test added) gets one
line in a `## Unplanned Changes` section in the same Edit pass: `- <path> — <what> — <why>`.
Record at the moment of change; empty section = omit the heading.

### 5.3 Run Tests — Confirm GREEN

Run the full test suite. **Expected: ALL tests PASS.** If tests fail, read the
output and fix the implementation (NOT the tests, unless the test itself has a
bug). Re-run until green.

Present the GREEN Phase Complete block (see output-blocks). Mark implementation task(s) as `completed`.

---

## PHASE 6: REFACTOR PHASE

Improve code quality without changing behavior. **Tests must stay green throughout.**

### 6.1 SOLID Review

Review all new/modified code against SOLID using the SOLID Compliance Check
template in [references/tdd-walkthrough.md](references/tdd-walkthrough.md).
Every principle (S, O, L, I, D) must be checked. Record any violation as an
ISSUE entry to fix in 6.2.

### 6.2 Apply Refactorings

For each issue: apply the refactoring, run tests (must stay green), revert and reconsider
if they break. Common refactorings: extract function, rename, introduce interface/trait for
dependency inversion, split large functions, move code to the correct module per
`folder-structure.md`. Refactors touching files outside the Phase 3 "Files to Create/Modify"
list also log to `## Unplanned Changes` (same `- <path> — <what> — <why>` format as Phase 5.2).

### 6.3 Final Green Check

Run full test suite one more time and present the REFACTOR Phase Complete block (see output-blocks).

---

## PHASE 7: QA VALIDATION

QA expert skills review the work — this is **not** a self-review.

**Preferred subagent_type:** delegate to `ck-code:qa-validator` if available (in this
plugin's `agents/` folder — runs the suite, maps results to acceptance criteria, reports
failures with file:line). If it is not registered, run the inline procedure below.

Mark the QA task `in_progress`, then follow the full procedure in
[`../../references/qa-validation.md`](../../references/qa-validation.md) — it loads the QA
experts, validates every acceptance criterion, runs the suite + code-quality checks
(commands per stack in [references/tdd-walkthrough.md](references/tdd-walkthrough.md)), and
checks architecture compliance. Present the QA Report (template in
[references/output-blocks.md](references/output-blocks.md)).

**Gate — iteration cap = 3.** At iteration 3, escalate `FIX MANUALLY / ACCEPT AS-IS /
ABORT` (wording in output-blocks); never silently continue past 3. On NEEDS FIXES inside the
loop: fix each issue → re-run Phase 6 (refactor) → re-run this phase with a fresh QA check.

---

## PHASE 8: COMPLETION

### 8.1 Update Story File — Implementation Summary

Append the Implementation Summary block (template in
[references/story-template.md](references/story-template.md)) to the story file. Required
fields and the **mandatory Files Touched precision** (CREATED = path; MODIFIED =
`path:lines` collected via `git diff`) are specified in
[references/completion.md](references/completion.md).

### 8.2 Update Story Checklist in Story File

Mark all acceptance criteria as `[x]` checked in the story file.

### 8.3 Mark Subtasks Complete

Mark every implementation subtask `completed` on Claude Tasks via TaskUpdate — subtasks
live on Claude Tasks, never the story file.

### 8.4 Show Final Task Summary

Use TaskList to show the final completed summary of all tasks.

### 8.5 User Manual Testing — REQUIRED GATE

Story stays IN PROGRESS until the user confirms PASS here. Never mark DONE or
update the EPIC before that.

**8.5.1** Present the prompt (template in [references/output-blocks.md](references/output-blocks.md)) — scenarios from acceptance criteria + edge case. Ask `Result? PASS / ISSUES`.

**8.5.2** On `PASS` → proceed to 8.6.

**8.5.3** On `ISSUES` → enter the Bug-Fix Sub-Loop (eight ordered steps in
[completion.md](references/completion.md) § 8.5.3): regression test (red) → minimum fix
(green) → **mandatory** re-run of Phase 6 + Phase 7 → mark the `## Manual-Test Bugs` entry
`FIXED` → re-prompt at 8.5.1. **Cap = 3 cycles**; on the 3rd, escalate `FIX MANUALLY /
ACCEPT AS-IS / ABORT` (template in [examples.md](references/examples.md)). Never continue past 3.

### 8.6 Update Story File — Status DONE (story file + index, same phase)

Edit the story file: `Status: IN PROGRESS` → `Status: DONE`.

Then Edit `tasks/<slug>/STORIES_INDEX.md`: locate the row with this story's `ID` and change the `Status` cell from `IN PROGRESS` to `DONE`. Both edits in the same phase — see [`../../references/stories-index.md`](../../references/stories-index.md).

Then Edit `tasks/FEATURE_INDEX.md`: recompute this feature's `Stories` count and roll up its `Status` — `IN PROGRESS`, or `DONE` once this was its last remaining story. Do not leave the feature rollup stale after a completed build. See [`../../references/feature-index.md`](../../references/feature-index.md).

### 8.7 Update Parent Epic

Read the parent EPIC.md and update the story's status in the stories table to `DONE`.

### 8.8 Ship (Commit + PR + Issue Updates)

**If PASS:** present the ship options (see output-blocks): **A) SHIP** — invoke `/ck-code:ship`
with the story file path (handles branch, staging, commit, PR, and GitHub Issue updates —
closing story issue, updating epic checklist); **B) SKIP** — don't commit yet; remind the
user they can run `/ck-code:ship [story-path]` later.

---

## HARD GATES (cross-phase contract)

Each gate is enforced inside its phase — listed here as a checklist for orchestrators:

- **Version gate** — run the shared [version gate](../../references/version-gate.md) before any architecture-doc read/write; on BLOCK (pre-v3), offer `/ck-code:doc-optimizer upgrade` and stop until it PASSes. `tasks/VERSION.md` = `layout: v3` is the cheap fast path.
- **Phase 1.2.0** — interactive runs read `tasks/FEATURE_INDEX.md` first (bootstrap if missing); > 2 unfinished features ⇒ ask which, then scope to its epic. Feature rollup updated on completion (8.6) — never stale.
- **Phase 1.2** — interactive selection prefers the parallel set (≥ 2 conflict-free ready ⇒ one-confirm, auto-fan-out to worktrees). An explicit story arg is always single-story.
- **Phase 2** — experts + guides detected, `Read`, and the "Skills loaded" block shown BEFORE any planning/code; `expert-qa` always detected. Non-empty 4a `ls` ⇒ never reach Phase 3 with zero skills.
- **Phase 3.7** — branch chosen before any code. Never implement on `main` / `develop`.
- **Phase 4** — Failing tests written before implementation (strict Red→Green→Refactor; trivial boilerplate exempt).
- **Phase 3.3 + Phase 6.1** — SOLID applied at design AND verified after refactor.
- **Phase 5.2 / 6.2** — Off-plan file touches logged to `## Unplanned Changes` in the same Edit pass.
- **Phase 7** — QA iteration cap = 3 → escalate `FIX MANUALLY / ACCEPT AS-IS / ABORT`.
- **Phase 8.5** — Manual-test gate, bug-fix loop cap = 3 (each cycle re-runs Phase 6 + Phase 7).

Story file is the source of truth. All output in English regardless of spec/story
language. JUCE test-runner rules live in [references/tdd-walkthrough.md](references/tdd-walkthrough.md).

---

## NEXT

After the user confirms manual testing PASS (Phase 8.7), run `/ck-code:ship <story-path>` to commit, open the PR, and update the linked GitHub Issues. If more stories remain, follow `ship` with `/ck-code:track next`.

**Native speed-ups (optional, user-driven — see [native-commands.md](../../references/native-commands.md)):**

- To run the QA/manual-test loops (Phase 7–8) autonomously, the user can set `/goal "all acceptance criteria in <story> pass and the full test suite is green"` — a cheap verifier model checks each turn until met.
- `/fast` is worth toggling for **small** stories (size `S`); keep it **off** for `L`/`XL` or SOLID-heavy work that needs full reasoning.
- Before `/ck-code:ship`, a deeper `/code-review --fix` pass is available on the diff.
