# Parallel-Build Opportunity Check — build Phase 1.4

Detail for build Phase 1.4. SKILL.md holds the trigger and the skip rule; this file holds
the detection steps and the offer.

Runs in both modes (story path given or interactive). **Skip entirely when running
non-interactively / as a dispatched sub-agent** — you cannot prompt the user and are
already inside a parallel run.

1. **Read the index** if not already loaded this session: `tasks/*/STORIES_INDEX.md`.
2. **Resolve the other ready set:** rows with `Status: TODO` whose every `Blocked by` ID
   resolves to `DONE`, **excluding the currently selected story**.
3. **None** → skip silently, proceed to Phase 1.5.
4. **One or more** → test file-scope independence. Read the `Files to Create/Modify` table
   of the selected story and of each other ready story (a deliberate cross-check, not
   Phase-1 discovery). A candidate is **parallel-safe** if its file scope does not overlap
   the selected story's scope nor any other already-chosen candidate's scope.
5. **No parallel-safe candidate** → note "other ready stories overlap this one's files —
   building sequentially" and proceed to Phase 1.5.
6. **Detect an epic-wave opportunity:** if the selected story's epic (`NN`) has other
   not-`DONE` stories that are still *blocked* (the epic needs more than one dependency
   wave — e.g. `01-03` blocked by `01-01` + `01-02`), a flat batch cannot finish the
   epic; wave mode can.
7. **Offer the switch** via AskUserQuestion, including only the options that apply:
   - **A) Switch to parallel-build (batch)** — build `[selected] + [safe candidates]`
     concurrently in worktrees. Offered when ≥ 1 parallel-safe candidate exists.
   - **B) Switch to parallel-build `--epic NN` (waves)** — build the whole epic in
     dependency-ordered waves. Offered when the epic-wave opportunity (step 6) holds.
   - **C) Stay in build** — build only the selected story now.
   Show the recommended batch set and/or wave plan so the operator can choose.

On **A**: leave the story `Status: TODO` (do NOT run 1.6), call
`Skill("ck-code:parallel-build", "<selected-id> <safe-id>...")` and **exit**.
On **B**: leave the story `Status: TODO`, call `Skill("ck-code:parallel-build", "--epic NN")`
and **exit** — parallel-build owns the wave loop. On **C**: proceed to Phase 1.5.
