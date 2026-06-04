---
name: fix
description: Use to diagnose and minimally fix a bug tied to one or more existing stories. Auto-matches story by file/criteria overlap, supports multi-story scope, creates stub stories when functionality is missing, defers when a future TODO already plans the fix. Argument is an optional story file path.
argument-hint: "[path-to-story.md]"
disable-model-invocation: true
---

# Fix — Story-Linked Bug Fix Orchestrator

Diagnose and fix a bug tied to one or more stories. Auto-matches the best story by file/criteria overlap, supports multi-story scope, and creates stub stories in the correct epic when a "bug" turns out to need missing functionality. Always confirms scope before writing.

For a worked bug-fix example, see [references/examples.md](references/examples.md).
For user-facing prompt scripts, see [references/qa-dialogue.md](references/qa-dialogue.md).
For story-file bug section templates, see [references/bug-section-template.md](references/bug-section-template.md).
For the index/epic sync contract, see [`../../references/stories-index.md`](../../references/stories-index.md).

## INPUT

`$ARGUMENTS` is an optional path to the story file. If provided, read it as a starting candidate (Phase 2.5 may still expand scope). If empty, enter interactive story selection (Phase 1.2) with `AUTO` as a supported answer.

## PHASE 1: CANDIDATE STORY SELECTION

**Goal:** Pick the initial candidate story (the scope analyzer in Phase 2.5 may add more).

### 1.1 If Story Path Provided

Read `$ARGUMENTS`, validate it exists and has the expected format, then confirm: "Starting candidate is story [EE-SS]: [Title]. Scope analysis after bug description may expand this — correct?"

### 1.2 If No Story Path (Interactive)

Read `tasks/<slug>/STORIES_INDEX.md` (bootstrap if missing — see [`../../references/stories-index.md`](../../references/stories-index.md) Read Protocol). Filter to `Status: DONE` or `IN PROGRESS`, then present the selection table from `references/qa-dialogue.md` (Phase 1.2). Supported answers:

- A row number / story path → use as candidate.
- `AUTO` → skip manual pick; Phase 2.5 will score every candidate after the bug description.
- `NONE` → ask for a free-form bug description and component; map to a story by file path. If no match, create a standalone bug report (no story linkage) and proceed.

### 1.3 Load Story Context

Once a candidate is selected (or `AUTO`):

**Batch 1 (parallel tool-call message):** read the candidate story file AND parent `EPIC.md` — the index row's `File` column encodes the epic folder, so EPIC.md is computable without parsing the story first.

From the story file extract: acceptance criteria, Files Touched, technical notes, Implementation Summary (from `/ck-code:build`).

**Batch 2 (parallel tool-call message, after parsing Batch 1):** read this bug's **feature doc** — `folder-structure.md` + the feature doc named in the affected feature's `FEATURE_INDEX` `Docs` column (+ `_shared.md` when the bug is cross-cutting). Do not read the retired layer docs; if the `Docs` cell is `—`/missing, read `folder-structure.md` + `_shared.md` and suggest `/ck-code:doc-optimizer sync`. This batch is sequential to Batch 1 but every file inside it is parallel.

For `AUTO`, defer both batches until Phase 2.5 narrows the candidate set.

## PHASE 2: BUG DESCRIPTION

**Goal:** Get a clear bug description from the user.

### 2.1 Ask About the Bug

Present the questionnaire from `references/qa-dialogue.md` (Phase 2.1).

### 2.2 Targeted Follow-ups

Ask at most 1-2 follow-ups (intermittent vs. consistent, trigger input, recent regression). See `references/qa-dialogue.md`.

## PHASE 2.5: SCOPE ANALYSIS (mandatory)

**Goal:** Determine whether the bug is single-story, multi-story, a missing feature, or mixed — and confirm with the user before any code change or story file write.

### 2.5.1 Score Candidate Stories

Read `tasks/<slug>/STORIES_INDEX.md`. Compute relevance scores in **two passes** using the same three signals:

- **File overlap** — does the bug area (paths inferred from the description, error messages, or stack trace) intersect the story's `Files Touched` (DONE / IN PROGRESS) or technical-notes file list (TODO)?
- **Criterion match** — does any acceptance criterion mention the broken behavior?
- **Component / epic match** — does the bug component match the parent epic's scope?

