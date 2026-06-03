# QA & User Dialogue Scripts

User-facing prompts emitted by the `fix` skill, indexed by phase. Use verbatim or with minor wording adjustments so the workflow stays predictable. Phase branching logic lives in `SKILL.md`; this file is templates only.

---

## Phase 1.2 — Story Selection (no path provided)

```
## Select the Story with the Bug

| # | Story | Epic | Status |
|---|-------|------|--------|
| 1 | [01-01] Setup server scaffold | Foundation | DONE |
| 2 | [01-02] gRPC service definition | Foundation | DONE |
| 3 | [01-03] WebSocket gateway | Foundation | IN PROGRESS |

Which story has the bug? (number, path, AUTO, or NONE)
```

---

## Phase 2.1 — Bug Description Questionnaire

```
## Describe the Bug

Story: [EE-SS] [Title]

1. Expected behavior?
2. Actual behavior?
3. Steps to reproduce?
4. Error messages or logs?
5. When did it start? (always / regression?)
```

### Phase 2.2 — Targeted Follow-ups (max 1-2)
- "Does this happen every time or intermittently?"
- "Which specific input or action triggers it?"
- "Did this work before a recent change?"

---

## Phase 2.5 — Scope Analysis Report

```
## Scope Analysis

**Bug summary:** [1-line]
**Verdict:** [SINGLE-STORY | MULTI-STORY | NEW-FEATURE | MIXED | PLANNED-IN-FUTURE]

### Best matches (DONE / IN PROGRESS)
| Score | Story | Why |
|-------|-------|-----|
| 0.92 | [01-03] WebSocket gateway | overlaps `src/ws/handler.rs` (criterion #2) |
| 0.41 | [02-01] Login form | shares 1 file but unrelated symptom |

### Future coverage (TODO — only when any score ≥ 0.5)
| Score | Story | Why |
|-------|-------|-----|
| 0.91 | [04-02] Validate profile fields | criterion match + file overlap |

### Verdict
A) SINGLE-STORY — bug belongs to [EE-SS]. Standard fix flow.
B) MULTI-STORY — bug spans [EE-SS], [EE-SS], …. Shared Bug ID `BUG-YYYYMMDD-NN`.
C) NEW-FEATURE — missing functionality in [N] epic(s). Recommend `/ck-code:plan`. STOP after confirm.
D) MIXED — real bug in [EE-SS] AND missing piece elsewhere. Fix here + create stubs marked `Created by fix flow on YYYY-MM-DD`.
E) PLANNED-IN-FUTURE — TODO story [EE-SS] [Title] already plans this. Default STOP; recommend `/ck-code:build <future-story>`. Override `PROCEED ANYWAY` falls through to A/B/D.

Confirm verdict? YES / ADJUST / ABORT
```

### Verdict A — Combined Prompt (fast-path, replaces Phase 2.5.5 gate)

When the verdict is A (single-story), append this block to the scope report instead of the generic verdict prompt above — it folds the verdict confirmation and the (trivial) story-set confirmation into one gate:

```
**Scope:** single-story `[EE-SS] [Title]` (no stubs to create, no index/epic sync needed).

Proceed with fix on this story? YES / ADJUST / ABORT
```

On `YES`: go directly to Phase 3 (no Phase 2.5.5 gate). On `ADJUST`: re-score with overrides and re-present. Verdicts B / D continue to use Phase 2.5.5 separately.

---

## Phase 2.5b — New-Feature Deferral (verdict C)

```
## Stop — This Looks Like a New Feature, Not a Bug

What you described isn't a regression — it's behavior that was never built. A new feature goes through the normal flow, which starts with architecture: `design` → `team` → `plan`. Don't skip straight to story planning.

Suggested next step:
  /ck-code:design <path-to-spec-or-feature-description>

`design` produces the architecture docs that `plan` later turns into epics and stories.

Proceed anyway? NO (recommended — stop) / YES (force fix flow with stub stories)
```

Default to NO. On YES: fall through to verdict D handling.

---

## Phase 2.5e — Future-Story Coverage Deferral (verdict E)

```
## Stop — A Future Story Already Plans This Fix

The bug is already covered by acceptance criteria in a planned TODO story. Fixing now would duplicate planned work.

**Future stories covering this fix:**
- [EE-SS] [Title] (score: 0.XX) — matched on: [files / criteria / component]

Suggested next step:
  /ck-code:build tasks/<slug>/epics/<epic>/stories/<file>.md

That run implements the fix as part of the planned story.

Proceed anyway? NO (recommended) / PROCEED ANYWAY (force fix now)
```

