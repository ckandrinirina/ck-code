# Example Dialogues

User-facing presentation blocks the build skill emits at each phase. Wording is adaptable; the **data shown** must match the checks performed in `SKILL.md`.

---

## Phase 1.2 — Interactive Story Selection

The menu leads with the **parallel** option whenever ≥ 2 ready stories are conflict-free,
then whole-epic wave builds, then single stories. Picking parallel hands off to
`/ck-code:parallel-build "<ids>"` (which dispatches one worktree agent per story, no
re-prompt); picking an epic hands off to `/ck-code:parallel-build --epic NN`.

```
## Stories Ready for Implementation

| # | Story | Epic | Size | Dependencies |
|---|-------|------|------|-------------|
| 1 | [01-04] Abort on SOKA reject | 01 | M | None |
| 2 | [01-02] Paid abandon grace   | 01 | L | None |
| 3 | [02-01] Free-private → 0 pts | 02 | M | None |

## ⚡ Recommended — build in parallel (isolated worktrees, one agent each)

| #  | Set                      | Builds via                          |
|----|--------------------------|-------------------------------------|
| P  | 01-04, 01-02, 02-01 (3)  | parallel-build "01-04 01-02 02-01"  |

## Or build a whole epic in dependency-ordered waves (drives every story to DONE)

| #  | Epic    | Remaining | Builds via                |
|----|---------|-----------|---------------------------|
| E1 | Epic 01 | 2 stories | parallel-build --epic 01  |
| E2 | Epic 02 | 2 stories | parallel-build --epic 02  |

Pick P to build the parallel set, an epic (E1/E2) for waves, or a single story (number/path).
```

**Routing (the selection is the single confirm — the downstream skill does not re-prompt):**
- **Parallel set (P)** → statuses stay `TODO` (skip SKILL.md 1.3–1.6); call `Skill("ck-code:parallel-build", "<id1> <id2> ...")` and exit. parallel-build receives explicit IDs, skips its own selection, and dispatches one worktree agent per story.
- **Epic (E1/E2)** → statuses stay `TODO`; call `Skill("ck-code:parallel-build", "--epic NN")` and exit — parallel-build owns the wave loop.
- **Single story** → proceed to SKILL.md 1.3; Phase 1.4 does NOT re-offer parallel/epic.

Do NOT glob `tasks/*/epics/*/stories/*.md` — read only the ready stories' `Files to
Create/Modify` tables, located via the index `File` column.

If none ready:
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

## Phase 7.7 — QA Report

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

## Phase 7.8 — QA Loop Messages

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

## Phase 8.5.3 — Bug-Fix Sub-Loop (worked example)

When the user replies `ISSUES`, each cycle MUST run all 8 sub-steps before re-prompting (capture → log → red test → fix → refactor → QA → mark FIXED → re-prompt). The audit trail is the `## Manual-Test Bugs` section in the story file.

```
You: ISSUES — when I click "Save" with an empty title, the form silently
     resets instead of showing a validation error.

Claude: Captured. Recording bug #1.

  [TDD red]    tests/editor.test.ts → "shows validation error on empty title" → FAIL
  [TDD green]  src/editor/save.ts:42-48 — added required-title check → 47/47 pass
  [Refactor]   SOLID review on src/editor/save.ts → PASS
  [QA]         full suite + lint + arch → PASS, 0 regressions

  Bug #1 marked FIXED. Re-running manual test.

Please manually test:
- Save with empty title → should show validation error
- Save with valid title → should persist normally

Result? PASS / ISSUES
```

---

## Phase 8.5.3 — Escalation (after 3 cycles)

```
The manual-test bug-fix loop has run 3 times and issues remain:

  #1  Empty-title save resets the form          → FIXED (cycle 1)
  #2  Date-picker timezone offset               → FIXED (cycle 2)
  #3  Form race condition on rapid double-click → still ISSUES

A) FIX MANUALLY — you apply the fix; I run Refactor + QA against it
B) ACCEPT AS-IS — mark story DONE; #3 documented as known issue
C) ABORT        — revert story to TODO; do not commit

Reply A / B / C.
```

---

## Phase 8.8 — Ship Prompt

```
Ready to ship! Options:

A) SHIP — Run /ck-code:ship to commit, PR, and update GitHub Issues
B) SKIP — Don't commit yet (run /ck-code:ship later manually)
```
