---
name: build
description: Use to implement a single story from `tasks/` end-to-end. Argument is an optional story file path; if omitted, picks the next ready story interactively.
argument-hint: "[path-to-story.md]"
---

# Implement Story — TDD Story Implementation Orchestrator

Implements a single story from `tasks/` using Test-Driven Development, SOLID principles,
and automated QA validation. Cycle: plan → test → implement → refactor → QA → commit.

References: [examples.md](references/examples.md) (per-phase dialogues) · [tdd-walkthrough.md](references/tdd-walkthrough.md) (SOLID templates, test mappings, quality checks, JUCE rules) · [story-template.md](references/story-template.md) (story-file blocks) · [completion.md](references/completion.md) (Phase 8 summary fields, Files Touched precision, bug-fix sub-loop) · [parallel-switch.md](references/parallel-switch.md) (Phase 1.4 explicit-path epic-wave offer) · [native-commands.md](../../references/native-commands.md) (`/goal`, `/fast`, `/code-review` pairings).

## INPUT

`$ARGUMENTS` is an optional path to a story markdown file. If provided: read and
validate. If empty: enter interactive selection (Phase 1.2).

---

## PHASE 1: STORY SELECTION

### 1.1 If Story Path Provided

Read the story at `$ARGUMENTS`. Validate it has the expected format (title,
description, acceptance criteria, status). If invalid or missing, tell the user and stop.

### 1.2 If No Story Path (Interactive — index-driven)

1. Read `tasks/*/STORIES_INDEX.md` (the project-level index — one Read covers every story).
2. **Bootstrap check:** if the index is missing or its header is not `<!-- Schema: v1 -->`, follow the bootstrap procedure in [`../../../references/stories-index.md`](../../../references/stories-index.md), then re-read.
3. Filter to `Status: TODO` AND every ID in `Blocked by` resolves to `Status: DONE` in the same table.
4. Sort by epic, then story number, then size (S < M < L < XL).
5. **Detect whole-epic options:** group ALL not-`DONE` rows by epic (`NN`); any epic with > 1 non-DONE story is a wave candidate (a partly-blocked epic is the dependency-order case wave mode exists for).
6. **Detect the parallel-safe set:** if ≥ 2 stories are ready, read each ready story's `Files to Create/Modify` table (deliberate cross-check via the index `File` column — NOT a glob of all stories) and group so no two share a file path. The largest conflict-free group of ≥ 2 is the **recommended parallel set** — the preferred default.
7. **Present the menu and route the choice** per [references/examples.md](references/examples.md): recommended parallel set (⚡, when ≥ 2) → epics → single stories. The selection is the one confirmation — the parallel/epic routes hand off to `parallel-build` (which does not re-prompt); a single story proceeds to 1.3 (Phase 1.4 then skips its offer). If none ready, say so + which deps are missing (suggest `/ck-code:plan` if the index is empty).

### 1.3 Load Story Context

Once a story is selected, **batch the story file and parent `EPIC.md` in a single parallel tool-call message** — the index row's `File` column already encodes the epic folder, so EPIC.md is computable without reading the story first. From the story file extract: **Title**, **Description**, **Acceptance Criteria**, **Technical Notes**, **Files to Create/Modify**, **Implementation Tasks** (if present), **Dependencies**, **Epic**, **Size**. Read `ROADMAP.md` ONLY if the story's Technical Notes reference it explicitly — otherwise skip (separate read, after parsing).

### 1.4 Epic-Wave Offer (explicit-path only, before status mutation)

Interactive parallel/epic routing lives in Phase 1.2, so **skip this phase** when the 1.2
menu ran or when running non-interactively / as a dispatched sub-agent — it runs ONLY for
a story PATH passed via `$ARGUMENTS`. An explicit single-story request is respected:
**never auto-pull parallel-safe peers**. Offer only the whole-epic build — if the story's
epic still has > 1 non-DONE story, ask (AskUserQuestion) build-whole-epic-in-waves
(`B → Skill("ck-code:parallel-build", "--epic NN")`, status stays `TODO`, exit) vs stay on
this story (`C → 1.5`); if only this story remains, skip silently. Detail:
[references/parallel-switch.md](references/parallel-switch.md).