Default to NO. On PROCEED ANYWAY: fall through to the A/B/D verdict from `done_in_progress_scores`. Never create stub stories under verdict E.

---

## Phase 2.5c — Multi-Story / Stub-Story Confirmation (verdicts B / D)

```
## Story Set for This Fix

**Bug ID:** BUG-YYYYMMDD-NN

### Will UPDATE (append Bug Report)
- tasks/<slug>/epics/01_foundation/stories/03_websocket-gateway.md  [01-03]
- tasks/<slug>/epics/02_auth/stories/01_login-form.md                [02-01]

### Will CREATE (new stub story — TODO criteria)
- tasks/<slug>/epics/03_mobile/stories/04_show-ip.md   [03-04]  (size: S)
- tasks/<slug>/epics/04_desktop/stories/02_write-ip.md [04-02]  (size: S)

### Will SYNC
- tasks/<slug>/STORIES_INDEX.md  (+2 rows)
- tasks/<slug>/epics/03_mobile/EPIC.md  (add 03-04 to story list)
- tasks/<slug>/epics/04_desktop/EPIC.md  (add 04-02 to story list)

Proceed? YES / ADJUST / ABORT
```

---

## Phase 4.6 — Diagnosis Report

```
## Bug Diagnosis Report

**Story:** [EE-SS] [Title]
**Bug:** [1-line summary]
**Root cause:** [explanation]
**Location:** [file:line]
**Reproduction test:** Written and FAILING (confirms the bug)
**Story:** Updated with bug details

### Related Issues
- [count] similar patterns found

### Affected Acceptance Criteria
- [ ] [Criterion X] — BROKEN by this bug
- [x] [Criterion Y] — Still working

Confirm and proceed to fix? YES / INVESTIGATE MORE
```

---

## Phase 5.4 — Fix Plan Confirmation

```
## Proposed Fix

**Root cause:** [1-line]
**Fix:** [1-line]
**Files to touch:** [count]
**Risk:** [LOW / MEDIUM / HIGH]

Proceed? YES / ADJUST / ABORT
```

---

## Phase 6.4 — Fix Applied Status

```
## Fix Applied

**Reproduction test:** NOW PASSING
**All tests:** [X]/[X] passing
**Files changed:** [count]
**Lines changed:** [count]
**Refactor applied:** YES (describe) / NO

Moving to QA validation.
```

---

## Phase 7.5 — QA Report

```
## QA Report: Bug Fix for [Story Title]

### Bug Fix Verification
- [x] Reproduction test passes
- [x] Root cause addressed
- [x] Related patterns checked

### Regression Check
- All tests: [X]/[X] passing
- New regressions: [count]

### Acceptance Criteria (full re-check)
- [x] Criterion 1 — PASS
- [x] Criterion 2 — PASS (was broken, now fixed)

### Code Quality
- Type checking / Linting / Formatting: PASS / FAIL

### Fix Minimalism: PASS / FAIL
[Notes on any unnecessary changes]

### Verdict: PASS / NEEDS FIXES
```

### Phase 7.6 — Escalation (after 3 failed iterations)

```
Fix has been attempted 3 times. Remaining issues:
[list]

A) MANUAL FIX — apply specific fixes you suggest
B) ACCEPT     — proceed with known limitations
C) REVERT     — undo all changes, keep bug documented
```

---

## Phase 8.5 — User Manual Testing

```
Bug fix complete!

Please verify:
1. Original bug is fixed: [reproduction steps]
2. Feature still works: [acceptance criteria summary]
3. No new issues introduced

Result? PASS / STILL BROKEN / NEW ISSUE
```

---

## Phase 8.6 — Manual-Test Escalation (after 3 cycles)

```
The manual-test bug-fix loop has run 3 times for BUG-YYYYMMDD-NN and issues remain:

Cycles:
  #1  <residual symptom>  → RESOLVED (cycle 1)
  #2  <residual symptom>  → RESOLVED (cycle 2)
  #3  <residual symptom>  → still STILL BROKEN

A) MANUAL FIX — you apply the fix; I re-run Refactor + QA against it
B) ACCEPT     — mark fix DONE; cycle #3 documented as known limitation
C) REVERT     — undo all changes; bug stays documented, unfixed

Reply A / B / C.
```

---

## Phase 8.7 — Ship

```
Ready to ship the fix! Options:

A) SHIP — Run /ck-code:ship to commit, PR, and update GitHub Issues
B) SKIP — Don't commit yet (run /ck-code:ship later manually)
```

On `SHIP`: invoke `/ck-code:ship` with the story file path (handles `fix/` branch, staging, commit, PR, issue updates).
On `SKIP`: remind the user they can run `/ck-code:ship [story-path]` later.
