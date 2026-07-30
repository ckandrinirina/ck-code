# Wave Mode — Dependency-Ordered Epic Builds

Wave mode runs PARALLEL MODE once per **wave** and merges each wave before the next, so a
dependent story always sees its blockers already `done`. Entered by `--epic NN`, or by the
whole-epic option in the SKILL.md 1.2 menu / the 1.4 epic-wave offer.

**Scope is exactly one epic — never a whole feature.** A multi-epic feature is built one
epic per `--epic` run; after an epic completes, the operator picks the next (no
auto-chaining). Never plan a wave that spans epics.

Example: epic 01 has 01-01, 01-02, 01-03 (blocked by 01-01+01-02), 01-04 (blocked by
01-03). Waves: `[01-01, 01-02]` → `[01-03]` → `[01-04]`.

## Plan the waves (from the index)

Read the epic's rows in `STORIES_INDEX.md`, restricted to this epic and `Status ≠ done`.
Order them into dependency phases by `Blocked by`:

- **Wave 1** = stories whose every blocker is `done` (or empty).
- **Wave k+1** = stories whose every blocker is `done` or scheduled in waves ≤ k.

An out-of-epic blocker that is not yet `done` makes the epic un-startable — report which
blocker is pending and stop. A story whose blocker never resolves (cycle, or a non-`done`
out-of-scope dep) is `UNSCHEDULABLE` — exclude it and report at the end.

Print the wave plan table ([conflict-format.md](conflict-format.md)). A deep chain means
many sequential merge+dispatch cycles and heavy token use — if the plan runs more than
~3 waves, note that and let the operator re-scope. Create one Claude Task per scheduled
story prefixed by wave (`W1 · Implement 01-01: …`) when the Task tools are available.

## The wave loop

For each wave, in order:

1. **Confirm** — the P3 question call, `PROCEED / DROP A STORY / ABORT` for this wave.
2. **Dispatch** this wave's stories through [parallel-mode.md](parallel-mode.md) P4, then walk
   each branch through P5 (integrity/resume) → P7 (QA) **as its agent returns** — those two are
   per-branch and pipelined, never barriered on the wave. P6 (conflict, intra-wave only) is the
   barrier: it starts once every branch has cleared P5. The worktrees are cut from
   the target branch's current HEAD, which already carries prior waves' merged code. A
   single-story wave inside a multi-wave run is still dispatched as a one-agent worktree run,
   never inline — its work has to land on the shared target like every other wave.
3. **Merge** this wave's merge-eligible branches into the target (P8 Option 1), then
   **regenerate the indexes** — `"${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh" tasks/<Plan>` —
   so the next wave's re-resolve sees these stories as `done`. Run the post-merge QA on the
   target via a `qa-validator` agent, not inline.
4. **Verify** the merged wave on the target (the P8 manual gate) before the next wave builds
   on it. A reverted story returns to `todo`/`in-progress`, holds its dependents, and its
   branch is kept.
5. **Update Tasks** — this wave's merged, verified stories `completed`; a blocked or
   reverted story stays open with the reason recorded.
6. **Re-resolve** the next wave (P9) from the freshly regenerated index and loop until no
   scheduled story remains.

## Blocked dependencies & summary

A story left BLOCKED from merge holds every downstream story depending on it — those cannot
dispatch (blocker not `done`). Report held and `UNSCHEDULABLE` stories in the final
summary, then the standard NEXT (`/ck-code:ship` per story). When more not-`done` epics
remain, list them and ask which to build next (`--epic NN`) — never auto-continue.