**Pass 1 — `done_in_progress_scores`:** every `DONE` / `IN PROGRESS` row.
**Pass 2 — `todo_scores`:** every `TODO` row. Collect rows scoring ≥ 0.7 into `future_coverage_matches` — these mean the fix is already planned in a future story.

Pick the verdict:
| Verdict | Trigger |
|---|---|
| **A) SINGLE-STORY** | One story scores ≥ 0.7 and no other ≥ 0.5 (in `done_in_progress_scores`) |
| **B) MULTI-STORY** | Two or more existing stories score ≥ 0.5 (in `done_in_progress_scores`) |
| **C) NEW-FEATURE** | No story scores ≥ 0.5 AND symptom describes behavior never built (no matching code path exists) |
| **D) MIXED** | At least one existing story scores ≥ 0.5 AND the bug also requires functionality in epics where no story covers it |
| **E) PLANNED-IN-FUTURE** | `future_coverage_matches` is non-empty. **Takes precedence** over A / B / D when a TODO story matches — present E first; the user may `PROCEED ANYWAY` to fall through to the underlying A / B / D verdict. |

### 2.5.2 Present Scope Report

Use the report in `references/qa-dialogue.md` (Phase 2.5). Wait for explicit `YES` (or `ADJUST` to override the verdict / story set). On `ADJUST`, re-score with the user's overrides and re-present.

**Verdict A fast-path:** when the verdict is A (single-story, no stubs, no sync work), the Phase 2.5 report uses the verdict-A combined prompt — one gate covers both the verdict and the (trivial) story set. **Skip Phase 2.5.5 entirely and proceed to Phase 3 on `YES`.** Verdicts B / D still flow through Phase 2.5.5 separately because the story set adds real information (stubs, epic syncs).

### 2.5.3 Verdict C (NEW-FEATURE) — Defer to /ck-code:design

A new feature must enter the **normal flow** — `design` → `team` → `plan` — not jump straight to story planning. Print the deferral prompt from `references/qa-dialogue.md` (Phase 2.5b), which recommends `/ck-code:design <spec-or-feature-description>` first (it produces the architecture docs that `plan` later consumes). **STOP** unless the user explicitly forces the fix flow (which falls through to verdict D handling). Do NOT create stub stories under verdict C — `design` then `plan` handle that with full architecture context.

### 2.5.4 Verdict E (PLANNED-IN-FUTURE) — Defer to /ck-code:build

Print the deferral prompt from `references/qa-dialogue.md` (Phase 2.5e). Default action is to **STOP** and recommend `/ck-code:build <future-story-path>` for the highest-scoring TODO story in `future_coverage_matches`. The user may type `PROCEED ANYWAY` to force the fix flow — in that case fall through to the original verdict (A / B / D) computed from `done_in_progress_scores` and continue. Do NOT create stub stories under verdict E — the planned story already exists.

### 2.5.5 Verdicts B / D only — Confirm Story Set

_(Skipped for Verdict A — the combined prompt in Phase 2.5.2 already covers it.)_

Present the story-set confirmation from `references/qa-dialogue.md` (Phase 2.5c) listing every story to UPDATE, every stub to CREATE, and every index/epic file to SYNC. Wait for `YES`.

## PHASE 2.6: CREATE STUB STORIES (verdict D only)

**Goal:** Write stub story files in the right epics, then sync the index and parent EPIC.md files in the same phase.

### 2.6.1 Pick Stub IDs

For each missing-functionality slot identified in 2.5.1, pick the next available `EE-SS` ID inside the target epic by reading the epic's existing story numbers in the index (`max(SS) + 1`).

### 2.6.2 Write Stub Story Files

Use the **stub story template** in `references/bug-section-template.md` (Phase 4.5b). Fill `Bug ID`, best-guess `Size`, parent epic name, and 1-3 best-guess acceptance criteria distilled from the bug description (marked `TODO`).

### 2.6.3 Insert Index Rows

For each stub, append a new row to `tasks/<slug>/STORIES_INDEX.md` in `ID` order. Status `TODO`, Size as guessed, `Blocked by: -`, File path relative to the tasks slug folder. Follow the cell-only Edit pattern in [`../../references/stories-index.md`](../../references/stories-index.md).

