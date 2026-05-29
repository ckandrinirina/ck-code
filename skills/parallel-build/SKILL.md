---
name: parallel-build
description: Use to implement multiple ready stories concurrently in isolated git worktrees. Argument is optional space-separated story IDs (e.g. `02-05 03-01`); if omitted, picks interactively.
argument-hint: "[story-ids...] | --epic NN  # stories e.g. 02-05 03-01, or a whole epic in waves"
user-invocable: true
---

# Parallel Build — Multi-Story Parallel Implementation

Implements multiple stories simultaneously using git worktrees + parallel sub-agents.
Each sub-agent invokes `/ck-code:build` on its story in isolation. Ends with QA
validation and conflict analysis before any merge.

References:

- `references/agent-prompts.md` — sub-agent dispatch prompt template + announce/result formats
- `references/conflict-format.md` — output formats for table, conflict report, QA, summary, cleanup
- `references/examples.md` — full worked example of a multi-story run
- `references/wave-mode.md` — dependency-ordered multi-wave epic builds (`--epic NN`)
- `references/pipeline.md` — bash mechanics for model resolution, integrity, conflict, merge, cleanup

## INPUT

`$ARGUMENTS` is optional:

- **Story IDs** (e.g. `02-05 03-01`) → skip Phase 2, go directly to Phase 3 with those
  stories (single batch).
- **`--epic NN`** → **wave mode**: implement the whole epic in dependency-ordered waves.
  Go to Phase 2.7 and follow [`references/wave-mode.md`](references/wave-mode.md).
- **Empty** → run interactive selection (Phase 2), which may also offer "whole epic in
  waves".

## PHASE 1: DISCOVERY (index-driven)

Find all stories ready to implement.

### 1.1 Read the Index

**FIRST ACTION — before any glob or file exploration:**
Glob `tasks/*/STORIES_INDEX.md` then Read the matched file.

Do NOT glob `tasks/*/epics/*/stories/*.md` — individual story reads are forbidden at this phase.
The index is the only source of truth for story selection.

The table contains `ID`, `Title`, `Status`, `Size`, `Blocked by`, and `File` columns; no per-story file reads are needed at this phase.

**Bootstrap check (only if index is absent or header ≠ `<!-- Schema: v1 -->`):** follow the bootstrap procedure in [`../../../references/stories-index.md`](../../../references/stories-index.md), then re-read.

### 1.2 Resolve Ready Set

A story is **ready** if its `Status` is `TODO` AND every ID in its `Blocked by` cell resolves to `Status: DONE` in the same table (empty `Blocked by` is always ready). Build the ready list directly from the index rows.

### 1.3 Handle Empty Result

If no stories are ready: list the still-blocked `TODO` stories and which of their `Blocked by` IDs are not yet `DONE` (the index has both). Stop.

### 1.4 Recommend Parallel-Safe Set

From the ready set, recommend which stories are safe to build **at the same time** —
i.e. their declared file scopes don't overlap, so they won't collide at merge.

1. For each ready story, read only its `Files to Create/Modify` table (the index lacks
   file scopes; this targeted read is allowed here, unlike Phase-1 discovery).
2. Group stories so that no two stories in a group share a file path. The largest
   conflict-free group is the **recommended parallel set**; any story that overlaps
   another is tagged "run in a separate batch".
3. Carry this into the Phase 2 table — annotate each row ✓ parallel-safe or ⚠ overlaps
   [ID] (column in `references/conflict-format.md` Phase 2.1).

This is a pre-flight heuristic from _declared_ scopes — Phase 4 still runs the
authoritative dry-run merge on _actual_ diffs after implementation. A story tagged
parallel-safe here can still surface a real conflict in Phase 4.

### 1.5 Detect Whole-Epic Opportunities

From the index, group the not-`DONE` stories by epic (`NN` in their `NN-SS` IDs). Any
epic with > 1 non-DONE story is a **whole-epic candidate** — wave mode (Phase 2.7) drives
it to completion in dependency order, whether its remaining stories are sequential or
parallel. Carry the list of candidate epics into Phase 2 so **each epic is surfaced as
its own explicit "implement whole epic NN in waves" choice** — one option per epic.

