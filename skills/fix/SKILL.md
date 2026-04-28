---
name: fix
description: >
  Use when you find a bug in a story (DONE or IN PROGRESS) that needs diagnosis
  and a minimal fix. QA reproduces with a failing test before any code change.
  Enforces minimal, focused fixes — no opportunistic refactoring. Includes
  root-cause analysis and regression testing. For non-story bugs, handle separately.
argument-hint: "[path-to-story.md]"
disable-model-invocation: true
---

# Fix — Story-Linked Bug Fix Orchestrator

Diagnose and fix a bug tied to an existing story. Workflow: identify story → describe bug → QA reproduces with failing test → plan minimal fix → TDD fix → QA validates → update story.

For a worked bug-fix example, see [references/examples.md](references/examples.md).
For user-facing prompt scripts, see [references/qa-dialogue.md](references/qa-dialogue.md).
For story-file bug section templates, see [references/bug-section-template.md](references/bug-section-template.md).

## INPUT
`$ARGUMENTS` is an optional path to the story file. If provided, read it as context. If empty, enter interactive story selection (Phase 1.2).

## PHASE 1: STORY SELECTION
**Goal:** Identify which story the bug belongs to.

### 1.1 If Story Path Provided
Read `$ARGUMENTS`, validate it exists and has the expected format, then confirm: "Bug is in story [EE-SS]: [Title]. Correct?"

### 1.2 If No Story Path (Interactive)
Glob `tasks/*/epics/*/stories/*.md`, read each header for title/status/epic, filter to `Status: DONE` or `IN PROGRESS` (bugs happen in implemented stories), then present the selection table from `references/qa-dialogue.md` (Phase 1.2). If user answers `NONE`: ask for a free-form bug description and component, try to map to a story by file paths/components. If no match, create a standalone bug report without story linkage and proceed to Phase 2.

### 1.3 Load Story Context
Once selected: read the full story file (including any Implementation Summary from `/ck-code:build`), extract acceptance criteria + files created/modified + technical notes, read parent EPIC.md, and read relevant `docs/architecture/` files for the affected component. This anchors what the code is SUPPOSED to do vs. what it's doing.

## PHASE 2: BUG DESCRIPTION
**Goal:** Get a clear bug description from the user.

### 2.1 Ask About the Bug
Present the questionnaire from `references/qa-dialogue.md` (Phase 2.1).

### 2.2 Targeted Follow-ups
Ask at most 1-2 follow-ups (intermittent vs. consistent, trigger input, recent regression). See `references/qa-dialogue.md`.

## PHASE 3: SKILL DETECTION & CONTEXT LOADING
**Goal:** Load the right expert and guide skills for the affected code.

### 3.1 Detect from Story Files
Use the story's "Files to Create/Modify" — same detection logic as `/ck-code:build`:
- `mobile/`, `app/`, `components/` → `expert-frontend`
- `server/`, `api/`, `backend/` → `expert-backend`
- File extensions → matching guide skills (`.rs` → `guide-rust`, etc.)

### 3.2 Always Load QA & Analyst
`expert-qa` is ALWAYS loaded for bug fix workflows. `expert-analyst` is also ALWAYS loaded — useful for root cause analysis.

### 3.3 Load Skills
Check `.claude/skills/experts/` and `.claude/skills/guides/` for detected skills. Load what's available; warn about missing ones.

### 3.4 Prepare Systematic Debugging Approach
Before any diagnosis, form a structured investigation plan:
1. Read the failing code path from entry point to point of failure.
2. List all assumptions the code makes at each step.
3. For each assumption, identify how it could be violated.
4. Form a hypothesis for the root cause **before** reading more code.
5. Only then read deeper to confirm or disprove the hypothesis.

This prevents "grep-driven debugging" — changing code without understanding why.

## PHASE 4: QA REPRODUCTION & DIAGNOSIS
**Goal:** QA expert reproduces the bug and confirms diagnosis BEFORE any fix.

**Preferred subagent_type:** delegate reproduction to `ck-code:qa-validator` if
available (defined in this plugin's `agents/` folder — writes a minimal failing
test for the bug and reports a root-cause hypothesis). If the subagent_type is
not registered, do the steps below inline.

