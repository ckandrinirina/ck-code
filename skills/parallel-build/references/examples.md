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
user answers `all` → 02-05, 02-06, 03-01. Three stories, so Phase 2.5's single-story
short-circuit does not apply.

## Phase 3 — Parallel Dispatch

`$TARGET` / `$TARGET_SHA` are frozen first (Phase 3.0). Tier is picked per story from
**reasoning complexity, never `Size:`**, then resolved to a concrete model at dispatch:

- 02-05 (M · routine CRUD/wiring) → `balanced` (Sonnet)
- 02-06 (M · routine UI) → `balanced` (Sonnet)
- 03-01 (S · novel scheduling algorithm) → `advanced` (Opus) — small, but the reasoning escalates it

Three Agent calls in **one response message**, `isolation: worktree`, each on branch
`story/XX-YY` in `.claude/worktrees/agent-XXXXXXXX`.

On return: 02-05 reports SUCCESS, 03-01 reports SUCCESS, 02-06 reports a compile error (✗ failed).

## Phase 3.5 — Integrity Verification

Every worktree is WIP-committed and rebased onto `$TARGET_SHA`. The agents' self-reports
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

## Phase 5.5 — Manual Test Gate

Orchestrator prompts per story. Both `PASS` → both merge-eligible.

## Phase 6 — Merge & Reconcile

The user picks `[1] Merge ready branches now`. Branches merge into `$TARGET` in the
suggested order. The orchestrator then reconciles the shared indexes **once** on the
target: `STORIES_INDEX.md` status cells → `DONE`, each parent `EPIC.md` row → `DONE`, and
the `FEATURE_INDEX.md` rollup recomputed. Final QA on the merged target passes.

02-06 (✗ failed, empty of salvageable work) is offered under Option 4 — re-dispatch from
scratch in a new worktree.

## Phase 7 — Worktree Cleanup

Each `.claude/worktrees/agent-*` removed with `git worktree remove -f -f`, then
`git worktree prune`. Only the main tree remains.

## Edge cases demonstrated

- **Single-story batch:** had the user picked only 02-05, Phase 2.5 would short-circuit
  straight to `/ck-code:build` — no worktree, no dispatch, no conflict analysis.
- **◐ incomplete (not failed):** an agent that stops mid-build without an error keeps its
  worktree and is finished by Phase 6 **Option 3** (continue in place, loop until the ✓
  COMPLETE gate passes), never re-dispatched from scratch.
- **✗ failed / empty diff:** re-dispatched fresh under **Option 4**.
- **QA failure post-build:** the worktree is kept and the story marked BLOCKED from merge.