### 2.6.4 Update Parent EPIC.md

For each stub, append the new story to its parent `EPIC.md` story list (preserve existing ordering, insert by `SS` number). If the EPIC.md format has a story table, add a row there too.

Also Edit `tasks/FEATURE_INDEX.md`: bump the affected feature's `Stories` total for each stub added, and if that feature was `DONE`, roll its `Status` back to `IN PROGRESS` (per [`../../references/feature-index.md`](../../references/feature-index.md)). The feature `Description` already gives this fix its epic-level context — no need to read the epic's stories for that.

### 2.6.5 Verify Sync

After writes, re-read the index and each modified EPIC.md to confirm the new rows / list entries are present. If any write failed (e.g., file lock, malformed table): tell the user `Sync failed — run /ck-code:sync to reconcile.` and continue with the fix flow on the **existing** stories only.

## PHASE 3: SKILL DETECTION & CONTEXT LOADING

**Goal:** Load the right expert and guide skills for the affected code.

### 3.1 Detect & Load Skills

Follow the shared procedure in [`../../references/skill-detection.md`](../../references/skill-detection.md). Experts/guides are matched by each present skill's `paths`/`keywords` frontmatter (anchor tables as fallback) — the slug set is project-derived, not fixed. For bug-fix flows, **both `expert-qa` AND `expert-analyst` are always loaded** (analyst drives root-cause analysis), and `guide-conventions` always loads when present. Architecture-doc reads (Step 1) and skill loads (Step 4b) must each be issued as a single parallel tool-call message — see the batching notes in `skill-detection.md`.

### 3.2 Prepare Systematic Debugging Approach

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

### 4.5 Update Story Files with Bug Details

Immediately after diagnosis (BEFORE planning the fix), append the Bug Report section to **every story file in scope** (single story for verdict A; all stories in the confirmed set for B / D). Use the same `Bug ID` (`BUG-YYYYMMDD-NN`) across all of them. Status: `DIAGNOSING`. Templates: `references/bug-section-template.md` (Phase 4.5 single-story / Phase 4.5b multi-story). This creates a permanent record of the bug and its diagnosis even before the fix begins.

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

### 5.3 Update Story Files with Fix Plan

Append the Fix Plan subsection (status `FIXING`) to the Bug Report section created in Phase 4.5 — in **every** story file in scope. Template: `references/bug-section-template.md` (Phase 5.3).

### 5.4 Confirm Fix Plan

Use the proposed-fix prompt in `references/qa-dialogue.md` (Phase 5.4). Wait for `YES`, `ADJUST`, or `ABORT`.

## PHASE 6: TDD FIX (RED → GREEN)

**Goal:** Fix the bug using TDD — the reproduction test goes red → green.

### 6.1 Verify RED

Re-run the reproduction test from Phase 4. Expected: FAIL. Also write any additional regression tests identified during diagnosis (related patterns from 4.4, edge cases near the root cause).

### 6.2 Apply Minimal Fix

Apply the fix as planned in Phase 5; change ONLY what's necessary (minimal diff); follow SOLID (don't violate SRP by cramming logic); follow loaded guide skill best practices.

If applying the fix forces a change outside the Phase 5 Fix Plan's "Files to modify" list (e.g., a helper file the fix depends on, or a related test that broke), record it in a `## Unplanned Changes` block under the Bug Report section, format `- <path> — <what> — <why minimal fix required it>`. This does NOT authorize widening the fix — it documents minimal expansions that were unavoidable. Drive-by fixes for OTHER bugs remain forbidden (existing rule); those still go in the Phase 4.4 related-issues note for separate `/ck-code:fix` runs. Empty section = omit the heading.

### 6.3 Verify GREEN

Run the reproduction test + all related tests. Expected: ALL pass (including the previously-failing reproduction test).

### 6.4 Refactor & SOLID Verification (REQUIRED)

With tests green, run a SOLID compliance check **bounded to the lines the fix
changed** (the diff produced by Phase 6.2 plus any unplanned-changes additions):

- **S** Single responsibility — does the changed function still have one job?
- **O** Open/closed — was a stable interface modified instead of extended?
- **L** Liskov — does the changed type still honor its contract for callers?
- **I** Interface segregation — was a fat interface widened?
- **D** Dependency inversion — does the fix depend on abstractions, not concretes?

