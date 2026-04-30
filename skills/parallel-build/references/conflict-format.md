# Conflict Report & QA Output Formats

Reference output templates for Phases 4, 5, and 6.

## Phase 2.1 — Ready Stories Table

```
Ready stories (N available):

 #  Story  Epic                        Size  Deps met
─────────────────────────────────────────────────────
 1  02-05  02 · JUCE Engine            M     02-01 ✓  02-02 ✓
 2  02-06  02 · JUCE Engine            L     02-03 ✓  02-04 ✓
 3  03-01  03 · Rust Server            S     01-01 ✓
 4  03-02  03 · Rust Server            M     01-01 ✓
 5  04-01  04 · Mobile                 S     (no deps)
...

Pick stories to implement (e.g. "1 3 4" or "all"):
```

## Phase 3.5 — Story File & Code Integrity Report

```
Story File & Code Integrity:
─────────────────────────────────────────────────────
  02-05  →  ✓ Status: DONE   ✓ All acceptance criteria checked   ✓ 12 files changed (+347 / -12)
  03-01  →  ✓ Status: DONE   ⚠ Incomplete criteria: "API rate limiting" unchecked
             ⚠ Possible code loss in server/src/handlers.rs  (0 additions, 8 deletions)
  02-06  →  🚫 Status: IN PROGRESS  — story file not updated  →  BLOCKED from merge
             🚫 No implementation detected (empty diff)        →  BLOCKED from merge
─────────────────────────────────────────────────────
Integrity summary:
  ✓ Clean:    02-05
  ⚠ Warnings: 03-01  (proceeds to QA — operator review required at merge)
  🚫 Blocked:  02-06  (worktree kept — fix before merging)
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
  ⚠ Review needed:   story/03-01  (QA failed: clippy errors)
  ✗ Build failed:    story/02-06  (agent error during /ck-code:build)

What would you like to do?
  [1] Merge ready branches now (conflict-free order)
  [2] Review worktrees first, merge manually
  [3] Re-run /ck-code:build on failing stories
```

## Phase 7 — Worktree Cleanup Confirmation

```
Worktree cleanup:
  ✓ removed: agent-XXXXXXXX  (story XX-YY)
  ...
  ✓ git worktree prune complete
  ✓ Only main worktree remains
```
