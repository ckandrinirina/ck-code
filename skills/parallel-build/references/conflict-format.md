# Conflict Report & QA Output Formats

Reference output templates for Phases 4, 5, and 6.

## Phase 2.1 — Ready Stories Table

The `Parallel` column comes from Phase 1.4 (declared file-scope overlap):
✓ parallel-safe, or ⚠ overlaps [ID] (build in a separate batch).

```
Ready stories (N available):

 #  Story  Epic                        Size  Deps met            Parallel
──────────────────────────────────────────────────────────────────────────
 1  02-05  02 · JUCE Engine            M     02-01 ✓  02-02 ✓    ✓
 2  02-06  02 · JUCE Engine            L     02-03 ✓  02-04 ✓    ⚠ overlaps 02-05
 3  03-01  03 · Rust Server            S     01-01 ✓             ✓
 4  03-02  03 · Rust Server            M     01-01 ✓             ✓
 5  04-01  04 · Mobile                 S     (no deps)           ✓
...

Recommended parallel-safe set: 02-05  03-01  03-02  04-01
Pick stories to build ("recommended", "all", "1 3 4", or IDs like "02-05 03-01"):
```

## Phase 3.5 — Story File & Code Integrity Report

```
Story File & Code Integrity:
─────────────────────────────────────────────────────
  02-05  →  ✓ Status: DONE   ✓ All acceptance criteria checked   ✓ 12 files changed (+347 / -12)
  03-01  →  ✓ Status: DONE   ⚠ Incomplete criteria: "API rate limiting" unchecked
             ⚠ Possible code loss in server/src/handlers.rs  (0 additions, 8 deletions)
  03-04  →  ◐ Status: IN PROGRESS  — agent stopped early (~99 tool-calls)
             ◐ Real partial work present (+412 / -7, non-empty)  →  INCOMPLETE (resumable)
  02-06  →  🚫 Status: IN PROGRESS  — story file not updated  →  BLOCKED from merge
             🚫 No implementation detected (empty diff)        →  BLOCKED from merge
─────────────────────────────────────────────────────
Integrity summary:
  ✓ Clean:      02-05
  ⚠ Warnings:   03-01  (proceeds to QA — operator review required at merge)
  ◐ Incomplete: 03-04  (worktree kept — Phase 6 "Continue in place" to finish)
  🚫 Blocked:    02-06  (worktree kept — empty diff, re-dispatch fresh before merging)
─────────────────────────────────────────────────────
```

## Phase 4.4 — Conflict Analysis Report

```
Conflict Analysis:
─────────────────────────────────────────────────────
  02-05  →  no conflicts with main
  03-01  →  no conflicts with main

  Cross-branch file overlaps:
    server/src/lib.rs   →  modified by 02-05 AND 03-01  ⚠️

  Suggested merge order (safest first):
    1. story/03-01
    2. story/02-05   (may need rebase after 03-01 merges)
─────────────────────────────────────────────────────
```

If no conflicts at all: print "No conflicts detected — all branches merge cleanly."

## Phase 5 — QA Report

```
QA Report:
─────────────────────────────────────────────────────
  02-05  →  ✓ build passed   ✓ tests passed   ✓ lint clean
  03-01  →  ✓ cargo test     ✗ clippy: 2 warnings treated as errors
             BLOCKED from merge — worktree kept for fix
─────────────────────────────────────────────────────
```

## Phase 5.5 — Per-Story Manual-Test Prompt

Run sequentially per story in the QA-passing set.

```
Manual test for story XX-YY: [story title]

Please manually verify:
- [Specific test scenario 1 from acceptance criteria]
- [Specific test scenario 2]
- [Edge case to try]

Worktree:  <path>
Branch:    story/XX-YY

Result? PASS / ISSUES
```

## Phase 5.5 — Manual-Test Result Table

Print after each story's gate is settled (PASS, BLOCKED, or escalation).

```
Manual-Test Gate:
─────────────────────────────────────────────────────
  02-05  →  ✓ MANUAL-TEST PASS  (cycle 1)
  03-01  →  ✓ MANUAL-TEST PASS  (cycle 2 — 1 bug fixed: BUG-1 timezone offset)
  02-06  →  🚫 BLOCKED — 3 cycles, escalation pending
─────────────────────────────────────────────────────
```

## Phase 5.5.4 — Escalation Prompt (after 3 cycles)

```
Story XX-YY has run 3 manual-test bug-fix cycles and issues remain:

Cycles:
  #1  <bug summary>  → FIXED
  #2  <bug summary>  → FIXED
  #3  <bug summary>  → still ISSUES

Options:

A) FIX MANUALLY  — You apply the specific fix in the worktree;
                   Refactor + QA will re-run against your changes
B) ACCEPT AS-IS  — Mark story MANUAL-TEST PASS with #3 as a known issue
C) ABORT         — Mark story BLOCKED FROM MERGE; keep worktree for review

Reply A / B / C.
```

## Phase 6 — Final Summary & Choices

```
Summary:
  ✓ Ready to merge:   story/02-05  (QA + manual-test passed, no conflicts)
  ◐ Incomplete:       story/03-04  (agent stopped early — partial work in worktree)
  ⚠ Review needed:   story/03-01  (QA failed: clippy errors)
  ⚠ Manual-test blocked: story/04-02  (3 cycles exhausted — escalation pending)
  ✗ Build failed:    story/02-06  (agent error / empty diff during /ck-code:build)

What would you like to do?
  [1] Merge ready branches now (conflict-free order)
  [2] Review worktrees first, merge manually
  [3] Continue ◐ incomplete stories in place (resume in existing worktrees)
  [4] Re-dispatch ✗ failed / empty stories from scratch (new worktrees)
```

## Phase 7 — Worktree Cleanup Confirmation

```
Worktree cleanup:
  ✓ removed: agent-XXXXXXXX  (story XX-YY)
  ...
  ✓ git worktree prune complete
  ✓ Only main worktree remains
```