**Wave mode is scoped to a single epic — never a whole feature.** A feature with several
epics (e.g. `01_foundation`, `02_shell`, `03_surfaces`, `04_integration`) produces one
candidate per epic; do NOT offer a "whole feature in waves" option and never merge stories
from different epics into one wave plan. Feature-wide waves create long dependency chains
with many sequential merge+dispatch cycles and heavy token use. Build one epic per run.

## PHASE 2: INTERACTIVE SELECTION

Show ready stories, let the user pick. Skip if `$ARGUMENTS` provided.

### 2.1 Display Table

Print the ready-stories table (format: `references/conflict-format.md`).

### 2.2 Wait for Input

Use AskUserQuestion. **For each epic flagged in Phase 1.5, include an explicit "implement
whole epic NN in dependency-ordered waves" option — listed first, one per candidate epic —
so the operator is asked epic-vs-batch directly and never has to know the `epic NN`
syntax.** Then the batch options. Parse the choice:

- the whole-epic option (or `"epic NN"`) → enter **wave mode** for that epic (jump to Phase 2.7)
- `"recommended"` → the parallel-safe set from Phase 1.4 (default batch suggestion)
- `"all"` → every story in the table
- `"1 3 4"` → stories at those positions
- `"02-05 03-01"` → match by story ID directly

If invalid/empty, ask again once. If still invalid, stop.

## PHASE 2.5: SINGLE-STORY SHORT-CIRCUIT

Before any worktree or sub-agent setup, check the selected set size.

**If exactly one story is in scope** (either Phase 1.2 resolved one ready story, or the user selected one in Phase 2, or `$ARGUMENTS` was a single story ID), **skip the entire parallel flow and invoke `/ck-code:build <story-path>` directly via the Skill tool.** Sub-agent dispatch with worktree isolation is pure overhead when there is nothing to run in parallel — the operator gets a faster, simpler flow, and the build skill handles TDD, SOLID, QA, and commit end-to-end.

Print a short notice before delegating:

```
Only one story ready / selected: [EE-SS] [Title]
Switching to /ck-code:build directly (no worktree, no sub-agent).
```

Then call `Skill("ck-code:build", "<story-file-path>")` and exit — do NOT continue to Phase 3, Phase 4, Phase 5, etc. The build skill owns the rest of the workflow.

**If two or more stories are in scope**, continue to Phase 3 with full parallel dispatch.

---

## PHASE 2.7: WAVE MODE (epic-scoped, dependency-ordered)

Entered only when `$ARGUMENTS` is `--epic NN` (or interactive selection chose "whole
epic in waves"). Skip this phase entirely for an explicit story-ID batch.

Wave mode drives **one epic to completion in dependency-ordered waves** — e.g.
`[01-01, 01-02]` first, then `[01-03]` (which needs both), then `[01-04]`. It runs the
Phase 3–7 pipeline **once per wave**, merging each wave into the target branch before the
next so dependents see their dependencies `DONE`. Scope is a single epic — never a whole
feature; after the epic completes, the operator picks the next epic (no auto-chaining).

Follow [`references/wave-mode.md`](references/wave-mode.md) in full. Key contract:

1. **Plan** the waves from the index (topological levels by `Blocked by`, restricted to
   this one epic), apply the **dynamic Wave Depth Guard** (recommended ceiling from story
   count; WARN + confirm `PROCEED / SPLIT` if natural depth exceeds it), print the wave
   plan table, and create one Claude Task per scheduled story prefixed by wave (`W1 · …`).
2. **Per wave:** confirm (`YES / SKIP STORY / ABORT`) → branch worktrees from the **target
   branch's current HEAD** (carries prior waves' merged code) → run Phase 3 → 3.5 → 4 → 5
   → 5.5 → **merge this wave** (Phase 6 Option 1) → **cleanup this wave's worktrees**
   (Phase 7) → mark its Tasks `completed`.
