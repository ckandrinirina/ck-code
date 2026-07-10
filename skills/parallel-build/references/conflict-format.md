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

## Phase 6 — Final Summary & Choices

```
Summary:
  ✓ Ready to merge:   story/02-05  (QA passed, no conflicts)
  ◐ Incomplete:       story/03-04  (agent stopped early — partial work in worktree)
  🚫 Stuck:           story/03-07  (auto-continue made 0 progress / too large — never merged)
  ⚠ Review needed:   story/03-01  (QA failed: clippy errors)
  ✗ Build failed:    story/02-06  (agent error / empty diff during /ck-code:build)

Manual testing runs after the merge, on the target branch (Phase 6.5).

What would you like to do?
  [1] Merge ready branches now (conflict-free order)
  [2] Review worktrees first, merge manually
  [3] Continue ◐ incomplete stories in place (resume in existing worktrees)
  [4] Re-dispatch ✗ failed / empty stories from scratch (new worktrees)
```

## Phase 6.5 — Per-Story Manual-Test Prompt

Run sequentially per merged story, in the main checkout on the target branch.

```
Manual test for story XX-YY: [story title]   (merged into <$TARGET>)

Please manually verify — in the main checkout, not a worktree:
- [Specific test scenario 1 from acceptance criteria]
- [Specific test scenario 2]
- [Edge case to try]

Branch:    <$TARGET>  (all merged stories of this batch/wave are present)
Merge SHA: <merge commit>

Result? PASS / ISSUES
```

## Phase 6.5 — Manual-Test Result Table

Print after each story's gate is settled (PASS, accepted, or reverted).

```
Manual-Test Gate (post-merge on <$TARGET>):
─────────────────────────────────────────────────────
  02-05  →  ✓ MANUAL-TEST PASS  (cycle 1)
  03-01  →  ✓ MANUAL-TEST PASS  (cycle 2 — 1 bug fixed on target: BUG-1 timezone offset)
  02-06  →  ↩ REVERTED — 3 cycles exhausted, story reopened IN PROGRESS
─────────────────────────────────────────────────────
```

## Phase 6.5.4 — Escalation Prompt (after 3 cycles)

```
Story XX-YY has run 3 post-merge manual-test bug-fix cycles and issues remain:

Cycles:
  #1  <bug summary>  → FIXED
  #2  <bug summary>  → FIXED
  #3  <bug summary>  → still ISSUES

Options:

A) FIX MANUALLY  — You apply the specific fix on <$TARGET>;
                   Refactor + QA will re-run against your changes
B) ACCEPT AS-IS  — Mark story MANUAL-TEST PASS with #3 as a known issue
C) REVERT        — git revert -m 1 <merge-sha>; story reopens IN PROGRESS in the
                   indexes, its worktree is kept, dependents are held

Reply A / B / C.
```

## Phase 7 — Worktree Cleanup Confirmation

```
Worktree cleanup:
  ✓ removed: agent-XX-YY  (story XX-YY)
  ...
  ✓ git worktree prune complete
  ✓ Only main worktree remains
```