For any principle that fails, apply the **smallest** refactor that resolves it.
Re-run tests after each refactor — must stay green. **Do NOT refactor unrelated
code** — the minimal-fix rule still binds; this check is bounded to the diff.

Record the per-principle PASS/FAIL line under the Bug Report's Resolution
section using the SOLID Verification template in
`references/bug-section-template.md` (Phase 6.4). Then present the
"Fix Applied" status from `references/qa-dialogue.md` (Phase 6.4).

## PHASE 7: QA VALIDATION

**Goal:** QA expert verifies the fix is complete and nothing else broke.

Follow the shared procedure in [`../../references/qa-validation.md`](../../references/qa-validation.md). Bug-fix flows include the **minimalism check** (Step 6) — the fix must be the smallest change that resolves the root cause; no unrelated refactoring.

Skill-specific report and escalation templates: `references/qa-dialogue.md` (Phase 7.5 / 7.6). Iteration cap = 3; on iteration 3 escalate with `MANUAL FIX / ACCEPT / REVERT`. On NEEDS FIXES, loop back to Phase 6.

## PHASE 8: COMPLETION

**Goal:** Update story files, sync index/epic, commit the fix.

### 8.1 Update Story Files — Resolution

Fill the Resolution + Files Touched subsections under the Bug Report in **every** story file in scope. Status: `FIXED`. Template: `references/bug-section-template.md` (Phase 8.1). The Resolution block records an **Unplanned changes count** (from `## Unplanned Changes` under the Bug Report if present, else "none").

**Files Touched precision rules:** for CREATED files use just the path (e.g., `CREATED tests/regression_test.rs`); for MODIFIED files use path + exact line numbers (e.g., `MODIFIED src/handler.rs:34,67-69`); use `git diff --stat` and `git diff` to collect precise lines; no descriptions — just paths and line numbers for quick reference.

### 8.2 Update Story Status

Existing stories: a `DONE` story stays `DONE`, an `IN PROGRESS` story stays `IN PROGRESS` — bug sub-states (`DIAGNOSING` / `FIXING` / `FIXED`) live inside the Bug Report only and never touch `STORIES_INDEX.md`. Stub stories created in Phase 2.6 stay `TODO`.

### 8.3 Update Parent Epic + Index