3. **Re-resolve** the next wave's ready set from the freshly-merged index and loop until
   the epic is done. A story whose blocker ended up BLOCKED-from-merge is **held** and
   reported, not dispatched.

A single-story wave short-circuits to `/ck-code:build` (Phase 2.5 rule).

---

## PHASE 3: PARALLEL EXECUTION

Create worktrees and dispatch all sub-agents in one parallel batch.

### 3.1 Model Selection

Pick a model **tier by reasoning complexity, not by story `Size:`**. After plan
consolidation, Size reflects scope (file count), not difficulty — a large story is
usually broad-but-routine. **Default every story to `balanced` (Sonnet)**; escalate to
`advanced` (Opus) only on a clear high-reasoning signal, reserve
`advanced-extended-context` for such a story that also needs 1M context, and use `fast`
(Haiku) only for trivial mechanical changes — Size alone never escalates. Resolve the
tier to a concrete model at dispatch (never hardcode versioned IDs). The complexity
rubric and resolution order (operator env overrides → latest-by-tier → confirm at
announce) live in [`references/pipeline.md`](references/pipeline.md).

### 3.2 Announce Launch

Print dispatch summary (template in `references/agent-prompts.md`).

### 3.2.5 Create Per-Story Tracking Tasks

Create one Claude Task per selected story with TaskCreate (`Implement story XX-YY:
[title]`) so the operator gets a live progress board across the whole parallel run.
Lifecycle:

- **3.3 dispatch** → mark each task `in_progress`.
- **3.4 results** → agent failed: keep `in_progress`, note the error; agent succeeded:
  leave `in_progress` (work continues through integrity, conflict, QA, manual-test).
- **3.5 / 4 / 5 / 5.5** → a 🚫 BLOCKED or QA-failed story stays `in_progress` with the
  blocker recorded in its task.
- **6 merge** → mark `completed` once the story's branch is merged (or the operator
  accepts/aborts it).

Run TaskList at the 3.4, 5, and 6 checkpoints to print the board.

**Use Claude Tasks when the Task tools are available.** If they are not, skip the board
and rely on the per-story status tables already printed in Phases 3.4 / 5 / 6.

### 3.3 Dispatch All Agents — SINGLE MESSAGE, TRULY PARALLEL

**CRITICAL:** You MUST dispatch ALL sub-agents in a single response message (multiple
Agent tool calls in one turn). Do NOT dispatch them sequentially.

For each story, dispatch one Agent call with `isolation: worktree`, the model from
3.1, branch `story/XX-YY`, and the prompt template from `references/agent-prompts.md`.
The prompt instructs the agent to read the story file and invoke `/ck-code:build` via
the Skill tool, which handles TDD, SOLID, QA, and commit.

**Preferred subagent_type:** if available, use `ck-code:story-implementer` (defined
in this plugin's `agents/` folder — wraps the build flow with worktree-isolation
guarantees). If that subagent_type is not registered, fall back to a
`general-purpose` agent with the same prompt.

Worktree isolation rules:

- Each agent runs in its own `.claude/worktrees/agent-XXXXXXXX`.
- Agents must only modify files relevant to their story.
- Agents must NOT modify story files in `tasks/` (the build skill updates those).

### 3.4 Collect Results

Record success/failure per story (capture error message on failure). Print status
summary (format in `references/conflict-format.md`).

## PHASE 3.5: STORY FILE & CODE INTEGRITY VERIFICATION

After all agents finish — before conflict analysis — verify each **successfully
completed** story is properly recorded and no code was silently lost. For each: confirm
its worktree story file reads `Status: DONE` (NOT the main-checkout index, which is
pre-implementation until merge), and run the code-integrity checks (empty diff,
unexpected deletions, pure-deletion files). Commands and flag definitions:
[`references/pipeline.md`](references/pipeline.md).

**Gate** (print the integrity report, format in `references/conflict-format.md`):

- ⚠️ **warning** (incomplete criteria, pure-deletion ratio) → proceeds to QA/merge but
  must appear in the Phase 6 summary for operator review.
- 🚫 **BLOCKED** (status not updated, no implementation, unexpected deletion) → removed
  from the merge-eligible set; keep its worktree; report in Phase 6 under "Review needed".

