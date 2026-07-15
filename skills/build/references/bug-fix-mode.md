# Bug-Fix Mode — Implementing a Recorded Fix

`build` enters **Bug-Fix Mode** when the selected story is a diagnosed bug handed
off by `/ck-code:fix`, rather than a fresh story to implement. This file holds the
per-phase deltas from the normal TDD flow; SKILL.md holds the detection hook and the
gate list.

## Detection

A story is in Bug-Fix Mode when **either** holds:

- its index / story-file `Status:` is `BUG`, **or**
- its story file has a `## Bug Report` section whose `Status:` is `DIAGNOSED` (a Fix
  Plan present, no `### Resolution` yet).

`fix` guarantees both together. If a `BUG`-status story has no `DIAGNOSED` Bug Report
(hand-edited / drift), STOP and tell the user to run `/ck-code:fix <story>` or
`/ck-code:sync`.

The rest of the story's acceptance criteria are already `DONE` (that's why the story
was `DONE` before the bug). Bug-Fix Mode implements **only** the recorded Fix Plan —
never re-derives work from the acceptance criteria.

## Phase deltas (vs. the normal build flow)

**Phase 1.3 — Load context.** Read the story's `## Bug Report`: `Bug ID`,
`Prior status`, root cause, `Reproduction test` name, and the `### Fix Plan`
(Strategy, Files to modify, Test target, Risk, SOLID note). The Fix Plan replaces
the acceptance-criteria breakdown as the work definition.

**Phase 3 — Planning.** Skip acceptance-criteria SOLID design. The plan IS the Fix
Plan: implement it verbatim, minimally. Do NOT refactor surrounding code, add
features, or widen scope. Present the Fix Plan as the plan (Phase 3.6 confirmation
still applies).

**Phase 3.7 — Branch.** Always the `fix/<EE>-<SS>-<slug>` prefix (bug story).

**Phase 4 — RED.** The failing reproduction test already exists in the tree (written
by `fix`). Run it and confirm it is RED — do not rewrite it. Add any related
regression tests the Fix Plan or diagnosis called out (edge cases near the root
cause). If the repro test is unexpectedly GREEN, STOP: the tree changed since
diagnosis — re-run `/ck-code:fix`.

**Phase 5 — GREEN.** Apply the Fix Plan's change — the **smallest** edit that turns
the reproduction test GREEN. Log any touch outside the Fix Plan's `Files to modify`
to `## Unplanned Changes` (bug-section-template Phase 6.2), same as normal build.

**Phase 6 — SOLID.** Run the SOLID check **bounded to the fix diff** (not the whole
story). Record it under the Bug Report as `### SOLID Verification` (bug-section-template
Phase 6.4), not as a story-level SOLID summary.

**Phase 7 — QA.** Full QA procedure **plus the minimalism check** — the diff must be
the smallest change that resolves the root cause; flag any unrelated edit.

**Phase 8 — Completion (Resolution, not Implementation Summary).**

1. Fill the Bug Report `### Resolution` + `### Files Touched` (bug-section-template
   Phase 8.1); set Bug Report `Status: DIAGNOSED → FIXED`.
2. **Restore the story status** to its `Prior status` (from the Bug Report — normally
   `DONE`): story file `Status: BUG → <prior>`; `STORIES_INDEX.md` status cell
   `BUG → <prior>` (same phase); `FEATURE_INDEX.md` — recompute the feature rollup
   (a feature with no remaining `BUG`/`IN PROGRESS`/`TODO` story rolls back to `DONE`).
   Parallel-worktree guard applies exactly as in SKILL.md 1.6/8.6 — a worktree defers
   the shared-index edits to the orchestrator's post-merge reconciliation.
3. Do NOT append an Implementation Summary — the Bug Report Resolution is the record
   for a bug fix.
4. Ship as usual (Phase 8.8) — the commit body lists the `Bug ID` and the story ID;
   `fix/` branch prefix.

**Phase 8.5 — Manual-test loop.** Unchanged (bug-section-template Phase 8.6 Manual-Test
Reports records residual-symptom cycles). Cap = 3.

## Multi-story bugs

A multi-story bug (`fix` verdict B / D) flips several stories to `BUG` under one
`Bug ID`. Each is its own `build` run (or a `parallel-build` batch) — Bug-Fix Mode
restores each story's prior status independently as its share of the Fix Plan lands.
