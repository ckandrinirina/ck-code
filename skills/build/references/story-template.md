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
