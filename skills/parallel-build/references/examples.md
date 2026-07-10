# Worked Example — Multi-Story Parallel Run

A walkthrough of a run invoked with no arguments, resolving to three ready stories.

## Setup

`/ck-code:parallel-build`, no arguments. In the selected feature's epic, three TODO
stories have all their `Blocked by` IDs `DONE`: `02-05` (M), `02-06` (M), `03-01` (S).

## Phase 1 — Discovery

The feature gate reads `tasks/FEATURE_INDEX.md` and auto-selects the single unfinished
feature. Its `STORIES_INDEX.md` is Read and filtered to the epic — **no story file is
read at this phase**; the index carries `Status`, `Size`, and `Blocked by`. The resolver
marks the three rows ready.

Phase 1.4 then extracts *only* each ready story's `Files to Create/Modify` table (batched
`awk`, never a full Read) and finds no shared paths → all three are parallel-safe.

## Phase 2 — Selection

The ready table prints (format in `conflict-format.md`) and AskUserQuestion blocks. The
user answers `all` → 02-05, 02-06, 03-01. Three stories, so Phase 2.5's lean N=1 path does
not apply — full parallel dispatch.

## Phase 3 — Parallel Dispatch

`$TARGET` / `$TARGET_SHA` are frozen first (Phase 3.0). Tier is picked per story from
**reasoning complexity, never `Size:`**, then resolved to a concrete model at dispatch:

- 02-05 (M · routine CRUD/wiring) → `balanced` (Sonnet)
- 02-06 (M · routine UI) → `balanced` (Sonnet)
- 03-01 (S · novel scheduling algorithm) → `advanced` (Opus) — small, but the reasoning escalates it

The orchestrator first creates three worktrees itself — `.claude/worktrees/agent-XX-YY`, each
on a fresh `story/XX-YY` cut from `$TARGET_SHA` (no branch-name collisions). Then three Agent
calls in **one response message**, **no `isolation` parameter**, each prompt carrying its
absolute worktree path and the STEP-0 guard.

On return: 02-05 reports SUCCESS, 03-01 reports SUCCESS, 02-06 reports a compile error (✗ failed).

## Phase 3.5 — Integrity Verification

Every worktree is WIP-committed, and each branch's base is **asserted** to be `$TARGET_SHA`
(it was cut there at launch, so this is a check, not a rebase). The agents' self-reports
are **not** the outcome of record: 02-05 and 03-01 are confirmed ✓ COMPLETE from their
worktrees (story file `DONE`, all criteria `[x]`, clean tree, non-empty diff). 02-06 is ✗
failed and excluded from the merge-candidate set.

## Phase 4 — Conflict Analysis

`ck-code:conflict-analyzer` dry-run merges both candidates onto the frozen `$TARGET` —
both clean. It reports one cross-branch overlap (`server/src/lib.rs`, touched by both) and
suggests 03-01 first, then 02-05.

## Phase 5 — QA

One `ck-code:qa-validator` (Haiku) agent per candidate, dispatched in a single message,
each running its component's detected stack commands **inside its own worktree**. Both
return PASS. 02-06 is not a QA candidate.

## Phase 6 — Merge & Reconcile

The user picks `[1] Merge ready branches now`. Branches merge into `$TARGET` in the
suggested order. The orchestrator then reconciles the shared indexes **once** on the
target: `STORIES_INDEX.md` status cells → `DONE`, each parent `EPIC.md` row → `DONE`, and
the `FEATURE_INDEX.md` rollup recomputed. Final QA on the merged target passes.

02-06 (✗ failed, empty of salvageable work) is offered under Option 4 — re-dispatch from
scratch in a new worktree.

## Phase 6.5 — Post-Merge Manual Test Gate

With both stories merged, the operator runs the app once from the main checkout on
`$TARGET` — no per-worktree install, and 02-05's UI is testable against 03-01's endpoint.
02-05 `PASS` on cycle 1. 03-01 reports `ISSUES` (timezone offset); a bug-fix agent commits
a regression test + fix **on `$TARGET`**, and cycle 2 passes.

## Phase 7 — Worktree Cleanup

Each `.claude/worktrees/agent-*` removed with `git worktree remove -f -f`, then
`git worktree prune`. Only the main tree remains.

## Edge cases demonstrated

- **Single-story batch:** had the user picked only 02-05, Phase 2.5's lean N=1 path would
  still dispatch one worktree agent — same pipeline, only cross-branch overlap detection
  (Phase 4.3) is skipped. The orchestrator never builds inline.
- **◐ incomplete (not failed):** an agent that stops mid-build without an error keeps its
  worktree and is finished by Phase 6 **Option 3** (continue in place, loop until the ✓
  COMPLETE gate passes), never re-dispatched from scratch.
- **✗ failed / empty diff:** re-dispatched fresh under **Option 4**.
- **QA failure post-build:** the worktree is kept and the story marked BLOCKED from merge.
