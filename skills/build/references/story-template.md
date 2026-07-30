# Story File Templates

Blocks written to the story file at specific phases of the build skill. **Status lives in
the frontmatter** (`status:`) — the only status mutation is editing that field and running
`ck-index` (SKILL.md 1.6 / 8.6). The blocks below are the free-form **body** additions
(Unplanned Changes, Implementation Summary, checklist, Manual-Test Bugs); the body never
records the plan or a status header.

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

## Phase 8.1 — Implementation Summary (append after QA pass)

```markdown
---

## Implementation Summary

**Completed:** [date]
**TDD Iterations:** [count] (red→green→refactor cycles)
**QA Iterations:** [count]
**Manual-test bugs:** [count, or "none"]
**Tests written:** [count]
**Files created:** [count]
**Files modified:** [count]
**Unplanned changes:** [count, or "none"]

### What Was Implemented

- [Key implementation point 1]
- [Key implementation point 2]

### Files Touched

[Precise reference of every file and line changed — no descriptions, just locations.
CREATED = path only; MODIFIED = path:lines, collected via `git diff`.]

CREATED src/server/ws/handler.rs
CREATED src/server/ws/mod.rs
MODIFIED src/server/main.rs:12,45-48,92
MODIFIED src/server/config.rs:8,23
CREATED tests/ws_handler_test.rs

### SOLID Compliance

- [How SOLID was applied — 1 line per principle]

### Notes

[Any important notes for future developers]
```

---

## Phase 8.2 — Acceptance Criteria Checklist Update

Mark all acceptance criteria as checked in the story file:

```
- [x] Criterion 1
- [x] Criterion 2
- [x] Criterion 3
```

---

## Phase 1.6 / 8.6 — Status Transitions (frontmatter only)

Status is a **frontmatter field** — edit the `status:` line inside the leading `---`
fences, then regenerate the views (`ck-index tasks/<slug>`)
in the same phase. Values are lowercase `todo | in-progress | done | skip | bug`. There is no
`EPIC.md` stories-table row and no index cell to touch — the generator recomputes both views
from this field.

Phase 1.6 (start):

```
status: todo
```
→
```
status: in-progress
```

Phase 8.6 (complete, only after manual-test PASS in 8.5):

```
status: in-progress
```
→
```
status: done
```

Bug-Fix Mode 8.6 restores the pre-bug status instead: `status: bug` → `status: <prior_status>`
(then clear `prior_status`). See [bug-fix-mode.md](bug-fix-mode.md).

---

## Phase 8.5 — Manual-Test Bugs (append on first bug, then per-bug)

Appended via Edit. Skip entirely on a clean run (no heading written when
empty). Add one entry per bug at the moment it is reported, then update the
same entry once `FIXED`.

```markdown
## Manual-Test Bugs

- **#1** [OPEN | FIXED] — <reported date>: <one-line bug description>
  - Repro: <steps>
  - Expected: <expected behaviour>
  - Actual: <actual behaviour>
  - Regression test: <test file>:<test name>
  - Fix: <one-line summary> (only present once status = FIXED)
  - Files: <path:line[,line]> (only present once status = FIXED)
  - Refactor + QA re-run: PASS (<date>)
```

**Format rules:**

- Status starts at `OPEN` and flips to `FIXED` only after Phase 8.5.3 steps 5–7 (Refactor + QA + entry update) complete.
- "Files" follows the same `path:line[,line]` precision as Implementation Summary's Files Touched.
- One entry per bug; if the same code is touched again later, update the existing entry rather than appending a duplicate.
- Empty section = omit the heading (consistent with `## Unplanned Changes`).
