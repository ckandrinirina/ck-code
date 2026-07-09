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

## ROUTING CHECK (do first)

This skill builds **multiple independent stories** in parallel worktrees.
If the request is actually something else, STOP and recommend the better skill:

- One story, or stories with `Blocked by` dependencies → `/ck-code:build`
- A bug in already-implemented code → `/ck-code:fix`

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:ship` (per branch).

## INPUT

`$ARGUMENTS` is optional:

- **Story IDs** (e.g. `02-05 03-01`) → skip Phase 2, go directly to Phase 3 with those
  stories (single batch).
- **`--epic NN`** → **wave mode**: implement the whole epic in dependency-ordered waves.
  Go to Phase 2.7 and follow [`references/wave-mode.md`](references/wave-mode.md).
- **Empty** → run interactive selection (Phase 2), which may also offer "whole epic in
  waves".

## PHASE 0: VERSION GATE (hard gate)

Read `tasks/VERSION.md`. If `layout: v3` → PASS, proceed. Otherwise run the shared [version gate](../../references/version-gate.md) (HARD GATE) — it detects, offers `/ck-code:doc-optimizer upgrade`, and stamps.

## PHASE 1: DISCOVERY (index-driven)

Find all stories ready to implement.

### 1.0 Feature Gate (top-level feature index — read FIRST)

**Before the story index**, Read `tasks/FEATURE_INDEX.md` and apply the feature-selection gate in [`../../references/feature-index.md`](../../references/feature-index.md): bootstrap it if missing; compute the unfinished set (`Status` ≠ `DONE`); **0** → all done, suggest `/ck-code:plan`, stop; **1** → auto-select; **2** → fall through; **> 2** → AskUserQuestion "Which feature do you want to build?" (single-select). The chosen feature's `Plan` + epic `NN` scope every step below to that one epic. Skip this phase entirely when `$ARGUMENTS` carries explicit story IDs or `--epic NN` — an explicit scope is always respected.

### 1.1 Read the Index

**FIRST ACTION after the feature gate — before any glob or file exploration:**
Glob the chosen feature's `tasks/<Plan>/STORIES_INDEX.md` then Read it and filter to its epic `NN`.

Do NOT glob `tasks/*/epics/*/stories/*.md` — individual story reads are forbidden at this phase.
The index is the only source of truth for story selection.

The table contains `ID`, `Title`, `Status`, `Size`, `Blocked by`, and `File` columns; no per-story file reads are needed at this phase.

**Bootstrap check (only if index is absent or header ≠ `<!-- Schema: v1 -->`):** follow the bootstrap procedure in [`../../references/stories-index.md`](../../references/stories-index.md), then re-read.

### 1.2 Resolve Ready Set

A story is **ready** if its `Status` is `TODO` AND every ID in its `Blocked by` cell resolves to `Status: DONE` in the same table (empty `Blocked by` is always ready). Build the ready list directly from the index rows.

### 1.3 Handle Empty Result

If no stories are ready: list the still-blocked `TODO` stories and which of their `Blocked by` IDs are not yet `DONE` (the index has both). Stop.

### 1.4 Recommend Parallel-Safe Set

From the ready set, recommend which stories are safe to build **at the same time** —
i.e. their declared file scopes don't overlap, so they won't collide at merge.

1. Extract **only** each ready story's `Files to Create/Modify` table in a single batched
   Bash call (the index lacks file scopes, so this targeted extraction is allowed here,
   unlike Phase-1 discovery) — never a full `Read` of each story body, which would load
   every story's acceptance criteria and technical notes into the long-lived orchestrator
   just to compare file paths:

   ```bash
   for f in <ready-story paths from the index `File` column>; do
     echo "== $f"; awk '/^## Files to Create\/Modify/{p=1;next} /^## /{p=0} p' "$f"
   done
   ```
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

**This batch-level short-circuit does NOT apply inside wave mode.** A single-story *wave*
keeps one-agent worktree dispatch (Phase 3, N=1) so the long-lived orchestrator stays lean
and the work lands on the wave target — see Phase 2.7 / [`references/wave-mode.md`](references/wave-mode.md).

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

A single-story wave still runs through **one-agent worktree dispatch** (Phase 3, N=1), NOT
inline `/ck-code:build` — the long-lived orchestrator stays lean across later waves and the
work lands on the wave target branch. Only a *terminal* single-story wave may inline. See
[`references/wave-mode.md`](references/wave-mode.md).

---

## PHASE 3: PARALLEL EXECUTION

Create worktrees and dispatch all sub-agents in one parallel batch.

### 3.0 Freeze the Merge Target (base pin — do this FIRST)

Before any dispatch, **freeze the merge target once**: `$TARGET` = current branch,
`$TARGET_SHA` = its HEAD (detached HEAD → stop and ask); confirm a clean tree. Every later
phase uses `$TARGET` / `$TARGET_SHA` — **never a hardcoded `main`** (diffing against `main`
while on a `docs`/feature branch is what produced the "stray commit" archaeology).
`isolation: worktree` won't let us pin the base at dispatch, so base correctness is
**guaranteed on return** (Phase 3.5b normalize), not at launch. Commands:
[`references/pipeline.md`](references/pipeline.md) Phase 3.0.

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
- **An oversized story may exhaust its dispatch budget and stop early** (◐ incomplete in
  Phase 3.4), so `/ck-code:build` commits per phase inside the worktree.

### 3.4 Collect Results

Each agent ends with a structured signal line (`STATUS: SUCCESS|PARTIAL|BLOCKED`,
`COMMITS:`, `REMAINING:` — enforced by `story-implementer` and the dispatch prompts). Use
it as a hint, but **never trust the agent's word as the outcome of record.** The outcome is
*derived from the worktree* in Phase 3.5 (criteria + QA + commits), because the failure you
must catch is precisely an agent that did nothing yet reported "Done". Record one of
**three** provisional outcomes per story (format in `references/conflict-format.md`):

- **✓ completed** — agent reported SUCCESS through Phase 8.4 (verified objectively in 3.5).
- **✗ failed** — agent reported an explicit error/blocker (capture the message).
- **◐ incomplete** — agent stopped **without an error and without finishing** (budget
  exhausted mid-implementation), OR returned no structured status at all (a bare stop).
  This is NOT a failure — partial work exists and is recoverable.

**Dispatched agents cannot be resumed** (no `SendMessage`) — a returned agent is gone and
its **only durable state is its worktree**. So an ◐ incomplete story is recovered by the
Phase 6 Option 3 auto-continue loop in its existing worktree — never by reattaching to the
dead agent or re-dispatching fresh.

## PHASE 3.5: STORY FILE & CODE INTEGRITY VERIFICATION

After all agents finish — before conflict analysis — verify each story is properly
recorded and no code was silently lost. Two **pre-steps run first per worktree** (commands:
[`references/pipeline.md`](references/pipeline.md) Phase 3.5a/3.5b):

1. **Preserve uncommitted work (3.5a).** The resume model needs committed state, but an
   agent can stop with work **uncommitted** (transcript 01-01 had *no* commit — one
   `git worktree prune` from losing it). WIP-commit every dirty worktree so it is durable
   and rebaseable.
2. **Normalize the base (3.5b).** If a branch's merge-base with `$TARGET_SHA` isn't
   `$TARGET_SHA`, it was cut from a divergent point and carries foreign commits (the
   `dabfb20` / `f298946` archaeology). Don't investigate by hand —
   `git rebase --onto $TARGET_SHA <merge-base> story/XX-YY` replays only the story's work
   onto the target, so the diff and merge are exactly the story.

Then verify the worktree **story file** reads `Status: DONE` (NOT the index — sub-agents
defer all shared-index edits in parallel mode, so the worktree's `STORIES_INDEX.md` /
`EPIC.md` stay at pre-build status by design; not drift, reconciled post-merge) and run the
code-integrity checks against `$TARGET_SHA` (empty diff, unexpected deletions, pure-deletion
files). For any ◐ incomplete story, the status + diff check here is what separates resumable
progress from a dead end.

**Gate** (print the integrity report, format in `references/conflict-format.md`):

- ✓ **COMPLETE** — the objective, orchestrator-verified done state (never the agent's
  self-report): the worktree story file reads `Status: DONE`, **every** acceptance-criteria
  checkbox is `[x]`, the working tree is clean (all work committed), and Phase 5 QA passes.
  This is the exact condition the Phase 6 Option 3 auto-continue loop runs *until*.
- ⚠️ **warning** (incomplete criteria, pure-deletion ratio) → proceeds to QA/merge but
  must appear in the Phase 6 summary for operator review.
- ◐ **INCOMPLETE (resumable)** — story file still TODO/IN PROGRESS **but the diff carries
  real partial work** (non-empty, not a pure deletion). Not merge-eligible and not failed:
  keep its worktree and route it to Phase 6 **Continue in place**. This is the expected
  state for an XL story whose agent ran out of budget mid-build.
- 🚫 **BLOCKED** (status not updated **with an empty diff** = no implementation, or
  unexpected deletion) → removed from the merge-eligible set; keep its worktree; report in
  Phase 6 under "Review needed". An empty diff means there is nothing to continue —
  re-dispatch fresh, do not "continue in place".

## PHASE 4: CONFLICT ANALYSIS

Detect file-level conflicts between **successfully completed** story branches before any
merge. **Preferred subagent_type:** delegate to `ck-code:conflict-analyzer` if available
(defined in this plugin's `agents/` folder — runs dry-run merges, classifies risk,
recommends merge order, aborts cleanly); else run the inline procedure in
[`references/pipeline.md`](references/pipeline.md) — dry-run merge each branch onto the
frozen `$TARGET`, then detect cross-branch file overlaps.

Print the conflict report (format in `references/conflict-format.md`): per-branch dry-run
result, cross-branch overlaps, and suggested merge order (fewest overlaps first). No
conflicts → "No conflicts detected — all branches merge cleanly."

## PHASE 5: QA & TESTING (delegated to parallel Haiku QA agents)

Validate builds, tests, and lint per story's worktree, based on its epic/component — but
**never run the heavy commands inline in this orchestrator.** A long-lived parallel-build
orchestrator that runs `cargo test`, `cmake --build`, `pnpm run typescript`, `vitest`, etc.
for every story in its own context floods the most expensive session in the run with verbose
build/test/lint output. Instead, **dispatch one `ck-code:qa-validator` agent per completed
story** — pinned to the `fast` (Haiku) tier — so each agent runs its stack's QA commands
**inside its own worktree and its own cheap context**, and returns only a compact PASS/FAIL
verdict. The orchestrator stays lean and the QA passes run in parallel instead of one-by-one.

### 5.1 Stack QA Commands (passed to each agent)

Derive each story's commands from the component it touches — never from a hardcoded
epic-to-stack map, which is project-specific and wrong on any other repo. For each
merge-candidate story, resolve the component directory from its `Files to Create/Modify`
paths, then detect the stack from that directory's manifest and pass the concrete
build/test/lint commands to the agent:

| Manifest found | QA commands |
| --- | --- |
| `Cargo.toml` | `cargo test && cargo clippy -- -D warnings && cargo fmt --check` |
| `package.json` | the `test`, `lint`, and typecheck scripts it actually declares |
| `CMakeLists.txt` | `cmake --build build --config Release`, then verify the expected artifact exists |
| `pyproject.toml` | `pytest` plus the declared lint/format checks |
| `go.mod` | `go test ./... && go vet ./...` |

A project's own `guide-conventions` skill (from `/ck-code:convention`) overrides this table
when it names the canonical commands. If no manifest matches, ask the operator once for the
QA command and reuse it for every story in the run.

### 5.2 Dispatch QA Agents — SINGLE MESSAGE, PARALLEL

For every story that reached Phase 3.5 ✓ COMPLETE or ⚠ warning (merge-candidate set),
dispatch one Agent in a single parallel message (like Phase 3.3) with `subagent_type:
ck-code:qa-validator`, `isolation: none`, `cwd: <worktree>`, and the **Phase 5 QA-Validation
Sub-Agent** prompt from [`references/agent-prompts.md`](references/agent-prompts.md) carrying
that story's concrete stack commands from 5.1. The agent runs the commands, captures any
failing output, and returns the QA Report verdict line. If the `ck-code:qa-validator`
subagent_type is not registered, **fall back** to running the 5.1 commands inline per
worktree.

### 5.3 Aggregate Verdicts

Collect each agent's verdict and print the per-story QA Report (format in
`references/conflict-format.md`). Mark any story with QA failures as **BLOCKED from merge** —
keep its worktree. ◐ incomplete and 🚫 blocked stories from Phase 3.5 are not QA candidates.

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

Print the final summary with four options (format in `references/conflict-format.md`)
and use AskUserQuestion to wait for the choice:

1. Merge ready branches now (conflict-free order)
2. Review worktrees first, merge manually
3. Continue ◐ incomplete stories in place (resume the work in their existing worktrees)
4. Re-dispatch ✗ failed / empty stories from scratch (new worktrees)

Stories without `MANUAL-TEST PASS` from Phase 5.5 are **not merge-eligible** under
Option 1, even if QA and conflict checks pass.

**Option 1** — merge QA-passing, manual-test-passing, conflict-free branches in suggested
order into the **orchestrator's current branch** (never a hardcoded `main`; detached HEAD
→ stop and ask). Resolve and confirm the target, merge each branch, then run final QA on
the merged target to catch cross-branch integration issues. Procedure:
[`references/pipeline.md`](references/pipeline.md).

**After the merges land, reconcile the shared indexes once on the target branch** — the
sub-agents deferred every shared-index edit, so the merged tree carries each story file at
`Status: DONE` while the indexes still show the pre-build status. The orchestrator is the
sole writer here, so these edits never conflict. In one pass:

1. `tasks/<slug>/STORIES_INDEX.md` — flip each merged story's `Status` cell to `DONE`
   (mutation protocol: [`../../references/stories-index.md`](../../references/stories-index.md)).
2. Each merged story's parent `EPIC.md` — set its row in the stories table to `DONE`.
3. `tasks/FEATURE_INDEX.md` — recompute the built feature's `Stories` count and roll up its
   `Status`: mark the feature `DONE` if its last story is now merged, else `IN PROGRESS`. Never
   leave the rollup stale after a completed parallel build (per
   [`../../references/feature-index.md`](../../references/feature-index.md)).

Commit the reconciliation on the target branch. If clean, proceed to **Phase 7**.

**Option 2** — print worktree paths and stop; worktrees stay intact for manual review.
Remind the user to run Phase 7 after merging.

**Option 3 — Continue in place (◐ incomplete stories) — AUTO-CONTINUE UNTIL VERIFIED.**
One dispatch cannot be guaranteed to finish an XL story (the per-agent budget is the
harness's, not ours), so completion is reached by *looping*, not by hoping one retry lands.
For each ◐ incomplete story, dispatch a fresh Continue-Incomplete agent INTO its existing
worktree (`isolation: none`, `cwd: <worktree>`, in-worktree story path) and **repeat until
the Phase 3.5 ✓ COMPLETE gate passes**, capped at 3 rounds. Loop mechanics + commands:
[`references/pipeline.md`](references/pipeline.md) Phase 6 Option 3. Three rules:

- **Done is the gate, never the message** — `complete` = criteria all `[x]` + clean tree +
  QA green (Phase 3.5), never the agent's "Done".
- **Zero-progress round = STUCK, not success** — if a round returns the same commit count
  AND same working-tree diff (the `0 tool uses · Done` no-op), break and flag `🚫 STUCK`;
  never accept it, never merge it.
- **CAP reached while still progressing** → too large for one budget: stop and **recommend
  splitting**. Do not claim done.

Verified complete → re-run Phase 4 → 5 → 5.5, then back to this prompt as merge-eligible.
The loop's only exits — *verified complete* or *flagged (stuck / too-large)* — guarantee a
worktree can never again silently report Done with unfinished or empty work.

**Option 4 — Re-dispatch from scratch (✗ failed / empty stories).** Re-run Phase 3 with
**new** worktrees only for stories that failed with an error or have an empty diff (no
salvageable progress). Do NOT use this for ◐ incomplete stories — it discards their work.

## PHASE 7: WORKTREE CLEANUP

Always run after a successful merge. List worktrees, remove each
`.claude/worktrees/agent-*` with double-force (`git worktree remove -f -f` — agent
worktrees are locked by default), then `git worktree prune` and confirm only main
remains. Commands: [`references/pipeline.md`](references/pipeline.md). Print cleanup
confirmation (format in `references/conflict-format.md`).

## RULES

- **Never read individual story files in Phase 1** — the index is the only discovery source; bootstrap is the sole exception.
- **Never let sub-agents edit `STORIES_INDEX.md`, `FEATURE_INDEX.md`, or `EPIC.md`** — the orchestrator is their single writer, reconciling once on the target branch after each merge.
- **Never modify story files in `tasks/` directly** — `/ck-code:build` owns them.
- **Never hardcode `main`** — freeze `$TARGET` / `$TARGET_SHA` once (Phase 3.0) and use it for integrity, conflict, and merge.
- **Never reattach to a returned sub-agent** — the worktree is its only durable state.
- **Never trust an agent's self-report** — completion is orchestrator-verified (Phase 3.5 gate); a zero-progress continue round is `🚫 STUCK`.
- **Never merge** a branch without QA (Phase 5) and `MANUAL-TEST PASS` (Phase 5.5).
- **Never re-dispatch a ◐ incomplete story from scratch** — continue in place (Phase 6 Option 3); fresh worktrees are only for ✗ failed / empty-diff stories.
- **Never escalate the sub-agent model on `Size:` alone** (Phase 3.1) — tier by reasoning complexity.
- **Never run heavy QA commands inline** — delegate to parallel `ck-code:qa-validator` (Haiku) agents; inline is the fallback when that subagent_type is unregistered.
- **Never run a deep wave chain silently** — the Wave Depth Guard requires `PROCEED / SPLIT` confirmation.
- **Never dispatch a wave story whose blocker is unresolved**, and never span epics in one wave plan.
- **Always dispatch agents in a single message** — one turn, multiple Agent calls.
- **Always isolate** each dispatched agent in its own worktree (`isolation: worktree`).
- **Always WIP-commit dirty worktrees** before resume or cleanup (Phase 3.5a).
- **Always merge a wave before dispatching the next** (wave mode).
- **Always run final QA on the merged target** before cleanup, then delete every agent worktree.
- **Single-story *batches* short-circuit to `/ck-code:build`; single-story *waves* do not** (Phase 2.5 / 2.7).

## NEXT

For each story branch that passed QA: run `/ck-code:ship <story-path>` to commit, open the PR, and update the linked GitHub Issues. Then `/ck-code:track next` to find the next batch.
