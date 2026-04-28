# QA & User Dialogue Scripts

Long-form prompts the orchestrator presents to the user across phases. Use
these verbatim (or adapt minor wording) so the workflow stays predictable.

---

## Phase 1.2 — Story Selection (no path provided)

```
## Select the Story with the Bug

| # | Story | Epic | Status |
|---|-------|------|--------|
| 1 | [01-01] Setup server scaffold | Foundation | DONE |
| 2 | [01-02] gRPC service definition | Foundation | DONE |
| 3 | [01-03] WebSocket gateway | Foundation | IN PROGRESS |

Which story has the bug? (enter number, path, or NONE if not story-related)
```

If user answers `NONE`, ask for a free-form bug description and which component
it affects, then try to map to a story by file path. If no story matches,
create a standalone bug report (no story linkage) and proceed to Phase 2.

---

## Phase 2.1 — Bug Description Questionnaire

```
## Describe the Bug

Story: [EE-SS] [Title]

1. What is the expected behavior?
2. What is the actual behavior?
3. Steps to reproduce (if known)?
4. Any error messages or logs?
5. When did it start? (always broken, or regression?)
```

### 2.2 Targeted Follow-ups (max 1-2)
- "Does this happen every time or intermittently?"
- "Which specific input or action triggers it?"
- "Did this work before a recent change?"

---

## Phase 4.6 — Diagnosis Report to User

```
## Bug Diagnosis Report

**Story:** [EE-SS] [Title]
**Bug:** [1-line summary]
**Root cause:** [explanation]
**Location:** [file:line]
**Reproduction test:** Written and FAILING (confirms the bug)
**Story:** Updated with bug details

### Related Issues
- [count] similar patterns found in codebase

### Affected Acceptance Criteria
- [ ] [Criterion X] — BROKEN by this bug
- [x] [Criterion Y] — Still working

Confirm diagnosis and proceed to fix? YES / INVESTIGATE MORE
```

If `INVESTIGATE MORE`: ask which aspect to investigate further, run more
analysis, then re-present.

---

## Phase 5.4 — Fix Plan Confirmation

```
## Proposed Fix

**Root cause:** [1-line]
**Fix:** [1-line description of the change]
**Files to touch:** [count]
**Risk assessment:** [LOW / MEDIUM / HIGH]

Proceed with fix? YES / ADJUST / ABORT
```

Wait for user confirmation before any code change.

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
- [x] Criterion 3 — PASS

### Code Quality
- Type checking: PASS / FAIL
- Linting: PASS / FAIL
- Formatting: PASS / FAIL

### Fix Minimalism: PASS / FAIL
[Notes on any unnecessary changes]

### Verdict: PASS / NEEDS FIXES
```

### After 3 failed iterations — Escalation

```
Fix has been attempted 3 times. Remaining issues:
[list]

Options:
A) MANUAL FIX — I'll try specific fixes you suggest
B) ACCEPT — Proceed with known limitations
C) REVERT — Undo all changes, keep the bug documented
```

---

## Phase 8.5 — User Manual Testing

```
Bug fix complete!

Please verify:
1. The original bug is fixed: [reproduction steps]
2. The feature still works as expected: [acceptance criteria summary]
3. No new issues introduced

Result? PASS / STILL BROKEN / NEW ISSUE
```

- `PASS` → proceed to commit
- `STILL BROKEN` → loop back to Phase 4 (re-diagnose)
- `NEW ISSUE` → document as a new bug, decide whether to fix now or separately

---

## Phase 8.6 — Ship Prompt

```
Ready to ship the fix! Options:

A) SHIP — Run /ck-code:ship to commit, PR, and update GitHub Issues
B) SKIP — Don't commit yet (run /ck-code:ship later manually)
```

If `SHIP`: invoke `/ck-code:ship` with the story file path.
`/ck-code:ship` handles: branch creation (`fix/` prefix), staging, commit
message, PR, and GitHub Issue updates.

If `SKIP`: remind the user they can run `/ck-code:ship [story-path]` later.
