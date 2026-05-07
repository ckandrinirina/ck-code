# Example Dialogues

Reference for the user-facing presentation blocks the build skill emits at
each phase. Wording can be adapted, but the data shown must match the
checks performed in SKILL.md.

---

## Phase 1.2 — Interactive Story Selection Prompt

```
## Stories Ready for Implementation

| # | Story | Epic | Size | Dependencies |
|---|-------|------|------|-------------|
| 1 | [01-01] Setup server scaffold | Foundation | M | None |
| 2 | [01-02] gRPC service definition | Foundation | S | None |
| 3 | [02-01] Plugin scanner | VST/AU Hosting | L | Blocked by 01-01 (done) |

Which story to implement? (enter number or path)
```

If no stories are ready:
```
No unblocked TODO stories found. Check `tasks/` or run `/ck-code:plan` to generate stories.
```

---

## Phase 1.4 — Linked GitHub Issue

```
Linked GitHub Issue: #[number] — [title]
```
or
```
No linked issue found
```

---

## Phase 2.4 — Missing Skills Warning

```
Missing recommended skills:
- guide-rust (not found — run /ck-code:team to create it)

Continue without these? YES / GENERATE FIRST
```

If GENERATE FIRST → tell the user to run `/ck-code:team` and come back.

---

## Phase 3.6 — Plan Confirmation

```
## Implementation Plan for [Story Title]

**Tests to write:** [count] (from [count] acceptance criteria)
**Files to create:** [list]
**Files to modify:** [list]
**SOLID approach:** [summary]
**Estimated subtasks:** [count]

Proceed with TDD implementation? YES / ADJUST
```

Wait for user confirmation.

---

## Phase 4.4 — RED Phase Complete

```
## RED Phase Complete

**Tests written:** [count]
**All failing:** YES (expected)
**Test output:** [summary of failures]

Moving to GREEN phase — implementing to make tests pass.
```

---

## Phase 5.3 — GREEN Phase Complete

```
## GREEN Phase Complete

**Tests passing:** [X]/[X] (all green)
**Files created:** [list]
**Files modified:** [list]

Moving to REFACTOR phase.
```

---

## Phase 6.3 — REFACTOR Phase Complete

```
## REFACTOR Phase Complete

**Refactorings applied:** [count]
**Tests still passing:** [X]/[X] (all green)

Moving to QA validation.
```

---

## Phase 7.7 — QA Report

```
## QA Report: [Story Title]

### Acceptance Criteria
- [x] Criterion 1 — PASS
- [x] Criterion 2 — PASS
- [ ] Criterion 3 — FAIL: [specific reason]

### Test Results
- Total tests: [X]
- Passing: [X]
- Failing: [X]
- New regressions: [X]

### Code Quality
- Type checking: PASS / FAIL
- Linting: PASS / FAIL ([count] warnings)
- Formatting: PASS / FAIL

### Architecture Compliance: PASS / FAIL
[Notes on any deviations]

### Edge Cases
- [Edge case 1]: COVERED / MISSING
- [Edge case 2]: COVERED / MISSING

### Issues Found
| # | Severity | Description | Location |
|---|----------|-------------|----------|
| 1 | HIGH | [issue] | [file:line] |
| 2 | MEDIUM | [issue] | [file:line] |
| 3 | LOW | [issue] | [file:line] |

### Verdict: PASS / NEEDS FIXES
```

---

## Phase 7.8 — QA Loop Messages

When iteration < 3:
```
QA found [X] issues. Looping back to fix.
Iteration: [N]/3
```

When iteration = 3 (escalation):
```
QA has run 3 times and issues remain:
[list remaining issues]

Please review and advise:
A) FIX MANUALLY — I'll attempt specific fixes you suggest
B) ACCEPT AS-IS — Proceed with known issues (I'll document them)
C) ABORT — Stop implementation, revert to TODO status
```

---

## Phase 8.7 — Manual Testing Prompt

```
Story implementation complete!

Please manually test the feature:
- [Specific test scenario 1 from acceptance criteria]
- [Specific test scenario 2]
- [Edge case to try]

Result? PASS / ISSUES
```

---

## Phase 8.5.3 — Bug-Fix Sub-Loop Dialogue

When the user replies `ISSUES`. Each pass MUST go through Refactor + QA before
the next manual-test prompt — the audit trail is the `## Manual-Test Bugs`
section in the story file.

```
You: ISSUES — when I click "Save" with an empty title, the form silently
     resets instead of showing a validation error.

Claude: Captured. Recording bug #1 in the story file.

  ── Bug captured ─────────────────────────────────────────────────────────
  #1  Empty-title save resets the form instead of showing a validation error
      Repro:    Open editor → leave title empty → click Save
      Expected: Inline error "Title is required"; form values preserved
      Actual:   Form clears; no message shown
  ─────────────────────────────────────────────────────────────────────────

  Now: writing a regression test, then fixing, then re-running Refactor + QA.

  [TDD red] tests/editor.test.ts → "shows validation error on empty title save"
            → FAIL (as expected)

  [TDD green] src/editor/save.ts:42-48 — added required-title check
              → all 47 tests pass

  [Phase 6 refactor] SOLID review on src/editor/save.ts → PASS, no changes

  [Phase 7 QA] full suite + lint + arch check → PASS, 0 regressions

  Bug #1 marked FIXED in the story file. Re-running manual test.

Story implementation complete!

Please manually test the feature:
- Save with empty title → should show validation error
- Save with valid title → should persist normally
- Edit existing record → no regression

Result? PASS / ISSUES
```

---

## Phase 8.5.3 — Bug-Fix Escalation (after 3 cycles)

After three manual-test bug-fix iterations on the same story, stop and
escalate. Never silently continue past 3.

```
The manual-test bug-fix loop has run 3 times and issues remain:

Cycles:
  #1  Empty-title save resets the form          → FIXED (cycle 1)
  #2  Date-picker timezone offset               → FIXED (cycle 2)
  #3  Form race condition on rapid double-click → still ISSUES

Options:

A) FIX MANUALLY  — You apply the specific fix; I run Refactor + QA against it
B) ACCEPT AS-IS  — Mark the story DONE with #3 documented as a known issue
C) ABORT         — Revert the story to TODO; do not commit anything

Reply A / B / C.
```

---

## Phase 8.8 — Ship Prompt

```
Ready to ship! Options:

A) SHIP — Run /ck-code:ship to commit, PR, and update GitHub Issues
B) SKIP — Don't commit yet (run /ck-code:ship later manually)
```
