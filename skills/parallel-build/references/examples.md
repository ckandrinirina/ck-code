# Worked Example — Multi-Story Parallel Run

A full walkthrough showing how the skill executes when invoked with three ready stories.

## Setup

User invokes `/ck-code:parallel-build` with no arguments. Three TODO stories exist in
the repo whose dependencies are all DONE: `02-05` (M), `02-06` (L), `03-01` (S).

## Phase 1 — Discovery

Glob finds all `tasks/*/epics/*/stories/*.md`. After parsing each story for `Status:`,
`Size:`, and `Blocked by:`, the resolver identifies three ready stories.

## Phase 2 — Selection

Skill prints the ready table (see `conflict-format.md`) and AskUserQuestion blocks.
User answers `all` → selects 02-05, 02-06, 03-01.

## Phase 3 — Parallel Dispatch

Tier picked from Size, then resolved to a concrete model at dispatch time
(latest in the tier, or operator override via `CK_MODEL_*` env vars):
- 02-05 (M) → `balanced` tier
- 02-06 (L) → `advanced` tier
- 03-01 (S) → `fast` tier

Three Agent calls dispatched in **a single response message** with `isolation: worktree`.
Each agent works in `.claude/worktrees/agent-XXXXXXXX` on branch `story/XX-YY`.

After all three return: 02-05 and 03-01 succeed; 02-06 fails (agent reports compile error).

## Phase 4 — Conflict Analysis

Dry-run merges of 02-05 and 03-01 onto main both clean. `git diff --name-only` shows
that both branches modified `server/src/lib.rs`. Reported as a cross-branch overlap;
suggested order is 03-01 first (smaller change) then 02-05 (rebase if needed).

## Phase 5 — QA

- 02-05 (engine) → cmake build OK
- 03-01 (server) → cargo test OK, clippy clean, fmt clean

Both green. 02-06 already failed in Phase 3 so QA is skipped for it.

## Phase 6 — Cleanup Prompt

Summary printed. User picks `[1] Merge ready branches now`. Skill merges in suggested
order, runs final QA on merged main. All clean.

## Phase 7 — Worktree Cleanup

`git worktree list` shows three agent worktrees. Each removed with `-f -f`.
`git worktree prune` clears stale refs. Final `git worktree list` shows only main.

## Edge Cases Demonstrated

- **Single-story run:** if user had only picked 02-05, the full flow would still run
  (worktree + QA + dry-run merge), only the cross-branch overlap step would be skipped.
- **All agents fail:** Phase 4 onward is skipped; user is prompted in Phase 6 to re-run
  failed stories (option 3).
- **QA failure post-build:** the story's worktree is kept and marked BLOCKED from merge
  so the user can fix in place.
