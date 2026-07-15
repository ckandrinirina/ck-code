# Epic-Wave Offer — build Phase 1.4 (explicit-path only)

Detail for build Phase 1.4. Runs ONLY when a story PATH was passed via `$ARGUMENTS` and
the Phase 1.2 interactive menu did not run. **Skip entirely** when 1.2 ran (it already
offered parallel/epic) or when running non-interactively / as a dispatched sub-agent.

An explicit single-story request is respected — this phase **never auto-pulls
parallel-safe peers** (that batch routing belongs to Phase 1.2's interactive selection).
It offers only the dependency-ordered whole-epic build:

1. **Read the index** if not already loaded this session: `tasks/*/STORIES_INDEX.md` (the
   generated view — its `Status` column is derived from story frontmatter).
2. **Detect the epic-build opportunity:** count the selected story's epic (`NN`) rows whose
   `Status` ≠ `DONE`. If only this story remains (no other non-DONE story), skip silently
   → proceed to Phase 1.5.
3. **Offer via AskUserQuestion** (only when the epic has > 1 non-DONE story):
   - **Build the whole epic in dependency-ordered waves** — drives every story in epic `NN`
     to done, whether the remaining stories are sequential or parallel. Show the wave plan so
     the operator can choose.
   - **Stay in build** — implement only the selected story now.
4. On **waves**: leave the story `status: todo` in its frontmatter (do NOT run 1.6), call
   `Skill("ck-code:parallel-build", "--epic NN")` and **exit** — parallel-build owns the
   wave loop. On **stay**: proceed to Phase 1.5.
