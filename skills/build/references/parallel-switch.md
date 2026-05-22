# Parallel-Build Opportunity Check — build Phase 1.4

Detail for build Phase 1.4. SKILL.md holds the trigger and the skip rule; this file holds
the detection steps and the offer.

Runs in both modes (story path given or interactive). **Skip entirely when running
non-interactively / as a dispatched sub-agent** — you cannot prompt the user and are
already inside a parallel run.

**If interactive selection (Phase 1.2) already presented the whole-epic options** and the
user deliberately picked a single story, the epic-wave choice was just declined — omit the
**B) epic-wave** option below (the parallel **A) batch** offer may still apply). When a
story path was passed directly (`$ARGUMENTS`, no 1.2 menu), offer B normally.

1. **Read the index** if not already loaded this session: `tasks/*/STORIES_INDEX.md`.
2. **Detect the epic-build opportunity (always check first — this is independent of
   parallel-safe candidates).** From the index, count the selected story's epic (`NN`)
   rows whose `Status` ≠ `DONE`. If more than one remains (the selected story plus ≥ 1
   other), the epic has unfinished work that wave mode can drive to completion in
   dependency order — the **B) epic-wave** offer applies, whether the remaining stories
   are sequential or parallel. Do NOT skip this check just because no peer is
   parallel-safe; a purely sequential epic is exactly the dependency-order case wave mode
   exists for.
3. **Resolve the other ready set:** rows with `Status: TODO` whose every `Blocked by` ID
   resolves to `DONE`, **excluding the currently selected story**.
4. **Test file-scope independence** for the ready set: read the `Files to Create/Modify`
   table of the selected story and of each other ready story (a deliberate cross-check,
   not Phase-1 discovery). A candidate is **parallel-safe** if its file scope does not
   overlap the selected story's scope nor any other already-chosen candidate's scope —
   these enable the **A) batch** offer.
5. **Decide which offers apply:**
   - Neither an epic-build opportunity (step 2) nor a parallel-safe candidate (step 4)
     exists → skip silently, proceed to Phase 1.5.
   - Otherwise → present the offer (step 6) with only the options that apply.
6. **Offer the switch** via AskUserQuestion, including only the applicable options:
   - **A) Switch to parallel-build (batch)** — build `[selected] + [safe candidates]`
     concurrently in worktrees. Offered when ≥ 1 parallel-safe candidate exists (step 4).
   - **B) Switch to parallel-build `--epic NN` (waves)** — build the whole epic to
     completion in dependency-ordered waves. Offered whenever the epic has > 1 non-DONE
     story (step 2).
   - **C) Stay in build** — build only the selected story now.
   Show the recommended batch set and/or wave plan so the operator can choose.

On **A**: leave the story `Status: TODO` (do NOT run 1.6), call
`Skill("ck-code:parallel-build", "<selected-id> <safe-id>...")` and **exit**.
On **B**: leave the story `Status: TODO`, call `Skill("ck-code:parallel-build", "--epic NN")`
and **exit** — parallel-build owns the wave loop. On **C**: proceed to Phase 1.5.
