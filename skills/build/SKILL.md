---
name: build
description: >
  Use when you have a story file ready and need to implement it via TDD
  (red-green-refactor) with SOLID principles. Auto-loads expert and guide
  skills based on file types. Runs a dev-QA validation loop (max 3 iterations)
  and tracks all progress in the story file. Requires /ck-code:plan to have run.
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

### 1.2 If No Story Path (Interactive)

1. Glob `tasks/*/epics/*/stories/*.md`
2. Read each header to extract: title, status, size, dependencies
3. Filter to `Status: TODO` only
4. Remove stories whose "Blocked by" stories are not `DONE`
5. Sort by: epic number, then story number, then size (S < M < L < XL)
6. Present as a table (see examples). If no stories are ready, tell the user
   to check `tasks/` or run `/ck-code:plan`.

### 1.3 Load Story Context

Once a story is selected, read the full file and extract all structured fields:
**Title**, **Description**, **Acceptance Criteria** (the checklist items),
**Technical Notes**, **Files to Create/Modify** (the action table),
**Dependencies** (blocked by / blocks), **Epic** reference, **Size** (S/M/L/XL).
Then read the parent `EPIC.md` and `ROADMAP.md` (if it exists) for broader context.

### 1.4 Detect Linked GitHub Issues

Search for story and epic issues, store the numbers for `/ck-code:ship`:
```bash
gh issue list --label "story" --state open --json number,title
gh issue list --label "epic"  --state open --json number,title
```
Present the linked issue (or "No linked issue found").

### 1.4 Update Story Status

Edit the story file: `Status: TODO` → `Status: IN PROGRESS`. See
[references/story-template.md](references/story-template.md) for the exact transition.

---

## PHASE 2: SKILL DETECTION & CONTEXT LOADING

### 2.1 Read Project Architecture

Read ALL of these from `docs/architecture/` (if they exist) — do not skip any:
`tech-stack.md`, `folder-structure.md`, `components.md`, `api-contracts.md`,
`database-schema.md`, `dev-guide.md`. Also check `ROADMAP.md` at the project root.

### 2.2 Detect Required Expert Skills

Analyze the story's "Files to Create/Modify" and "Technical Notes":

```
File path                                     → Expert
mobile/, app/, components/, screens/, ui/     → expert-frontend
server/, api/, backend/, services/            → expert-backend
.test., .spec., __tests__/                    → expert-qa (always loaded)
docker/, .github/, ci/, deploy/               → expert-devops
DB migrations, .sql, schema changes           → expert-backend

Technical Notes keyword                       → Expert
"frontend"/"UI"/"component"/"screen"          → expert-frontend
"API"/"endpoint"/"server"/"handler"           → expert-backend
"deploy"/"CI"/"docker"/"pipeline"             → expert-devops
```

**expert-qa is ALWAYS loaded regardless of story type** — it reviews implementation
for test quality and edge cases. Do not skip it.

### 2.3 Detect Required Guide Skills

By file extension in "Files to Create/Modify":
`.rs` → guide-rust; `.cpp/.h/.hpp` → guide-cpp (+ guide-juce if JUCE);
`.ts/.tsx` → guide-typescript; `.tsx` in `mobile/` → guide-react-native;
`.py` → guide-python; `.go` → guide-go; `.java/.kt` → guide-java;
`.swift` → guide-swift; plus any framework-specific guides (guide-axum, guide-juce, etc.).

### 2.4 Load Skills & Warn

**Step 1 — Filesystem check FIRST (mandatory):**
```bash
find .claude/skills -type f -name "*.md" | sort
```
This is the authoritative list. Never claim a skill is missing without running
this first. Skills live in subdirectories (`experts/`, `guides/`) that are not
surfaced by the Skill tool's system listing.

**Step 2 — Load each detected skill:** Try `Skill` tool first
(e.g., `Skill("experts/backend")`); on error, fall back to
`Read(".claude/skills/experts/backend/SKILL.md")` and apply manually.
Always load `experts/qa/SKILL.md` unconditionally.

**Step 3 — Warn about truly missing skills:** If a skill was expected but does NOT
appear in the filesystem check output, ask `Continue without these? YES / GENERATE FIRST`
(see examples). If GENERATE FIRST → tell user to run `/ck-code:team` and come back.

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

### 6.3 Final Green Check

Run full test suite one more time and present the REFACTOR Phase Complete block (see examples).

---

## PHASE 7: QA VALIDATION

The QA expert skills review the work — this is **not** a self-review.

**Preferred subagent_type:** delegate the validation pass to `ck-code:qa-validator`
if available (defined in this plugin's `agents/` folder — runs the test suite,
maps results to acceptance criteria, reports failures with file:line citations).
If the subagent_type is not registered, do the steps below inline.

### 7.0 Load QA Expert Skills (mandatory, do not skip)

Before any QA, load both QA skills directly:
```
Read(".claude/skills/experts/qa/SKILL.md")
Read(".claude/skills/experts/qa-project/SKILL.md")
```
Apply their standards throughout this entire phase. A self-review without loading
these skills does NOT count as QA validation.