No change in EPIC.md or `STORIES_INDEX.md` unless a story status changed (it shouldn't here — the bug-fix protocol leaves status alone). The index/epic mutations from Phase 2.6 (stub creation) are already persisted.

### 8.4 Sync Verification

Re-read `STORIES_INDEX.md` and confirm: every stub story file from Phase 2.6 has a matching row, and every existing story in scope still has its row unchanged. If a mismatch appears, tell the user `Index drift detected — run /ck-code:sync to reconcile.` and continue (do not silently rewrite).

### 8.5 Mark All Tasks Completed

Use TaskUpdate to mark all fix-related tasks as `completed`.

### 8.6 User Manual Testing — Strict Revalidation Loop

#### 8.6.1 Present the Manual-Test Prompt

Use the manual-testing prompt in `references/qa-dialogue.md` (Phase 8.5).
Ask `Result? PASS / STILL BROKEN / NEW ISSUE`.

#### 8.6.2 If PASS

Proceed to 8.7 (Ship).

#### 8.6.3 If STILL BROKEN — Mandatory Refactor + QA Loop

The root bug is not fully resolved. Every cycle must re-touch the test, the
code, the SOLID check, AND the QA pass before re-prompting the user.

1. Capture the residual symptom from the user (what still fails, repro).
2. Append an entry to `## Manual-Test Reports` under the Bug Report section in **every** in-scope story file. Status: `OPEN`. Template: `references/bug-section-template.md` (Phase 8.6).
3. Loop back to **Phase 4.2** — write/update the failing reproduction test for the residual symptom (TDD red).
4. Run **Phase 5** (re-plan minimal fix) → **Phase 6 (TDD fix)** → **Phase 6.4 (Refactor & SOLID Verification — MANDATORY)** → **Phase 7 (QA — full procedure)**. The QA 3-iteration cap still applies inside this single cycle.
5. Update the Manual-Test Report entry: status `OPEN` → `RESOLVED`. Append fix summary + Files Touched (`path:line[,line]`).
6. Return to 8.6.1.

#### 8.6.4 If NEW ISSUE

A different bug surfaced during manual test. Decide with the user:
_"Is this related to the same root cause, or a separate bug?"_

- **Related (same root cause)** → treat as 8.6.3 STILL BROKEN; same Bug ID, same loop.
- **Separate bug** → append to Phase 4.4 related-issues note and recommend a separate `/ck-code:fix` run; **do NOT** fix it inside the current flow (the minimal-fix rule still binds).

#### 8.6.5 Iteration Cap

Cap = 3 manual-test loops on the same Bug ID. On the third consecutive
`STILL BROKEN`, escalate with `MANUAL FIX / ACCEPT / REVERT` (template in
`references/qa-dialogue.md` Phase 8.6 escalation). Never silently continue past 3.

### 8.7 Ship (Commit + PR + Issue Updates)

Use the ship prompt in `references/qa-dialogue.md` (Phase 8.7). `SHIP` → invoke `/ck-code:ship` with the **primary** story file path (the highest-scored story from Phase 2.5 for multi-story bugs); it handles branch (`fix/` prefix), staging, commit message, PR, and GitHub Issue updates. The commit body should list every story ID in scope (`Stories: 01-03, 02-01`) plus the `Bug ID`. `SKIP` → remind the user they can run `/ck-code:ship [story-path]` later.

## HARD GATES (cross-phase contract)

Each gate is enforced inside its phase — listed here as a checklist:

- **Version gate** — run the shared [version gate](../../references/version-gate.md) before any architecture-doc read/write; on BLOCK (pre-v3), offer `/ck-code:doc-optimizer upgrade` and stop until it PASSes (or the user declines). `tasks/VERSION.md` = `layout: v3` is the cheap fast path.
- **Phase 2.5** — Scope analysis mandatory, even when `$ARGUMENTS` provides a story path.
- **Phase 2.5.1** — Score `DONE` / `IN PROGRESS` AND `TODO` rows; TODO matches trigger verdict E.
- **Phase 2.5.2 / 2.5.5 / 5.4** — Three confirmation gates; no writes without explicit `YES`.
- **Phase 2.6.3 / 2.6.4** — Stub story + `STORIES_INDEX.md` + parent `EPIC.md` synced in the same phase.
- **Phase 4.2 + 5.0** — Failing reproduction test before any fix code.
- **Phase 6.4 + 7** — SOLID re-check (bounded to changed lines) AND QA pass after every code change.
- **Phase 7** — QA iteration cap = 3 → escalate `MANUAL FIX / ACCEPT / REVERT`.
- **Phase 8.6.5** — Manual-test loop cap = 3 on the same Bug ID → escalate.

### Scope discipline (cross-cutting)

- **Verdict C (NEW-FEATURE)** → defer to `/ck-code:design` (normal flow: design → team → plan). Never create stub stories from the fix flow.
- **Verdict E (PLANNED-IN-FUTURE)** → defer to `/ck-code:build <future-story>`. `PROCEED ANYWAY` falls through to the underlying A/B/D verdict; it does NOT bypass other gates.
- **Minimal fix only.** No refactor, no improvement, no feature. Drive-by fixes for OTHER bugs stay in the Phase 4.4 related-issues note, never inline.
- **Index purity.** `STORIES_INDEX.md` tracks only `TODO` / `IN PROGRESS` / `DONE` / `SKIP`. Bug sub-states (`DIAGNOSING` / `FIXING` / `FIXED`) live inside the Bug Report.
- **Unplanned-change log.** Off-plan file touches → one line in `## Unplanned Changes` under the Bug Report (`- <path> — <what> — <why>`). Empty section = omit heading.

### Universal

- **Same `Bug ID` across all in-scope stories** — format `BUG-YYYYMMDD-NN`.
- **Language: English** for all output.
- **Reusability.** Works with any project using the `tasks/` story format.

---

## NEXT

After QA PASS and the user confirms manual testing, run `/ck-code:ship <story-path>` to commit (`fix/` branch prefix), open the PR, and update the linked GitHub Issues.

To drive the regression loop autonomously, the user can set `/goal "the new regression test passes and the full suite stays green"` (cheap verifier model). See [native-commands.md](../../references/native-commands.md).
