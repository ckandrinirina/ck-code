---
name: build
description: Use to implement a single story from `tasks/` end-to-end. Argument is an optional story file path; if omitted, picks the next ready story interactively.
argument-hint: "[path-to-story.md]"
disable-model-invocation: true
---

# Implement Story — TDD Story Implementation Orchestrator

Implements a single story from `tasks/` using Test-Driven Development, SOLID principles,
and automated QA validation. Cycle: plan → test → implement → refactor → QA → commit.

For example dialogues emitted at each phase, see [references/examples.md](references/examples.md).
For a worked TDD walkthrough (SOLID templates, test mappings, quality checks), see [references/tdd-walkthrough.md](references/tdd-walkthrough.md).
For story-file templates appended at each phase, see [references/story-template.md](references/story-template.md).

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
5. Present as a table (see examples). If empty: tell the user nothing is ready and which deps are still missing. Suggest `/ck-code:plan` if the index is empty.

Do NOT glob `tasks/*/epics/*/stories/*.md` here — the index has everything you need.

### 1.3 Load Story Context

Once a story is selected, read **only that story's full file** (the index already gave you status/size/deps for selection). Extract: **Title**, **Description**, **Acceptance Criteria**, **Technical Notes**, **Files to Create/Modify**, **Dependencies**, **Epic**, **Size**. Then read the parent `EPIC.md` (small, always useful). Read `ROADMAP.md` ONLY if the story's technical notes reference it explicitly — otherwise skip.

### 1.4 Detect Linked GitHub Issues

Search for story and epic issues, store the numbers for `/ck-code:ship`:
```bash
gh issue list --label "story" --state open --json number,title
gh issue list --label "epic"  --state open --json number,title
```
Present the linked issue (or "No linked issue found").

### 1.4 Update Story Status (story file + index, same phase)

Edit the story file: `Status: TODO` → `Status: IN PROGRESS`. See [references/story-template.md](references/story-template.md) for the exact transition.

Then Edit `tasks/<slug>/STORIES_INDEX.md`: locate the row with this story's `ID` and change the `Status` cell from `TODO` to `IN PROGRESS`. The story file and the index must never disagree — see the mutation protocol in [`../../../references/stories-index.md`](../../../references/stories-index.md).

---

## PHASE 2: SKILL DETECTION & CONTEXT LOADING

Follow the full procedure in [`../../../references/skill-detection.md`](../../../references/skill-detection.md):

1. **Read scoped architecture docs** — always `folder-structure.md`, plus the
   docs matching the paths in the story's "Files to Create/Modify" table.
2. **Detect required experts** by file path + Technical Notes keywords.
   `expert-qa` is **always** loaded.
3. **Detect required guides** by file extension.
4. **Load** each detected skill (filesystem check → `Skill` tool → fallback
   to `Read`); warn about any truly missing skills with
   `Continue without these? YES / GENERATE FIRST` (template in
   [references/examples.md](references/examples.md)).

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

Break the work into ordered subtasks using TaskCreate (template in
[references/tdd-walkthrough.md](references/tdd-walkthrough.md)). The fixed
ordering and dependencies are mandatory:

- tests → implementation → refactor → QA → completion
- Implementation is blocked by tests; refactor is blocked by implementation;
  QA is blocked by refactor; completion is blocked by QA.

### 3.5 Update Story File

**Do this BEFORE writing any implementation code.** The story file is the source
of truth — the plan must exist in it before work begins, not appended after the fact.

Append the Implementation Plan block (template in
[references/story-template.md](references/story-template.md)) to the story file using Edit.

### 3.6 Confirm Plan

Present the plan to the user (template in
[references/examples.md](references/examples.md)) and **wait for user confirmation**
(`YES / ADJUST`) before proceeding.

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

Mark the first implementation task as `in_progress`.

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

Mark the QA task `in_progress`, then follow the shared procedure in
[`../../../references/qa-validation.md`](../../../references/qa-validation.md):

1. Load `experts/qa/SKILL.md` + `experts/qa-project/SKILL.md` (mandatory).
2. Acceptance-criteria verification (per-criterion PASS/FAIL).
3. Run the full test suite — watch for regressions.
4. Code-quality checks (full command list per stack lives in
   [references/tdd-walkthrough.md](references/tdd-walkthrough.md)).
