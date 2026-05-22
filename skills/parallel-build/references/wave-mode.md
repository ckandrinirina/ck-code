# Wave Mode — Dependency-Ordered Multi-Wave Epic Builds

Wave mode turns parallel-build into a dependency-ordered orchestrator for a **whole
epic**. Instead of one batch + a single end merge, it runs the parallel pipeline once
per **wave**, merging each wave before the next so downstream stories see their
dependencies already `DONE`.

Example: Epic 01 has 01-01, 01-02, 01-03 (blocked by 01-01 + 01-02), 01-04 (blocked by
01-03). Waves: `[01-01, 01-02]` → `[01-03]` → `[01-04]`.

## Entry

Wave mode is entered when `$ARGUMENTS` is `--epic <NN>` (or interactive selection picks
"whole epic in waves"). `<NN>` is the epic number as it appears in `STORIES_INDEX.md`
story IDs (`NN-SS`).

## Wave Computation (from the index)

1. Read `tasks/*/STORIES_INDEX.md`. Filter rows whose `ID` is in epic `<NN>` and
   `Status` ≠ `DONE`.
2. Topologically level by `Blocked by` (restricted to in-scope IDs):
   - **Wave 1** = stories whose every blocker is already `DONE` (or empty).
   - **Wave k+1** = stories whose every blocker is `DONE` or scheduled in waves ≤ k.
3. Out-of-epic blockers must already be `DONE`; if one is not, the epic is not startable
   — report which blocker is pending and stop.
4. A story whose blocker never resolves (cycle, or a non-DONE out-of-scope dep) →
   flag `UNSCHEDULABLE`, exclude it, report at the end.

## Wave Plan Table

```
Epic 01 — Wave plan (4 stories):

  Wave 1  (parallel)   01-01  Login form         S
                       01-02  Session store       M
  Wave 2  (parallel)   01-03  Auth middleware     L   ← needs 01-01, 01-02
  Wave 3               01-04  Audit log           S   ← needs 01-03

Proceed with Wave 1? (YES / ADJUST)
```

## Claude Task Plan (per story, grouped by wave)

Create one Task per scheduled story up front with TaskCreate, prefixing the wave number:
`W1 · Implement 01-01: Login form`, `W2 · Implement 01-03: Auth middleware`, …
All start `pending`; the wave loop flips each `in_progress` at dispatch and `completed`
at that wave's merge. This is the live board for the whole epic.

## The Wave Loop

For each wave, in order:

1. **Confirm (confirm-each-wave gate).** Present this wave's stories and AskUserQuestion
   `YES / SKIP STORY / ABORT`. Wave 1's confirmation is the plan-table prompt above.
2. **Branch base.** Create this wave's worktrees from the **merge target branch's current
   HEAD** — which already contains previous waves' merged code — NOT from a stale `main`.
   This is what lets a dependent story (e.g. 01-03) see its merged dependencies and their
   `DONE` index status.
3. **Single-story wave** → short-circuit to `/ck-code:build` for that one story
   (SKILL.md Phase 2.5 rule); skip dispatch and conflict analysis for that wave.
4. **Run the pipeline on this wave's stories:** SKILL.md Phase 3 (dispatch) → 3.5
   (integrity) → 4 (conflict, intra-wave only) → 5 (QA) → 5.5 (manual-test gate).
5. **Merge this wave** into the target branch with Phase 6 Option 1 logic — merge-eligible
   = QA-passed + manual-test-passed + conflict-free. Run the post-merge QA on the target.
6. **Cleanup this wave's worktrees** (Phase 7) before the next wave. Keep only the
   worktrees of BLOCKED stories.
7. **Update Tasks.** Mark this wave's merged stories `completed`; a BLOCKED story stays
   `in_progress` with the blocker recorded.
8. **Re-resolve.** Re-read the index from the target branch (this wave's stories now read
   `DONE`). Recompute the next wave's ready set — a story dispatches only when every
   blocker is `DONE`.
9. Loop until no scheduled stories remain.

## Blocked Dependency Handling

If a wave leaves a story BLOCKED from merge, every downstream story depending on it is
**held** — it cannot dispatch because its blocker is not `DONE`. Report held stories in
the final summary. The operator fixes the blocked story (re-run via Phase 6 Option 3),
then re-runs `--epic <NN>` to resume from where it stalled.

## Final Summary

After the last wave: print per-wave merge results, any UNSCHEDULABLE / held stories, and
confirm the epic's `STORIES_INDEX.md` + `EPIC.md` status. Then the standard NEXT
(`/ck-code:ship` per story).
