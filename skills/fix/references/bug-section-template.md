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

---

## Phase 5.3 — Fix Plan (append to the Bug Report section)

```markdown
### Fix Plan
- **Strategy:** [minimal fix description]
- **Files to modify:** [list]
- **Status:** FIXING
```

---

## Phase 8.1 — Resolution + Files Touched (fill in at completion)

```markdown
### Resolution
- **Fixed:** [date]
- **Fix:** [1-line description]
- **Regression tests added:** [count]
- **QA iterations:** [count]
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
