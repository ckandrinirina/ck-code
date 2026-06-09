# Wave Mode — Dependency-Ordered Multi-Wave Epic Builds

Wave mode turns parallel-build into a dependency-ordered orchestrator for a **single
epic**. Instead of one batch + a single end merge, it runs the parallel pipeline once
per **wave**, merging each wave before the next so downstream stories see their
dependencies already `DONE`.

Example: Epic 01 has 01-01, 01-02, 01-03 (blocked by 01-01 + 01-02), 01-04 (blocked by
01-03). Waves: `[01-01, 01-02]` → `[01-03]` → `[01-04]`.

**Scope is exactly one epic — never a whole feature.** A feature with several epics
(e.g. `01_foundation`, `02_shell`, `03_surfaces`, `04_integration`) is built **one epic
per `--epic` run**. Wave mode never plans waves that span more than one epic — that
produces feature-wide chains with many sequential merge+dispatch cycles and heavy token
use. After an epic completes, parallel-build stops and the operator picks the next epic
(it does not auto-chain across epics).

## Entry

Wave mode is entered when `$ARGUMENTS` is `--epic <NN>` (or interactive selection picks
"whole epic NN in waves"). `<NN>` is a **single** epic number as it appears in
`STORIES_INDEX.md` story IDs (`NN-SS`). If selection offers multiple epics, exactly one
is chosen per run.

## Wave Computation (from the index)

1. Read `tasks/*/STORIES_INDEX.md`. Filter rows whose `ID` is in epic `<NN>` and
   `Status` ≠ `DONE`. **In-scope is restricted to this single epic** — never pull in
   stories from other epics, even if they are blockers.
2. Topologically level by `Blocked by` (restricted to in-scope IDs):
   - **Wave 1** = stories whose every blocker is already `DONE` (or empty).
   - **Wave k+1** = stories whose every blocker is `DONE` or scheduled in waves ≤ k.
3. Out-of-epic blockers must already be `DONE`; if one is not, the epic is not startable
   — report which blocker is pending and stop.
4. A story whose blocker never resolves (cycle, or a non-DONE out-of-scope dep) →
   flag `UNSCHEDULABLE`, exclude it, report at the end.

## Wave Depth Guard (dynamic, complexity-based)

The wave count equals the topological depth `D` from the step above. Before printing the
plan, derive a **recommended ceiling** from the epic's complexity and compare:

1. Let `N` = number of in-scope (non-DONE) stories, `D` = computed wave depth.
2. Recommended ceiling (dynamic — scales with the epic, not a fixed constant):
   - `N ≤ 2` → **1 wave** (single batch; skip wave overhead entirely).
   - `3 ≤ N ≤ 6` → up to **3 waves**.
   - `N > 6` → up to **4 waves**.
3. **`D ≤ ceiling`** → proceed; state the recommendation in the plan (e.g. "5 stories →
   3-wave ceiling; plan uses 2 ✓").
4. **`D > ceiling`** → **WARN + CONFIRM**: print that the epic expands into `D` waves,
   deeper than the `N`-story recommendation of `<ceiling>`, meaning `D` sequential
   merge+dispatch cycles and high token use. Then AskUserQuestion:
   - **PROCEED** — run all `D` waves anyway.
   - **SPLIT** — abort and advise re-scoping the epic into smaller epics, or running an
     explicit story-ID batch for the independent stories first.

   Never silently run past the recommendation — the depth warning must be shown and
   acknowledged.

## Wave Plan Table

```
Epic 01 — Wave plan (4 stories · 3-wave ceiling · depth 3 ✓):

  Wave 1  (parallel)   01-01  Login form         S
                       01-02  Session store       M
  Wave 2  (parallel)   01-03  Auth middleware     L   ← needs 01-01, 01-02
  Wave 3               01-04  Audit log           S   ← needs 01-03

Proceed with Wave 1? (YES / ADJUST)
```

The header line states the depth guard verdict (`N stories · <ceiling>-wave ceiling ·
depth D ✓` when within budget, or `⚠ depth D > ceiling` when the guard tripped — see
Wave Depth Guard).

## Claude Task Plan (per story, grouped by wave)

Create one Task per scheduled story up front with TaskCreate, prefixing the wave number:
`W1 · Implement 01-01: Login form`, `W2 · Implement 01-03: Auth middleware`, …
All start `pending`; the wave loop flips each `in_progress` at dispatch and `completed`
at that wave's merge. This is the live board for the whole epic.

## The Wave Loop

For each wave, in order:

1. **Confirm (confirm-each-wave gate).** Present this wave's stories and AskUserQuestion
   `YES / SKIP STORY / ABORT`. Wave 1's confirmation is the plan-table prompt above.
2. **Branch base.** Freeze this wave's target (`$TARGET` / `$TARGET_SHA`, SKILL.md Phase 3.0)
   from the **merge target branch's current HEAD** — which already contains previous waves'
   merged code — NOT a stale `main`. This is what lets a dependent story (e.g. 01-03) see its
   merged dependencies and their `DONE` index status. Phase 3.5b still normalizes each branch
   onto this wave's `$TARGET_SHA` on return, so a divergent worktree base is corrected
   automatically rather than polluting the wave merge.
3. **Single-story wave** → still dispatch it as a **one-agent worktree run** (Phase 3
   with N=1), NOT an inline `/ck-code:build`. The orchestrator is long-lived across the
   remaining waves: inline build would load that story's whole TDD/QA detail into the
   orchestrator context (taxing every later wave) and could land the work on a
   `story/…` branch off the wave target instead of on it. Skip only the cross-branch
   conflict analysis (Phase 4) — with one branch there is nothing to compare. **Exception:**
   the *terminal* wave, when it is a single story and no wave follows, may inline
   `/ck-code:build` — there is no downstream orchestrator context to protect and it regains
   build's interactive gates.
4. **Run the pipeline on this wave's stories:** SKILL.md Phase 3 (dispatch) → 3.5
   (integrity) → 4 (conflict, intra-wave only) → 5 (QA) → 5.5 (manual-test gate).
5. **Merge this wave** into the target branch with Phase 6 Option 1 logic — merge-eligible
   = QA-passed + manual-test-passed + conflict-free. Then **reconcile the shared indexes on
   the target branch** (`STORIES_INDEX.md` rows → `DONE`, each story's `EPIC.md` row →
   `DONE`, `FEATURE_INDEX.md` rollup) — sub-agents deferred these edits, and this
   reconciliation MUST land before step 8 so the next wave's re-resolve sees this wave's
   stories as `DONE`. Run the post-merge QA on the target.
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

**One epic per run.** When the feature has more not-DONE epics, list them and ask which
to build next (`--epic <NN>`) — do not auto-continue into the next epic. This keeps each
run scoped and token-bounded.
