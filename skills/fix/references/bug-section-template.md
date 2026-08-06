# Bug Section Templates for the Story File

Templates appended to the story file across the bug's lifecycle. **`fix` fills the
Bug Report + Fix Plan (Phases 4.5 / 5.2); `build` (Bug-Fix Mode) fills the
Unplanned Changes, SOLID Verification, Manual-Test Reports, and Resolution.** The
story file is the durable hand-off between the two skills.

Bug Report status flow: `DIAGNOSED` (set by `fix`) → `FIXED` (set by `build`).
Story frontmatter status flow: `done → bug` (set by `fix`, with `prior_status` recorded)
→ `done` (restored by `build` from `prior_status`). The indexes are generated views —
`fix`/`build` change frontmatter and run `ck-index`, never edit a cell.

---

## Phase 4.5 — Bug Report (fix — append after diagnosis)

```markdown

---

## Bug Report: [date]

**Bug ID:** BUG-YYYYMMDD-NN
**Reported:** [date]
**Prior status:** [done | in-progress]   <!-- human-readable note; the authoritative value is the frontmatter `prior_status`, which build restores -->
**Status:** DIAGNOSED

### Description
- **Expected:** [expected behavior]
- **Actual:** [actual behavior]
- **Steps to reproduce:** [steps]

### Diagnosis
- **Root cause:** [explanation]
- **Location:** [file:line]
- **Reproduction test:** [test name — written and FAILING, the RED target build inherits]
- **Related issues:** [count]
```

### Bug ID format
`BUG-YYYYMMDD-NN` where `NN` is a zero-padded counter starting at `01` for the
first bug filed on that date in this `tasks/<slug>/` folder. The same ID is
reused across every story touched by a multi-story bug so they can be
cross-referenced.

---

## Phase 4.5b — Multi-Story Bug Report (verdict B / D)

When a bug spans multiple existing stories, append the same Bug Report block
above to each story file with this addition:

```markdown
**Scope:** MULTI-STORY (also appears in: [02-01], [03-04])
```

**Missing functionality** (verdict D) is NOT recorded as a stub here — `fix`
scaffolds a real `todo` story through `/ck-code:plan --quick` instead (SKILL.md
Phase 2.6). `fix` never writes stub story files or index rows itself.

---

## Phase 5.2 — Fix Plan (fix — append to the Bug Report section)

The build contract. `build` (Bug-Fix Mode) implements this verbatim, so it must be
concrete enough to execute without re-diagnosing.

```markdown
### Fix Plan
- **Strategy:** [minimal change and why it fixes the root cause]
- **Files to modify:** [exact paths — minimal]
- **Test target:** [the Phase 4.2 reproduction test that must go GREEN]
- **Risk:** [LOW | MEDIUM | HIGH]
- **SOLID note:** [none, or the smallest abstraction if the minimal fix bends a principle]
```

Bug Report status stays `DIAGNOSED` — `fix` does not apply the fix.

---

## Phase 6.2 — Unplanned Changes (build — append under Bug Report on first deviation)

Written by `build` (Bug-Fix Mode) if applying the Fix Plan forces a touch outside
its `Files to modify` list. Skipped on a clean run (no heading when empty).

```markdown
## Unplanned Changes
- <path> — <one-line what> — <why minimal fix required it>
```

**Format rules:**
- One bullet per change. Three slash-separated fields: path, what, why.
- "Why" must justify the expansion as unavoidable for the minimal fix
  (e.g., "shared helper required by the patched function", "test broke
  because mocked dependency changed signature").
- Does NOT authorize widening the fix — drive-by fixes for OTHER bugs remain
  forbidden; those go in the `fix` Phase 4.4 related-issues note for a separate run.
- If the same file is touched again later, update its existing line in place
  rather than adding a duplicate.

Example:
- `- src/server/ws/types.rs — added optional field to Frame struct — patched handler in handler.rs requires it to round-trip the new error code`

---

## Phase 6.4 — SOLID Verification (build — append under Bug Report after Refactor pass)

Written by `build` (Bug-Fix Mode) once per code-touch cycle. Bounded to the diff —
does not authorize widening the fix.

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
state (must be all PASS to leave the refactor phase). Cycle 1 = initial fix; later
cycles correspond to manual-test loops.

---

## Phase 8.6 — Manual-Test Reports (build — append on STILL BROKEN, then per-cycle)

Written by `build` (Bug-Fix Mode) during its manual-test loop. Skipped on a clean
run (no heading when empty).

```markdown
### Manual-Test Reports
- **Cycle 1** [OPEN | RESOLVED] — <reported date>: <residual symptom>
  - Repro: <steps>
  - Fix: <one-line summary> (only present once status = RESOLVED)
  - Files: <path:line[,line]> (only present once status = RESOLVED)
  - Refactor + QA re-run: PASS (<date>)
```

**Format rules:**
- Status starts at `OPEN` and flips to `RESOLVED` only after the fix + Refactor + QA re-run all complete.
- "Files" follows the same `path:line[,line]` precision as the Resolution block's Files Touched.
- One entry per cycle; the same Bug ID accumulates entries across cycles.
- Empty section = omit the heading (consistent with `## Unplanned Changes`).

---

## Phase 8.1 — Resolution + Files Touched (build — fill in at completion)

Written by `build` (Bug-Fix Mode) when the fix is done. Flips Bug Report status to
`FIXED`, restores the story frontmatter `status` from `prior_status`, and regenerates
the views with `ck-index`, then syncs the board with `ck-project sync`.

```markdown
### Resolution
- **Fixed:** [date]
- **Fix:** [1-line description]
- **Regression tests added:** [count]
- **QA iterations:** [count]
- **Manual-test cycles:** [count, or "none"] (count of `## Manual-Test Reports` entries; "none" if heading absent)
- **Unplanned changes:** [count, or "none"]
- **Status:** FIXED   <!-- frontmatter status restored from prior_status (done); views regenerated, board synced -->

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
