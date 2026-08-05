# Bug-Fix Mode — Implementing a Recorded Fix

`build` enters **Bug-Fix Mode** when the selected story is a diagnosed bug handed off by
`/ck-code:fix`, rather than a fresh story to implement. This file holds the per-phase deltas
from the normal TDD flow; SKILL.md holds the detection hook and the gate list.

## Detection

A story is in Bug-Fix Mode when its frontmatter reads **`status: bug`** and its body has a
`## Bug Report` whose `Status:` is `DIAGNOSED` (a Fix Plan present, no `### Resolution` yet).
`fix` guarantees both together and records the pre-bug status in the frontmatter
`prior_status:` field. If a `status: bug` story has **no** `DIAGNOSED` Bug Report
(hand-edited / the tree drifted since diagnosis), STOP and tell the user to run
`/ck-code:fix <story>`.

The story's acceptance criteria are already `done` (that's why the story was `done` before
the bug). Bug-Fix Mode implements **only** the recorded Fix Plan — it never re-derives work
from the acceptance criteria.

## Phase deltas (vs. the normal build flow)

**Phase 1.3 — Load context.** Read the frontmatter `prior_status:` and the body
`## Bug Report`: `Bug ID`, root cause, `Reproduction test` name, and the `### Fix Plan`
(Strategy, Files to modify, Test target, Risk, SOLID note). The Fix Plan replaces the
acceptance-criteria breakdown as the work definition.

**Phase 1.6 — No status change.** The story stays `status: bug` through the fix; it is
restored to `prior_status` at Phase 8.6. Do NOT flip `bug → in-progress`.

**Phase 3 — Planning.** Skip acceptance-criteria SOLID design. The plan IS the Fix Plan:
implement it verbatim, minimally. Do NOT refactor surrounding code, add features, or widen
scope. Present the Fix Plan as the plan (the Phase 3.5 confirm + branch gate still applies).

**Phase 3.5 — Branch.** Always the `fix/<EE>-<SS>-<slug>` prefix (bug story).

**Phase 4 — RED.** The failing reproduction test already exists in the tree (written by
`fix`). Run it and confirm it is RED — do not rewrite it. Add any related regression tests the
Fix Plan or diagnosis called out. If the repro test is unexpectedly GREEN, STOP: the tree
changed since diagnosis — re-run `/ck-code:fix`.

**Phase 5 — GREEN.** Apply the Fix Plan's change — the **smallest** edit that turns the
reproduction test GREEN. Log any touch outside the Fix Plan's `Files to modify` to
`## Unplanned Changes` (bug-section-template Phase 6.2), same as normal build.

**Phase 6 — SOLID.** Run the SOLID check **bounded to the fix diff** (not the whole story).
Record it under the Bug Report as `### SOLID Verification` (bug-section-template Phase 6.4),
not as a story-level SOLID summary.

**Phase 7 — QA.** Full QA procedure **plus the minimalism check** — the diff must be the
smallest change that resolves the root cause; flag any unrelated edit.

**Phase 8 — Completion (Resolution, not Implementation Summary).**

1. Fill the Bug Report `### Resolution` + `### Files Touched` (bug-section-template Phase 8.1);
   set Bug Report `Status: DIAGNOSED → FIXED`.
2. **Restore the story status** in the frontmatter: `status: bug` → `status: <prior_status>`
   (from the frontmatter `prior_status:` — normally `done`), then clear `prior_status:`. Run
   the generator in the same phase:

   ```bash
   ck-index tasks/<slug>
   ck-project sync tasks/<slug>
   ```

   The rollup recomputes automatically — a feature with no remaining `bug`/`in-progress`/`todo`
   story rolls back to `DONE`, and the sync moves the card out of Blocked into the column the restored status calls for. There is no index cell to edit and no `EPIC.md` to touch. In
   DELEGATED MODE the agent restores only its own frontmatter and skips `ck-index` — the
   orchestrator regenerates once on the target branch after merge.
3. Do NOT append an Implementation Summary — the Bug Report Resolution is the record for a bug
   fix.
4. Ship as usual (Phase 8.7) — the commit body lists the `Bug ID` and the story ID; `fix/`
   branch prefix.

**Phase 8.5 — Manual-test loop.** Unchanged (bug-section-template Phase 8.6 Manual-Test
Reports records residual-symptom cycles). Cap = 3.

## Multi-story bugs

A multi-story bug (`fix` verdict B / D) flips several stories to `status: bug` under one
`Bug ID`. Each is its own `build` run (or one PARALLEL MODE batch) — Bug-Fix Mode restores
each story's `prior_status` independently as its share of the Fix Plan lands.