### 7.1 Start QA Task

Mark the QA task as `in_progress`.

### 7.2 Acceptance Criteria Verification

For EACH acceptance criterion: confirm a test covers it (should be, from Phase 4),
confirm the implementation fulfills it, mark PASS or FAIL with explanation.

### 7.3 Run Full Test Suite

Run all tests, not just the new ones. Check for regressions in existing tests.

### 7.4 Code Quality Checks

Run all applicable quality tools. Detect which are available per stack — full
command list (TypeScript / Rust / Python / C++ / JUCE) is in
[references/tdd-walkthrough.md](references/tdd-walkthrough.md). Zero compiler
warnings in project-owned files is the quality bar.

### 7.5 Architecture Compliance

Check the implementation against `docs/architecture/`: new files in correct
directories per `folder-structure.md`, API shapes match `api-contracts.md`,
data flow follows `data-flow.md`, DB changes consistent with `database-schema.md`.

### 7.6 Edge Case Analysis

Look for scenarios tests might not cover: null/undefined/empty inputs, concurrent
access (if applicable), resource cleanup (file handles, connections), error
propagation through the call chain.

### 7.7 Present QA Report

Emit the QA Report block (template in [references/examples.md](references/examples.md)).
It must include: per-criterion PASS/FAIL, test totals + new regressions, code
quality results, architecture compliance, edge case coverage, an Issues Found
table with severity, and a final `Verdict: PASS / NEEDS FIXES`.

### 7.8 Handle Results

**If PASS (no issues):** mark QA task as `completed`, proceed to Phase 8.

**If NEEDS FIXES:**
- Present the issues clearly
- Track the QA iteration count (max 3)
- **If iteration < 3:** announce `[N]/3` (see examples), fix each issue (write
  test for it if missing, then fix code), re-run Phase 6 (refactor), then re-run
  Phase 7 (QA) with fresh check.
- **If iteration = 3:** escalate to user with three options — **A) FIX MANUALLY**
  (attempt specific fixes the user suggests), **B) ACCEPT AS-IS** (proceed with
  known issues, document them), **C) ABORT** (stop implementation, revert story
  to TODO status). Exact wording in [references/examples.md](references/examples.md).
  Do NOT silently continue past iteration 3.

---

## PHASE 8: COMPLETION

### 8.1 Update Story File — Status

Edit the story file: `Status: IN PROGRESS` → `Status: DONE`.
**Note:** Per 8.7, this transition only happens after the user confirms manual testing PASS.

### 8.2 Update Story File — Implementation Summary

Append the Implementation Summary block (template in
[references/story-template.md](references/story-template.md)) to the story file.
It must record: TDD iteration count, QA iteration count, tests written, files
created/modified counts, what was implemented, a precise Files Touched list,
SOLID compliance summary, and notes.

**Files Touched precision (mandatory):**
- CREATED files: path only (e.g., `CREATED src/ws/handler.rs`)
- MODIFIED files: path + exact line numbers (e.g., `MODIFIED src/main.rs:12,45-48,92`)
- Use `git diff --stat` and `git diff` to collect precise lines
- No descriptions — paths + line numbers only

### 8.3 Update Story Checklist in Story File

Mark all acceptance criteria as `[x]` checked in the story file.

### 8.4 Update Parent Epic

Read the parent EPIC.md and update the story's status in the stories table to `DONE`.

### 8.5 Update Implementation Plan Subtasks

Mark all subtasks in the story's Implementation Plan section as `[x]` done.

### 8.6 Mark All Claude Tasks Completed

Use TaskUpdate to mark all remaining tasks as `completed`. Use TaskList to show final summary.

### 8.7 User Manual Testing — REQUIRED before marking story DONE

**Do NOT mark the story as DONE or update the EPIC until the user explicitly
confirms PASS here.** The story status must stay IN PROGRESS until manual
verification is complete.

Present the manual-testing prompt (see examples) listing specific scenarios from
the acceptance criteria plus an edge case to try. Ask `Result? PASS / ISSUES`.

- **If ISSUES:** Ask what's wrong, loop back to Phase 5 for targeted fixes.
- **If PASS:** Proceed to update story to DONE, update EPIC, then move to 8.8.

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
- **Language: English** for all output, comments, commit messages, and docs — regardless of spec/story language.

### JUCE Test Runner Rules
When writing JUCE unit tests, always:
- Use `juce::ScopedJuceInitialiser_GUI juceInit;` as the first line of `main()` — prevents CoreMidi/Singleton assertions from `AudioDeviceManager` needing a MessageManager
- Use ASCII-only strings in `beginTest()`, `expect()`, and JUCE String-constructing calls — `juce::String(const char*)` asserts bytes ≤ 127 (use `-` not `—`, `...` not `…`)
- Use a single meaningful assertion instead of looping hundreds of `expect()` calls — e.g. find max amplitude rather than 512 individual sample checks