## PHASE 4: CONFLICT ANALYSIS

Detect file-level conflicts between **successfully completed** story branches before any
merge. **Preferred subagent_type:** delegate to `ck-code:conflict-analyzer` if available
(defined in this plugin's `agents/` folder — runs dry-run merges, classifies risk,
recommends merge order, aborts cleanly); else run the inline procedure in
[`references/pipeline.md`](references/pipeline.md) — dry-run merge each branch onto main,
then detect cross-branch file overlaps.

Print the conflict report (format in `references/conflict-format.md`): per-branch dry-run
result, cross-branch overlaps, and suggested merge order (fewest overlaps first). No
conflicts → "No conflicts detected — all branches merge cleanly."

## PHASE 5: QA & TESTING

Validate builds, tests, and lint per story's worktree, based on its epic/component.
Use the worktree path the agent returned.

- **Engine (epic 02):** `cd [wt]/engine && cmake --build build --config Release` — verify binary exists at `engine/build/Release/<binary>`.
- **Server (epics 03, 09):** `cd [wt]/server && cargo test && cargo clippy -- -D warnings && cargo fmt --check`.
- **Desktop (epics 10–13):** `cd [wt]/desktop && pnpm run typescript && npx vitest run`.
- **Mobile (epic 04):** `cd [wt]/mobile && pnpm run typescript && npx eslint .`.

Print per-story QA results (format in `references/conflict-format.md`). Mark any
story with QA failures as **BLOCKED from merge** — keep its worktree.

## PHASE 5.5: PER-STORY MANUAL TESTING GATE (orchestrator-level, sequential)

Sub-agents in Phase 3 cannot interact with the user, so manual testing runs at
the orchestrator level after Phase 5 QA passes. One gate per story, capped at
3 cycles.

For each story in the QA-passing set:

**5.5.1** Present the manual-test prompt (template in `references/conflict-format.md`)
with scenarios from the story's acceptance criteria + one edge case.
Ask `Result? PASS / ISSUES`.

**5.5.2** On `PASS` → mark the story `MANUAL-TEST PASS` (merge-eligible in Phase 6).

**5.5.3** On `ISSUES` → capture the bug from the user, then dispatch ONE Agent
into that story's existing worktree (prompt template in
`references/agent-prompts.md` — Phase 5.5.3 Bug-Fix Sub-Agent). The agent invokes
`/ck-code:build`, which re-enters at Phase 8.5.3 (regression test → fix →
Refactor → QA) and commits inside the worktree. Story stays IN PROGRESS.
After the agent returns, loop back to 5.5.1 for the same story.

**5.5.4** Cap = 3 cycles per story. On the third `ISSUES`, mark
`BLOCKED FROM MERGE — escalation pending` (escalation template in
`references/conflict-format.md` Phase 5.5.4). Surface in the Phase 6 summary.

## PHASE 6: CLEANUP PROMPT

Print the final summary with three options (format in `references/conflict-format.md`)
and use AskUserQuestion to wait for the choice:

1. Merge ready branches now (conflict-free order)
2. Review worktrees first, merge manually
3. Re-run `/ck-code:build` on failing stories

Stories without `MANUAL-TEST PASS` from Phase 5.5 are **not merge-eligible** under
Option 1, even if QA and conflict checks pass.

**Option 1** — merge QA-passing, manual-test-passing, conflict-free branches in suggested
order into the **orchestrator's current branch** (never a hardcoded `main`; detached HEAD
→ stop and ask). Resolve and confirm the target, merge each branch, then run final QA on
the merged target to catch cross-branch integration issues. Procedure:
[`references/pipeline.md`](references/pipeline.md). If clean, proceed to **Phase 7**.

**Option 2** — print worktree paths and stop; worktrees stay intact for manual review.
Remind the user to run Phase 7 after merging.

**Option 3** — re-run Phase 3 only for failed/blocked stories (dispatch new agents).

## PHASE 7: WORKTREE CLEANUP