### 1.5 Detect Linked GitHub Issues

Search for story and epic issues in **a single parallel Bash tool-call message** (the two queries are independent); store the numbers for `/ck-code:ship`:

```bash
gh issue list --label "story" --state open --json number,title
gh issue list --label "epic"  --state open --json number,title
```

Present the linked issue (or "No linked issue found").

### 1.6 Update Story Status (story file + index, same phase)

Edit the story file: `Status: TODO` → `Status: IN PROGRESS`. See [references/story-template.md](references/story-template.md) for the exact transition.

Then Edit `tasks/<slug>/STORIES_INDEX.md`: locate the row with this story's `ID` and change the `Status` cell from `TODO` to `IN PROGRESS`. The story file and the index must never disagree — see the mutation protocol in [`../../../references/stories-index.md`](../../../references/stories-index.md).

---

## PHASE 2: SKILL DETECTION & CONTEXT LOADING (BLOCKING GATE)

**Mandatory — this phase blocks Phase 3. Never plan or write code until it has run
to completion.** Phases 5 and 6 tell you to "follow loaded guide/expert skills"; if
Phase 2 is skipped, those instructions silently apply nothing and the work ships
without its experts and guides. The phase is done ONLY when all three are true:
(1) the 4a `ls` has run, (2) every detected-and-present skill has been `Read`, and
(3) the Step 5 "Skills loaded for this implementation" block has been shown to the
user. `expert-qa` is always in the detected set (plus `expert-analyst` for bug-fix
flows). If 4a returns skills but you loaded none, stop and re-run Step 4 — a
non-empty project must never reach Phase 3 with zero skills loaded.

