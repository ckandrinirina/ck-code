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

Which story has the bug? (enter number, path, AUTO to let me pick the best
match after you describe the bug, or NONE if not story-related)
```

- `AUTO` → skip manual pick, go to Phase 2 first, then run Phase 2.5 scope analysis to score candidate stories.
- `NONE` → ask for a free-form bug description and which component it affects, try to map to a story by file path. If no story matches, create a standalone bug report (no story linkage) and proceed to Phase 2.

---

## Phase 2.5 — Scope Analysis Report

Present after the bug description (Phase 2) is captured. Computed by scoring
each candidate story on (a) file overlap with the bug area, (b) acceptance
criteria match, (c) component/epic match.

```
## Scope Analysis

**Bug summary:** [1-line]
**Candidate match:** [SINGLE-STORY | MULTI-STORY | NEW-FEATURE | MIXED]

### Best matches
| Score | Story | Why |
|-------|-------|-----|
| 0.92 | [01-03] WebSocket gateway | bug area overlaps `src/ws/handler.rs` (acceptance criteria #2) |
| 0.41 | [02-01] Login form | shares 1 file but unrelated symptom |

### Verdict
[One of the four verdicts below — pick exactly one]

A) SINGLE-STORY — bug belongs to [EE-SS]. Proceed with the standard fix flow.
B) MULTI-STORY — bug spans [EE-SS], [EE-SS], …. A Bug Report will be appended
   to each story (shared bug ID `BUG-YYYYMMDD-NN`).
C) NEW-FEATURE — bug is actually a missing feature in [N] epic(s). Recommend
   running `/ck-code:plan` (Add Feature or Continue mode) instead. Fix flow
   will STOP after your confirmation.
D) MIXED — real bug in [EE-SS] AND missing piece in [other epic(s)]. I will
   fix the bug here and create stub stories in the missing epics with TODO
   acceptance criteria, marked `Created by fix flow on YYYY-MM-DD`. Enrich
   them later via `/ck-code:plan` Continue mode.

Confirm verdict? YES / ADJUST (specify) / ABORT
```

Wait for explicit `YES` before proceeding. On `ADJUST`, ask which verdict
the user prefers and which stories belong in scope, then re-present.

---

## Phase 2.5b — New-Feature Deferral (verdict C only)

```
## Stop — This Looks Like a New Feature, Not a Bug

What you described isn't a regression in existing implemented code; it's
behavior that was never built. The right tool for this is `/ck-code:plan`,
not `/ck-code:fix`.

Suggested next step:
  /ck-code:plan <path-to-spec-or-feature-description>

Pick mode A (ADD FEATURE) or C (CONTINUE) when prompted, then come back to
`/ck-code:fix` only if a real bug surfaces.

Proceed anyway? NO (recommended — stop here) / YES (force fix flow with stub stories)
```

Default to NO. If the user picks YES, fall through to verdict D handling.

---

## Phase 2.5c — Multi-Story / Stub-Story Confirmation

For verdicts B and D, after the user confirms the verdict, list every story
file that will be touched or created and request a final go-ahead:

```
## Story Set for This Fix

**Bug ID:** BUG-YYYYMMDD-NN

### Will UPDATE (append Bug Report to existing story)
- tasks/<slug>/epics/01_foundation/stories/03_websocket-gateway.md  [01-03]
- tasks/<slug>/epics/02_auth/stories/01_login-form.md                [02-01]

### Will CREATE (new stub story — TODO acceptance criteria)
- tasks/<slug>/epics/03_mobile/stories/04_show-ip.md  [03-04]  (size: S)
- tasks/<slug>/epics/04_desktop/stories/02_write-ip.md [04-02]  (size: S)

### Will SYNC (after writes)
- tasks/<slug>/STORIES_INDEX.md  (insert 2 new rows)
- tasks/<slug>/epics/03_mobile/EPIC.md  (add story 03-04 to story list)
- tasks/<slug>/epics/04_desktop/EPIC.md  (add story 04-02 to story list)

Proceed? YES / ADJUST / ABORT
```

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
