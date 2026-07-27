# Output Blocks — Per-Phase Presentation Templates

Compact user-facing blocks the build skill presents on the happy path. Wording is
adaptable; the **data shown** must match the checks performed in `SKILL.md`. Heavier
worked dialogues (interactive selection menu, bug-fix sub-loop) live in `examples.md`.

**Choices are delivered via `AskUserQuestion`, not typed replies.** Each block below is the
*data* to present; the option labels named in it (e.g. SHIP / SKIP, PASS / ISSUES, FIX
MANUALLY / ACCEPT AS-IS / ABORT) are the `AskUserQuestion` options, not a "type X" prompt.

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
```

Then `AskUserQuestion`: **Continue without these** / **Generate first**.

---

## Phase 3.5 — Plan + Branch Confirmation (single gate)

Present the plan data, then run `git branch --show-current` and ask **one**
`AskUserQuestion` that confirms the plan and picks the branch:

```
## Implementation Plan for [Story Title]

**Tests to write:** [count] (from [count] acceptance criteria)
**Files to create:** [list from frontmatter `files:`]
**Files to modify:** [list from frontmatter `files:`]
**SOLID approach:** [summary]
**Estimated subtasks:** [count]
**Current branch:** [name]
```

`AskUserQuestion` options:

- **New branch** — `story/<EE>-<SS>-<slug>` (`fix/…` for a bug story).
- **Current branch `[name]`** — omit when `[name]` is `main`/`develop`.
- **Adjust plan** — revise, then re-ask.

---

## Phase 4.4 / 5.3 / 6.3 — Phase Complete (ONE LINE each)

These three are **progress notes, not gates** — the user takes no action on them. Keep each
to a single line; a heading block per TDD phase spends output tokens and wall-clock on
information already implied by the next phase starting.

```
RED: 7/7 new tests failing ✓ → implementing
GREEN: 7/7 passing ✓ · 3 files created, 1 modified → refactoring
REFACTOR: 7/7 still passing ✓ · 2 refactorings applied → QA
```

Expand to a full block **only when something is off-nominal** — a new test passed during
RED, a refactor broke green, the suite count changed unexpectedly. Then say what and why,
because that *is* actionable.

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
C) ABORT         — stop; set `status: todo` in frontmatter and regenerate
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

## Phase 8.7 — Ship Prompt

```
Ready to ship!
```

Then `AskUserQuestion`:

- **SHIP** — run `/ck-code:ship` to commit, open the PR, and update the linked GitHub Issue.
- **SKIP** — don't commit yet (run `/ck-code:ship [story-path]` later).