Follow the full procedure in [`../../../references/skill-detection.md`](../../../references/skill-detection.md): read scoped architecture docs (always `folder-structure.md` + the docs matching the story's "Files to Create/Modify" paths), detect required experts (by file path + Technical Notes keywords; `expert-qa` is **always** loaded) and guides (by file extension), load each (filesystem check → warn on truly-missing with `Continue without these? YES / GENERATE FIRST`, template in [references/examples.md](references/examples.md)), and **report the loaded experts/guides to the user before Phase 3 — never load skills silently**. All arch-doc reads and skill loads inside that procedure **must be batched into parallel tool-call messages** (Steps 1 and 4b).

---

## PHASE 3: IMPLEMENTATION PLANNING

Create a SOLID-compliant plan **before writing any code.**

### 3.1 Research (if needed)

If the story involves patterns or technologies that could benefit from current docs:

- Use context7 (MCP tools if available, else `npx -y @upstash/context7`) to look up relevant framework documentation
- Use WebSearch for uncommon patterns referenced in technical notes
- Only research what's actually needed — don't research well-known basics

### 3.2 Clarify Ambiguities

Review the acceptance criteria. If any are vague or incomplete:

- Ask the user 1-2 targeted questions
- Do NOT ask about things already clear in the story or architecture docs

### 3.3 Design with SOLID

Plan the implementation applying each SOLID principle (S, O, L, I, D). Fill out
the SOLID Analysis template in [references/tdd-walkthrough.md](references/tdd-walkthrough.md)
for: single responsibility per file/class, open/closed extension points, Liskov-substitutable
new types, focused interfaces, and dependency inversion via injection. Every
principle must be addressed before moving on.

### 3.4 Create Subtasks

**Seed from the story's task list when present.** If the story file has an
`## Implementation Tasks` section (authored by `plan`), use those ordered tasks
as the concrete implementation steps — fold them into the implementation phase
of the subtask board rather than inventing generic steps. If the section is
absent or empty (older stories, or a story created without `plan`), proceed with
the default breakdown below exactly as before — never block on a missing task list.

Break the work into ordered subtasks using **Claude Tasks** (TaskCreate; template in
[references/tdd-walkthrough.md](references/tdd-walkthrough.md)) so the story's progress
is tracked on a live board and updated as each phase runs (4.1 / 5.1 / 6 / 7 / 8.4).
The fixed ordering and dependencies are mandatory:

- tests → implementation → refactor → QA → completion
- Implementation is blocked by tests; refactor is blocked by implementation;
  QA is blocked by refactor; completion is blocked by QA.

**Always use Claude Tasks when the Task tools are available.** If they are not (e.g. a
host without TaskCreate), fall back to tracking the same ordered subtasks as a checklist
in the story file's Implementation Plan section — never skip the breakdown.

### 3.5 Update Story File

**Do this BEFORE writing any implementation code.** The story file is the source
of truth — the plan must exist in it before work begins, not appended after the fact.

Append the Implementation Plan block (template in
[references/story-template.md](references/story-template.md)) to the story file using Edit.

### 3.6 Confirm Plan

Present the plan to the user (template in
[references/examples.md](references/examples.md)) and **wait for user confirmation**
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

For EACH acceptance criterion in the story, write at minimum one test. Worked
example mapping criteria → test names is in
[references/tdd-walkthrough.md](references/tdd-walkthrough.md).

Also add tests for:

- **Edge cases** — empty input, boundary values, max limits
- **Error scenarios** — invalid input, connection failures, timeouts
- **Integration points** — if the story connects two components

### 4.4 Run Tests — Confirm RED

Run the test suite (cargo test, npm test, pytest, etc.).
**Expected result: ALL new tests FAIL.** If any new test passes without
implementation, the test is likely wrong (testing something that already exists
or is trivially true) — review and fix.

Present the RED Phase Complete block (see examples). Mark test task as `completed`.

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

**Implementation rules:**

- Follow SOLID principles from the Phase 3 plan
- Follow loaded guide skills' best practices and expert skills' coding standards
- Reuse existing code — check `docs/architecture/` and scan existing files
- Write the simplest code that passes the tests
- Add inline comments only where logic isn't self-evident
- **Log unplanned changes incrementally.** If you modify a file not in the story's "Files to Create/Modify" table, fix a bug noticed in passing, or add a helper/test file that wasn't in the Phase 3 plan, append one line to a `## Unplanned Changes` section in the story file in the same Edit pass. Format: `- <path> — <what> — <why>`. Record at the moment of the change, not at the end. Empty section = omit the heading.

### 5.3 Run Tests — Confirm GREEN

Run the full test suite. **Expected: ALL tests PASS.** If tests fail, read the
output and fix the implementation (NOT the tests, unless the test itself has a
bug). Re-run until green.

Present the GREEN Phase Complete block (see examples). Mark implementation task(s) as `completed`.

---

## PHASE 6: REFACTOR PHASE

Improve code quality without changing behavior. **Tests must stay green throughout.**

### 6.1 SOLID Review

Review all new/modified code against SOLID using the SOLID Compliance Check
template in [references/tdd-walkthrough.md](references/tdd-walkthrough.md).
Every principle (S, O, L, I, D) must be checked. Record any violation as an
ISSUE entry to fix in 6.2.

### 6.2 Apply Refactorings

For each issue: (1) apply the refactoring, (2) run tests — must still pass,
(3) if tests break, revert and reconsider. Common refactorings: extract function,
rename, introduce interface/trait for dependency inversion, split large functions,
move code to the correct module per `folder-structure.md`.

Refactors that touch files outside the Phase 3 "Files to Create/Modify" list
also log to `## Unplanned Changes` (same `- <path> — <what> — <why>` format
used in Phase 5.2).

### 6.3 Final Green Check

Run full test suite one more time and present the REFACTOR Phase Complete block (see examples).

---

## PHASE 7: QA VALIDATION

QA expert skills review the work — this is **not** a self-review.

**Preferred subagent_type:** delegate to `ck-code:qa-validator` if available
(defined in this plugin's `agents/` folder — runs the test suite, maps
results to acceptance criteria, reports failures with file:line citations).
If the subagent_type is not registered, run the inline procedure.

Mark the QA task `in_progress`, then follow the full procedure in
[`../../../references/qa-validation.md`](../../../references/qa-validation.md): load
`experts/qa` + `experts/qa-project` (mandatory), verify each acceptance criterion
(PASS/FAIL), run the full suite for regressions, run code-quality checks (commands per
stack in [references/tdd-walkthrough.md](references/tdd-walkthrough.md)), check
architecture compliance against `docs/architecture/`, analyse edge cases, and present the
QA Report (template in [references/examples.md](references/examples.md)).

**Gate — iteration cap = 3.** At iteration 3, escalate `FIX MANUALLY / ACCEPT AS-IS /
ABORT` (wording in examples); never silently continue past 3. On NEEDS FIXES inside the
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

### 8.3 Update Implementation Plan Subtasks

Mark all subtasks in the story's Implementation Plan section as `[x]` done.

### 8.4 Mark All Claude Tasks Completed

Use TaskUpdate to mark all remaining tasks as `completed`. Use TaskList to show final summary.

### 8.5 User Manual Testing — REQUIRED GATE

Story stays IN PROGRESS until the user confirms PASS here. Never mark DONE or
update the EPIC before that.

**8.5.1** Present the prompt (template in [references/examples.md](references/examples.md)) — scenarios from acceptance criteria + edge case. Ask `Result? PASS / ISSUES`.

**8.5.2** On `PASS` → proceed to 8.6.

**8.5.3** On `ISSUES` → enter the Bug-Fix Sub-Loop: regression test (red) → minimum fix
(green) → **mandatory** re-run of Phase 6 (Refactor) + Phase 7 (QA) → update the
`## Manual-Test Bugs` entry `OPEN` → `FIXED` → re-prompt at 8.5.1. The full eight ordered
steps are in [references/completion.md](references/completion.md). **Cap = 3 cycles**; on
the 3rd, escalate `FIX MANUALLY / ACCEPT AS-IS / ABORT` (template in
[references/examples.md](references/examples.md)). Never continue silently past 3.

### 8.6 Update Story File — Status DONE (story file + index, same phase)

Edit the story file: `Status: IN PROGRESS` → `Status: DONE`.

Then Edit `tasks/<slug>/STORIES_INDEX.md`: locate the row with this story's `ID` and change the `Status` cell from `IN PROGRESS` to `DONE`. Both edits in the same phase — see [`../../../references/stories-index.md`](../../../references/stories-index.md).

### 8.7 Update Parent Epic

Read the parent EPIC.md and update the story's status in the stories table to `DONE`.

### 8.8 Ship (Commit + PR + Issue Updates)

**If PASS:** Present the ship options (see examples):

- **A) SHIP** — Invoke `/ck-code:ship` with the story file path. It handles
  branch creation, staging, commit message, PR, and GitHub Issue updates
  (closing story issue, updating epic checklist).
- **B) SKIP** — Don't commit yet. Remind the user they can run
  `/ck-code:ship [story-path]` later manually.

---

## HARD GATES (cross-phase contract)

Each gate is enforced inside its phase — listed here as a checklist for orchestrators:

- **Phase 1.2** — Interactive selection prefers parallel: ≥ 2 conflict-free ready stories ⇒ the parallel set is the recommended one-confirm option, then auto-fan-out to worktree agents. An explicit story arg is always single-story — never auto-expanded.
- **Phase 2** — Experts + guides detected, loaded via `Read`, and the "Skills loaded" block shown BEFORE any planning or code. `expert-qa` always detected (+ `expert-analyst` for fixes). A non-empty 4a `ls` must never reach Phase 3 with zero skills loaded — skipping Phase 2 turns the "follow loaded skills" rules in Phases 5/6 into no-ops.
- **Phase 3.7** — Branch chosen before any code. Never implement on `main` / `develop`.
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
