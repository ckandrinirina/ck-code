# Story File Templates

Templates appended to the story markdown file at specific phases of the build skill.

---

## Phase 3.5 — Implementation Plan (append before any code)

Appended via Edit. The story file is the source of truth — the plan must exist
in it before work begins, not after the fact.

```markdown

---

## Implementation Plan

**Planned:** [date]
**Skills loaded:** [list of expert/guide skills detected]
**SOLID approach:** [1-line summary]

### Subtasks
1. [ ] Write tests ([count] tests planned)
2. [ ] Implement [component A]
3. [ ] Implement [component B]
4. [ ] Refactor for SOLID compliance
5. [ ] QA validation
6. [ ] Update docs and commit

### Design Notes
[Key design decisions, patterns chosen, abstractions planned]
```

---

## Phase 5 — Unplanned Changes (append on first deviation, then per-change)

Appended via Edit. Skip entirely on a clean run (no heading written when
empty). Add one bullet per unplanned change at the moment it happens.

```markdown

## Unplanned Changes
- <path> — <one-line what> — <why it was needed during the planned work>
```

**Format rules:**
- One bullet per change. Three slash-separated fields: path, what, why.
- "Why" must explain what triggered the change during the planned work
  (e.g., "broke test for AC-2 without it", "needed twice by planned handler",
  "REFACTOR mode — adjacent code").
- If the same file is touched again later, update its existing line in place
  rather than adding a duplicate.
- This section coexists with `Files Touched` — `Files Touched` records every
  file with line numbers; `Unplanned Changes` records only those outside the
  Phase 3 "Files to Create/Modify" plan, with reasoning.

Examples:
- `- src/api/user.ts — added null check in getUser() — broke test for AC-2 without it`
- `- src/queue/retry.go — extracted retryWithBackoff() — needed twice by planned handler, would have duplicated`
- `- tests/helpers/mock_clock.ts — new file — planned tests required time-mocking, not anticipated in Files to Create/Modify`

---

## Phase 8.2 — Implementation Summary (append after QA pass)

```markdown

---

## Implementation Summary

**Completed:** [date]
**TDD Iterations:** [count] (red→green→refactor cycles)
**QA Iterations:** [count]
**Tests written:** [count]
**Files created:** [count]
**Files modified:** [count]
**Unplanned changes:** [count, or "none"]

### What Was Implemented
- [Key implementation point 1]
- [Key implementation point 2]

### Files Touched
[Precise reference of every file and line changed — no descriptions, just locations]

```
CREATED  src/server/ws/handler.rs
CREATED  src/server/ws/mod.rs
MODIFIED src/server/main.rs:12,45-48,92
MODIFIED src/server/config.rs:8,23
CREATED  tests/ws_handler_test.rs
```

### SOLID Compliance
- [How SOLID was applied — 1 line per principle]

### Notes
[Any important notes for future developers]
```

---

## Phase 8.3 — Acceptance Criteria Checklist Update

Mark all acceptance criteria as checked in the story file:

```
- [x] Criterion 1
- [x] Criterion 2
- [x] Criterion 3
```

---

## Phase 8.4 — Parent EPIC.md Stories Table Row

Update the row for this story in the parent epic's stories table:

```
| 01 | [Title] | M | DONE |
```

---

## Phase 8.5 — Implementation Plan Subtasks (final state)

Mark all subtasks in the story's Implementation Plan section as done:

```
1. [x] Write tests (5 tests)
2. [x] Implement server handler
3. [x] Implement client serializer
4. [x] Refactor for SOLID compliance
5. [x] QA validation
6. [x] Update docs and commit
```

---

## Phase 1.4 — Status Transitions

Story status moves through these states. Edit the existing line in the story file.

TODO → IN PROGRESS (Phase 1.4):
```
> **Status:** TODO
```
→
```
> **Status:** IN PROGRESS
```

IN PROGRESS → DONE (Phase 8.1, only after manual testing PASS in 8.7):
```
> **Status:** IN PROGRESS
```
→
```
> **Status:** DONE
```