### 4.1 Locate the Buggy Code
Identify likely source files (Grep + the story's file list), read source + existing tests, trace the execution path that triggers the bug.

### 4.2 Reproduce the Bug — write a FAILING test FIRST
1. **Check existing tests** for this scenario: passes → test is wrong/insufficient; fails → confirms the bug; no coverage → gap identified.
2. **Write a reproduction test that FAILS because of the bug.** Format: `Test: "should [expected behavior] when [trigger condition]" → Currently FAILS with: [actual behavior]`.
3. **Run the reproduction test** — confirm it fails.

**This test is mandatory. No code change is allowed until a failing reproduction test exists.** Enforced again at the Phase 5.0 gate.

### 4.3 Root Cause Analysis
Produce a diagnosis block with: Symptom, Reproduction (test), Root cause, Location (file:line), Why it happened (logic error / missing check / wrong assumption / etc.), Impact scope.

### 4.4 Check for Related Issues
Grep for similar patterns that might share the bug; check whether the root cause affects other acceptance criteria; list related issues by `file:line` flagged as "same pattern" or "similar but not identical". **Do NOT fix related bugs in OTHER stories here** — document them and tell the user to run `/ck-code:fix` on those separately.

### 4.5 Update Story with Bug Details
Immediately after diagnosis (BEFORE planning the fix), append the Bug Report section to the story file using `references/bug-section-template.md` (Phase 4.5). Status: `DIAGNOSING`. This creates a permanent record of the bug and its diagnosis even before the fix begins.

### 4.6 Present Diagnosis to User
Use the diagnosis report script in `references/qa-dialogue.md` (Phase 4.6). Wait for `YES` or `INVESTIGATE MORE`. If `INVESTIGATE MORE`: ask which aspect to investigate, run more analysis, re-present.

## PHASE 5: FIX PLANNING
**Goal:** Plan the minimal fix before changing any code.

### 5.0 TDD Discipline Gate
Before planning, verify:
- [ ] A **failing reproduction test** exists (written in Phase 4.2).
- [ ] You can state exactly what the test expects vs. what it currently produces.
- [ ] The fix will make ONLY that test pass — nothing broader.

**If no failing test exists: STOP. Return to Phase 4.2 and write it first.** Fixing code without a failing test is guessing, not engineering.

### 5.1 Design Minimal Fix
The fix must be the **smallest possible change** that resolves the bug. **DO NOT** refactor surrounding code, add features, or "improve" unrelated code. Fix ONLY the root cause. Produce a Fix Plan stating: Strategy, Files to modify (minimal), Risk.

**SOLID compliance check:**
- S: each modified function remains single-responsibility.
- O: stable interfaces left untouched (extend, don't modify).
- L: changed types still honor their contracts.
- I: no fat interfaces introduced or widened.
- D: fix depends on abstractions, not concrete implementations.

If any SOLID principle is violated by the minimal fix, note it explicitly and design the smallest abstraction needed to fix it cleanly.

### 5.2 Create Subtasks
1. Write regression test for [bug description].
2. Apply minimal fix in [file].
3. QA validation of fix.
4. Update story and commit.

### 5.3 Update Story with Fix Plan
Append the Fix Plan subsection (status `FIXING`) to the Bug Report section created in Phase 4.5. Template: `references/bug-section-template.md` (Phase 5.3).

### 5.4 Confirm Fix Plan
Use the proposed-fix prompt in `references/qa-dialogue.md` (Phase 5.4). Wait for `YES`, `ADJUST`, or `ABORT`.

## PHASE 6: TDD FIX (RED → GREEN)
**Goal:** Fix the bug using TDD — the reproduction test goes red → green.

### 6.1 Verify RED
Re-run the reproduction test from Phase 4. Expected: FAIL. Also write any additional regression tests identified during diagnosis (related patterns from 4.4, edge cases near the root cause).

### 6.2 Apply Minimal Fix
Apply the fix as planned in Phase 5; change ONLY what's necessary (minimal diff); follow SOLID (don't violate SRP by cramming logic); follow loaded guide skill best practices.

### 6.3 Verify GREEN
Run the reproduction test + all related tests. Expected: ALL pass (including the previously-failing reproduction test).

### 6.4 Refactor (optional, deliberate)
With the test passing, ask: is the fix readable? Does it duplicate logic shareable with existing code? Can naming/structure improve **without changing behavior**? Only refactor if it makes the fix clearer; re-run tests after any refactor. **Do NOT refactor unrelated code** — stay focused on the fix area. Then present the "Fix Applied" status from `references/qa-dialogue.md` (Phase 6.4).

## PHASE 7: QA VALIDATION
**Goal:** QA expert verifies the fix is complete and nothing else broke.

### 7.1 Run Full Test Suite
Run ALL tests, not just fix-related ones. Check for regressions.

### 7.2 Verify Acceptance Criteria
Re-check ALL acceptance criteria from the original story — not just the broken ones. The fix may have side effects on previously-passing criteria.

### 7.3 Code Quality Checks
Run linting, type checking, formatting — same as `/ck-code:build` Phase 7.4.

### 7.4 Verify Minimalism
Check that the fix is truly minimal: no unrelated changes, no unnecessary refactoring, no added features. Diff should be small and focused.

### 7.5 Present QA Report
Use the QA Report template in `references/qa-dialogue.md` (Phase 7.5). Verdict: `PASS` or `NEEDS FIXES`.

### 7.6 Handle Results
- **PASS:** proceed to Phase 8.
- **NEEDS FIXES:** track iteration count (max 3). Loop back to Phase 6 for targeted fixes. After 3 iterations, escalate to user with `MANUAL FIX / ACCEPT / REVERT` options (see `references/qa-dialogue.md`).

## PHASE 8: COMPLETION
**Goal:** Update the story, commit the fix.

### 8.1 Update Story File — Resolution
Fill the Resolution + Files Touched subsections under the Bug Report. Status: `FIXED`. Template: `references/bug-section-template.md` (Phase 8.1).

**Files Touched precision rules:** for CREATED files use just the path (e.g., `CREATED tests/regression_test.rs`); for MODIFIED files use path + exact line numbers (e.g., `MODIFIED src/handler.rs:34,67-69`); use `git diff --stat` and `git diff` to collect precise lines; no descriptions — just paths and line numbers for quick reference.

### 8.2 Update Story Status
If the story was `DONE`, it stays `DONE` (bug fixed, story still complete). If `IN PROGRESS`, it stays `IN PROGRESS`.

### 8.3 Update Parent Epic
No change in EPIC.md unless the story status changed.

### 8.4 Mark All Tasks Completed
Use TaskUpdate to mark all fix-related tasks as `completed`.

### 8.5 User Manual Testing
Use the manual-testing prompt in `references/qa-dialogue.md` (Phase 8.5).
- `PASS` → proceed to commit.
- `STILL BROKEN` → loop back to Phase 4 (re-diagnose).
- `NEW ISSUE` → document as a new bug; decide whether to fix now or separately.

### 8.6 Ship (Commit + PR + Issue Updates)
Use the ship prompt in `references/qa-dialogue.md` (Phase 8.6). `SHIP` → invoke `/ck-code:ship` with the story file path; it handles branch (`fix/` prefix), staging, commit message, PR, and GitHub Issue updates. `SKIP` → remind the user they can run `/ck-code:ship [story-path]` later.

## IMPORTANT GUIDELINES

- **Minimal fix only.** Fix the bug, nothing else. No refactoring, no improvements, no features. The diff must be as small as possible while correctly fixing the root cause. Other issues found during diagnosis are documented, not fixed.
- **Reproduce before fixing.** NEVER attempt a fix without a failing reproduction test first. If you can't reproduce, investigate more before guessing. The reproduction test is proof the bug exists AND proof it's fixed.
- **QA loop safety valve.** Max 3 fix↔QA iterations; then escalate with options including revert.
- **Story file tracks everything.** The bug report is appended to the original story file (original implementation + bug reports + fixes). Future developers can see what went wrong and why.
- **Files Touched must be precise.** See Phase 8.1 rules.
- **Related bugs.** If diagnosis reveals bugs in OTHER stories, document them but don't fix them here. Tell the user: "Found related bugs in [stories]. Run `/ck-code:fix` on those separately."
- **Skill loading is automatic.** Same detection as `/ck-code:build`. QA and analyst experts are ALWAYS loaded.
- **Language: English** — all output in English regardless of spec/story language.
- **Reusability.** Works with any project using the `tasks/` story format. No project-specific references.