Always run after a successful merge. List worktrees, remove each
`.claude/worktrees/agent-*` with double-force (`git worktree remove -f -f` — agent
worktrees are locked by default), then `git worktree prune` and confirm only main
remains. Commands: [`references/pipeline.md`](references/pipeline.md). Print cleanup
confirmation (format in `references/conflict-format.md`).

## RULES

- **Never read individual story files in Phase 1** — `STORIES_INDEX.md` is the only source of truth for story discovery; bootstrap (absent index or wrong schema) is the sole exception.
- **Never merge** a story branch without QA passing first.
- **Always run per-story manual-testing gate (Phase 5.5)** before merge — sub-agents cannot perform manual testing inside their dispatch, so the orchestrator owns it. A story without `MANUAL-TEST PASS` is never merge-eligible. Cap = 3 cycles per story.
- **Always dispatch all agents in one message** — not sequentially. True parallelism
  requires multiple Agent calls in a single turn.
- **Pick the sub-agent model by reasoning complexity, never by Size** (Phase 3.1) —
  default `balanced` (Sonnet), escalate to `advanced` (Opus) only on a clear
  high-reasoning signal. A large consolidated story is not automatically an Opus story.
- **Always track each story as a Claude Task** (Phase 3.2.5) — create at dispatch, keep
  `in_progress` through QA/manual-test, mark `completed` at merge — so the parallel run
  has a live, visible progress board.
- **Always recommend the parallel-safe set** (Phase 1.4) from non-overlapping file
  scopes before selection — it is a pre-flight heuristic, not a substitute for the
  Phase 4 dry-run merge check.
- **Always offer whole-epic wave mode** when an epic has > 1 non-DONE story (Phase 1.5 /
  2.2) — surface it as an explicit AskUserQuestion option so the operator is asked
  epic-vs-batch, never required to know the `epic NN` syntax.
- **Wave mode is single-epic, never feature-wide** (Phase 1.5 / 2.7) — never merge stories
  from different epics into one wave plan; a multi-epic feature is built one epic per run
  and never auto-chains into the next epic.
- **Always apply the dynamic Wave Depth Guard** (Phase 2.7 / `references/wave-mode.md`) —
  derive a recommended wave ceiling from the epic's story count, and if the natural depth
  exceeds it, WARN and require `PROCEED / SPLIT` confirmation before running; never silently
  run a deep, token-heavy wave chain.
- **In wave mode, always merge a wave before dispatching the next** (Phase 2.7 /
  `references/wave-mode.md`) — a dependent story must see its blockers `DONE` on the
  target branch, so each wave's worktrees branch from the post-merge target HEAD.
- **In wave mode, always confirm each wave** (`YES / SKIP STORY / ABORT`) before
  dispatch, and **hold** any story whose blocker ended up BLOCKED-from-merge — never
  dispatch a story with an unresolved dependency.
- **Always isolate** each agent in its own worktree (`isolation: worktree`).
- **Always run story file & code integrity verification** (Phase 3.5) after agents complete — catch missing status updates and code loss before conflict analysis.
- **Always run dry-run merge conflict detection** (Phase 4) before any merge.
- **Always delete** agent worktrees after merging — `git worktree remove -f -f` then
  `git worktree prune`.
- **Never modify** story files in `tasks/` directly — `/ck-code:build` handles that.
- **Single-story runs short-circuit to `/ck-code:build`.** Phase 2.5 detects a one-story scope (from Phase 1.2 / Phase 2 selection / `$ARGUMENTS`) and delegates to `/ck-code:build` directly — no worktree, no sub-agent dispatch, no conflict analysis. Parallel orchestration only makes sense for ≥ 2 stories.
- **Run final QA on the merged target branch** before cleanup — cross-branch integration issues only appear after all merges.
- **Never hardcode `main` as merge target.** Phase 6 Option 1 always resolves to the orchestrator's current branch (`git branch --show-current` in the main checkout). Detached HEAD = stop and ask.

## NEXT

For each story branch that passed QA: run `/ck-code:ship <story-path>` to commit, open the PR, and update the linked GitHub Issues. Then `/ck-code:track next` to find the next batch.