5. Architecture compliance against `docs/architecture/`.
6. Edge-case analysis.
7. Present the QA Report (template in
   [references/examples.md](references/examples.md)).
8. Handle PASS / NEEDS FIXES — iteration cap is 3. At iteration 3,
   escalate with FIX MANUALLY / ACCEPT AS-IS / ABORT (exact wording in
   [references/examples.md](references/examples.md)). Never silently
   continue past iteration 3.

On NEEDS FIXES inside the loop: fix each issue → re-run Phase 6 (refactor)
→ re-run this phase with a fresh QA check.

---

## PHASE 8: COMPLETION

### 8.1 Update Story File — Implementation Summary

Append the Implementation Summary block (template in
[references/story-template.md](references/story-template.md)) to the story file.
It must record: TDD iteration count, QA iteration count, tests written, files
created/modified counts, **unplanned changes count** (from `## Unplanned Changes`
if present, else "none"), what was implemented, a precise Files Touched list,
SOLID compliance summary, and notes.

**Files Touched precision (mandatory):**
- CREATED files: path only (e.g., `CREATED src/ws/handler.rs`)
- MODIFIED files: path + exact line numbers (e.g., `MODIFIED src/main.rs:12,45-48,92`)
- Use `git diff --stat` and `git diff` to collect precise lines
- No descriptions — paths + line numbers only

### 8.2 Update Story Checklist in Story File

Mark all acceptance criteria as `[x]` checked in the story file.

### 8.3 Update Implementation Plan Subtasks

Mark all subtasks in the story's Implementation Plan section as `[x]` done.

### 8.4 Mark All Claude Tasks Completed

Use TaskUpdate to mark all remaining tasks as `completed`. Use TaskList to show final summary.

### 8.5 User Manual Testing — REQUIRED GATE

**Do NOT mark the story as DONE or update the EPIC until the user explicitly
confirms PASS here.** The story status must stay IN PROGRESS until manual
verification is complete.

Present the manual-testing prompt (see examples) listing specific scenarios from
the acceptance criteria plus an edge case to try. Ask `Result? PASS / ISSUES`.

- **If ISSUES:** Ask what's wrong, loop back to Phase 5 for targeted fixes.
- **If PASS:** Proceed to 8.6.

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

## IMPORTANT GUIDELINES

### Hard Rules (non-negotiable)
- **TDD:** Tests are ALWAYS written before implementation. Strict Red→Green→Refactor. No implementation code without a failing test first. Exception: trivial boilerplate (config, type exports) that can't meaningfully fail.
- **SOLID enforced twice:** Phase 3 (design) AND Phase 6 (verify in actual code). Both passes are mandatory.
- **QA loop cap = 3.** After 3 dev↔QA iterations, escalate to the user with FIX MANUALLY / ACCEPT AS-IS / ABORT. Never silently continue past 3.
- **Story file is source of truth.** Status, plan, summary all live in the story file and are updated as work progresses.
- **Unplanned-changes log.** Any file touched outside the story's "Files to Create/Modify", any drive-by fix, and any unscoped helper gets one line in `## Unplanned Changes` (`- <path> — <what> — <why>`) at the moment it happens. Empty section = omit the heading.
- **Language: English** for all output, comments, commit messages, and docs — regardless of spec/story language.

### JUCE Test Runner Rules
When writing JUCE unit tests, always:
- Use `juce::ScopedJuceInitialiser_GUI juceInit;` as the first line of `main()` — prevents CoreMidi/Singleton assertions from `AudioDeviceManager` needing a MessageManager
- Use ASCII-only strings in `beginTest()`, `expect()`, and JUCE String-constructing calls — `juce::String(const char*)` asserts bytes ≤ 127 (use `-` not `—`, `...` not `…`)
- Use a single meaningful assertion instead of looping hundreds of `expect()` calls — e.g. find max amplitude rather than 512 individual sample checks

---

## NEXT

After the user confirms manual testing PASS (Phase 8.7), run `/ck-code:ship <story-path>` to commit, open the PR, and update the linked GitHub Issues. If more stories remain, follow `ship` with `/ck-code:track next`.
