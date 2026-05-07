# Bug Section Templates for the Story File

These templates are appended to the original story file across phases. The bug
report is written immediately after diagnosis (Phase 4.5), the Fix Plan section
is added in Phase 5.3, and the Resolution section is filled in at completion
(Phase 8.1).

---

## Phase 4.5 — Bug Report (append after diagnosis, before fix planning)

```markdown

---

## Bug Report: [date]

**Bug ID:** BUG-YYYYMMDD-NN
**Reported:** [date]
**Status:** DIAGNOSING

### Description
- **Expected:** [expected behavior]
- **Actual:** [actual behavior]
- **Steps to reproduce:** [steps]

### Diagnosis
- **Root cause:** [explanation]
- **Location:** [file:line]
- **Reproduction test:** [test name]
- **Related issues:** [count]
```

This creates a permanent record of the bug and its diagnosis even before the
fix begins.

### Bug ID format
`BUG-YYYYMMDD-NN` where `NN` is a zero-padded counter starting at `01` for the
first bug filed on that date in this `tasks/<slug>/` folder. The same ID is
reused across every story touched by a multi-story bug so they can be
cross-referenced.

---

## Phase 4.5b — Multi-Story Bug Report (verdict B / D)

When a bug spans multiple existing stories, append the same Bug Report block
above to each story file with these additions:

```markdown
**Scope:** MULTI-STORY (also appears in: [02-01], [03-04])
```

For stub stories created from a fix-flow scope (verdict D), use the **stub
story template** below instead of the full epic-derived template — the
acceptance criteria and tech notes will be filled in later by the user (or by
`/ck-code:plan` Continue mode).

### Stub story template
```markdown
# Story EE-SS: [Title]

**Status:** TODO
**Size:** [S | M | L | XL — best guess from scope analysis]
**Created by:** /ck-code:fix on YYYY-MM-DD (bug BUG-YYYYMMDD-NN)
**Parent epic:** [epic display name]

## Context
This story was created as part of fixing BUG-YYYYMMDD-NN, which surfaced
missing functionality in this epic. See the linked stories for the full bug
context: [01-03], [02-01].

## Acceptance Criteria (TODO — enrich via `/ck-code:plan` continue)
- [ ] [Best-guess criterion 1 from bug description]
- [ ] [Best-guess criterion 2]

## Technical Notes
TODO — enrich during planning.

## Dependencies
[List of story IDs that must complete first, or `-`]
```

---

## Phase 5.3 — Fix Plan (append to the Bug Report section)

```markdown
### Fix Plan
- **Strategy:** [minimal fix description]
- **Files to modify:** [list]
- **Status:** FIXING
```

---

## Phase 6.2 — Unplanned Changes (append under Bug Report on first deviation)

Appended via Edit. Skip entirely on a clean run (no heading written when
empty). Add one bullet per unplanned expansion at the moment it happens.

```markdown
## Unplanned Changes
- <path> — <one-line what> — <why minimal fix required it>
```

**Format rules:**
- One bullet per change. Three slash-separated fields: path, what, why.
- "Why" must justify the expansion as unavoidable for the minimal fix
  (e.g., "shared helper required by the patched function", "test broke
  because mocked dependency changed signature").
- This does NOT authorize widening the fix. Drive-by fixes for OTHER bugs
  remain forbidden — those go in the Phase 4.4 related-issues note for
  separate `/ck-code:fix` runs.
- If the same file is touched again later, update its existing line in place
  rather than adding a duplicate.

Example:
- `- src/server/ws/types.rs — added optional field to Frame struct — patched handler in handler.rs requires it to round-trip the new error code`

---

## Phase 6.4 — SOLID Verification (append under Bug Report after Refactor pass)

Appended once per code-touch cycle (initial fix and every Phase 8.6 manual-test
loop). Bounded to the diff produced by Phase 6.2 — does not authorize widening
the fix.

```markdown
### SOLID Verification (cycle [N])
- **S** Single responsibility — PASS / FAIL [: 1-line note if FAIL]
- **O** Open/closed             — PASS / FAIL [: note]
- **L** Liskov substitution     — PASS / FAIL [: note]
- **I** Interface segregation   — PASS / FAIL [: note]
- **D** Dependency inversion    — PASS / FAIL [: note]
- **Refactor applied:** [1-line summary, or "none — all PASS"]
```

If any principle was FAIL on first check, the entry records the post-refactor
state (must be all PASS to leave Phase 6.4). Cycle 1 = initial fix; later
cycles correspond to Phase 8.6 manual-test loops.

---

## Phase 8.6 — Manual-Test Reports (append on STILL BROKEN, then per-cycle)

Appended via Edit. Skip entirely on a clean run (no heading written when
empty). Add one entry per manual-test cycle that returned `STILL BROKEN`,
then update the same entry once `RESOLVED`.

```markdown
### Manual-Test Reports
- **Cycle 1** [OPEN | RESOLVED] — <reported date>: <residual symptom>
  - Repro: <steps>
  - Fix: <one-line summary> (only present once status = RESOLVED)
  - Files: <path:line[,line]> (only present once status = RESOLVED)
  - Refactor + QA re-run: PASS (<date>)
```

**Format rules:**
- Status starts at `OPEN` and flips to `RESOLVED` only after Phase 8.6.3 steps 3–5 (Phase 4.2 → Phase 6 → Phase 6.4 → Phase 7) all complete.
- "Files" follows the same `path:line[,line]` precision as the Resolution block's Files Touched.
- One entry per cycle; the same Bug ID accumulates entries across cycles.
- Empty section = omit the heading (consistent with `## Unplanned Changes`).

---

## Phase 8.1 — Resolution + Files Touched (fill in at completion)

```markdown
### Resolution
- **Fixed:** [date]
- **Fix:** [1-line description]
- **Regression tests added:** [count]
- **QA iterations:** [count]
- **Manual-test cycles:** [count, or "none"] (count of `## Manual-Test Reports` entries; "none" if heading absent)
- **Unplanned changes:** [count, or "none"]
- **Status:** FIXED

### Files Touched
[Precise reference of every file and line changed — no descriptions, just locations]

```
MODIFIED src/server/ws/handler.rs:34,67-69
CREATED  tests/ws_handler_regression_test.rs
```
```

### Files Touched format rules
- For CREATED files: just the path (e.g., `CREATED tests/regression_test.rs`)
- For MODIFIED files: path + exact line numbers (e.g., `MODIFIED src/handler.rs:34,67-69`)
- Use `git diff --stat` and `git diff` to collect precise lines after the fix
- No descriptions — just paths and line numbers for quick reference
