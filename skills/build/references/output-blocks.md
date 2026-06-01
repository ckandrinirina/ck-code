# Output Blocks — Per-Phase Presentation Templates

Compact user-facing blocks the build skill presents on the happy path. Wording is
adaptable; the **data shown** must match the checks performed in `SKILL.md`. Heavier
worked dialogues (interactive selection menu, bug-fix sub-loop) live in `examples.md`.

---

## Phase 1.5 — Linked GitHub Issue

```
Linked GitHub Issue: #[number] — [title]
```

or

```
No linked issue found
```

---

## Phase 2 — Missing Skills Warning

```
Missing recommended skills:
- guide-rust (not found — run /ck-code:team to create it)

Continue without these? YES / GENERATE FIRST
```

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

---

## Phase 4.4 / 5.3 / 6.3 — Phase Complete Status Blocks

Same pattern, different phase label. Substitute `<PHASE>` with `RED` / `GREEN` / `REFACTOR`:

```
## <PHASE> Phase Complete

**Tests:** [X]/[X] (RED: all failing; GREEN/REFACTOR: all passing)
**Files created / modified:** [list]  (omit for REFACTOR if no new files)
**Refactorings applied:** [count]      (REFACTOR only)

Moving to <next phase>.
```

---

## Phase 7 — QA Report

```
## QA Report: [Story Title]

### Acceptance Criteria
- [x] Criterion 1 — PASS
- [ ] Criterion 3 — FAIL: [specific reason]

### Test Results
- Total: [X]  Passing: [X]  Failing: [X]  New regressions: [X]

### Code Quality
- Type checking / Linting / Formatting: PASS / FAIL

### Architecture Compliance: PASS / FAIL
[Notes on deviations]

### Edge Cases
- [Edge case]: COVERED / MISSING

### Issues Found
| # | Severity | Description | Location |
|---|----------|-------------|----------|
| 1 | HIGH | [issue] | [file:line] |

### Verdict: PASS / NEEDS FIXES
```

---

## Phase 7 — QA Loop Messages

Iteration < 3:

```
QA found [X] issues. Looping back to fix.
Iteration: [N]/3
```

Iteration = 3 (escalation):

```
QA has run 3 times and issues remain:
[list]

A) FIX MANUALLY  — apply specific fixes you suggest
B) ACCEPT AS-IS  — proceed with known issues (documented)
C) ABORT         — stop, revert to TODO
```

---

## Phase 8.5 — Manual Testing Prompt

```
Story implementation complete!

Please manually test the feature:
- [Specific test scenario 1 from acceptance criteria]
- [Specific test scenario 2]
- [Edge case to try]

Result? PASS / ISSUES
```

---

## Phase 8.8 — Ship Prompt

```
Ready to ship! Options:

A) SHIP — Run /ck-code:ship to commit, PR, and update GitHub Issues
B) SKIP — Don't commit yet (run /ck-code:ship later manually)
```
