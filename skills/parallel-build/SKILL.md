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

- `references/context-budget.md` — what the orchestrator may run inline vs. must delegate
- `references/agent-prompts.md` — sub-agent dispatch prompt template + announce/result formats
- `references/conflict-format.md` — output formats for table, conflict report, QA, summary, cleanup
- `references/examples.md` — full worked example of a multi-story run
- `references/wave-mode.md` — dependency-ordered multi-wave epic builds (`--epic NN`)
- `references/pipeline.md` — bash mechanics for model resolution, integrity, conflict, merge, cleanup

## CONTEXT BUDGET (applies to every phase)

This orchestrator is the **longest-lived context in the run** — everything it loads is re-paid
on every later turn, wave, and merge, while a sub-agent's context is discarded on return. So it
**decides and routes; it never builds, tests, or reads code.**

Inline only **bounded output**: index tables, file paths, counts, statuses, SHAs. Delegate
everything that scales with the codebase, the diff, or the test suite — story implementation
(**at any N, including N=1**), QA (per-story *and* post-merge), conflict dry-runs, post-merge
bug fixes. Delegation table, safe-inline commands, forbidden-inline list:
[`references/context-budget.md`](references/context-budget.md).

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

A story is **ready** if its `Status` is `TODO` AND every ID in its `Blocked by` cell resolves to `Status: DONE` in the same table (empty `Blocked by` is always ready), **or if its `Status` is `BUG`** (a triaged bug from `/ck-code:fix` — the dispatched `/ck-code:build` enters Bug-Fix Mode and implements its recorded Fix Plan on a `fix/` branch). Build the ready list directly from the index rows. Multiple `BUG` stories sharing one `Bug ID` fix in parallel like any other independent stories.

### 1.3 Handle Empty Result

If no stories are ready: list the still-blocked `TODO` stories and which of their `Blocked by` IDs are not yet `DONE` (the index has both). Stop.

### 1.4 Recommend Parallel-Safe Set

From the ready set, recommend which stories are safe to build **at the same time** —
i.e. their declared file scopes don't overlap, so they won't collide at merge.

1. Extract **only the file paths** from each ready story's `Files to Create/Modify` table in
   a single batched Bash call (the index lacks file scopes, so this targeted extraction is
   allowed here, unlike Phase-1 discovery). Never a full `Read` of the story body, and never
   the table's description column — overlap detection needs paths and nothing else:

   ```bash
   for f in <ready-story paths from the index `File` column>; do
     echo "== $f"
     awk '/^## Files to Create\/Modify/{p=1;next} /^## /{p=0} p' "$f" \
       | grep -oE '`[^`]+`' | tr -d '`' | grep '/' | sort -u
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

**Wave mode is scoped to a single epic — never a whole feature.** A multi-epic feature
produces one candidate per epic; do NOT offer a "whole feature in waves" option and never
merge stories from different epics into one wave plan (rationale:
[`references/wave-mode.md`](references/wave-mode.md)). Build one epic per run.

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

## PHASE 2.5: SINGLE-STORY LEAN PATH (N=1 — still a worktree)

Before any dispatch, check the selected set size. **A single story never builds inline in this
orchestrator** — inlining `/ck-code:build` saves one worktree and buys that build's entire
transcript into every later phase (see
[`references/context-budget.md`](references/context-budget.md) → *Why N=1 Still Uses a Worktree*).

**If exactly one story is in scope** (Phase 1.2 resolved one ready story, the user selected
one in Phase 2, or `$ARGUMENTS` was a single story ID), run the **normal pipeline with N=1**:

- **Phase 3** — dispatch one worktree agent, exactly as for N=8.
- **Phase 3.5** — full integrity gate. Unchanged; this is what makes "done" objective.
- **Phase 4** — run the branch's dry-run merge onto `$TARGET`, but **skip cross-branch
  overlap detection**: with one branch there is nothing to compare against.
- **Phases 5 → 7** — unchanged.

Print a short notice before dispatching:

```
Only one story ready / selected: [EE-SS] [Title]
Dispatching 1 agent in an isolated worktree (skipping cross-branch conflict analysis).
```

**If two or more stories are in scope**, continue to Phase 3 with full parallel dispatch.

---

## PHASE 2.7: WAVE MODE (epic-scoped, dependency-ordered)

Entered only when `$ARGUMENTS` is `--epic NN` (or interactive selection chose "whole
epic in waves"). Skip this phase entirely for an explicit story-ID batch.

Wave mode drives **one epic to completion in dependency-ordered waves**, running the
Phase 3–7 pipeline **once per wave** and merging each wave into the target branch before
the next so dependents see their dependencies `DONE`. Scope is a single epic — never a
whole feature; after the epic completes, the operator picks the next epic (no auto-chaining).

Follow [`references/wave-mode.md`](references/wave-mode.md) in full. Key contract:

1. **Plan** the waves from the index (topological levels by `Blocked by`, restricted to
   this one epic), apply the **dynamic Wave Depth Guard** (recommended ceiling from story
   count; WARN + confirm `PROCEED / SPLIT` if natural depth exceeds it), print the wave
   plan table, and create one Claude Task per scheduled story prefixed by wave (`W1 · …`).
2. **Per wave:** confirm (`YES / SKIP STORY / ABORT`) → branch worktrees from the **target
   branch's current HEAD** (carries prior waves' merged code) → run Phase 3 → 3.5 → 4 → 5
   → **merge this wave** (Phase 6 Option 1) → **manual-test the merged wave on the target**
   (Phase 6.5) → **cleanup this wave's worktrees** (Phase 7) → mark its Tasks `completed`.
3. **Re-resolve** the next wave's ready set from the freshly-merged index and loop until
   the epic is done. A story whose blocker ended up BLOCKED-from-merge is **held** and
   reported, not dispatched.

A single-story wave takes the same lean N=1 path as any single-story batch (Phase 2.5) —
worktree dispatch, never inline `/ck-code:build`, **terminal wave included**.

---

## PHASE 3: PARALLEL EXECUTION

Create worktrees and dispatch all sub-agents in one parallel batch.

### 3.0 Freeze the Target, Then Create the Worktrees (base pin — do this FIRST)

Before any dispatch: **freeze the merge target once** (`$TARGET` = current branch,
`$TARGET_SHA` = its HEAD; detached HEAD → stop and ask; tree must be clean), then **create
every worktree yourself**, each cut from `$TARGET_SHA` on branch `$PREFIX$ID`. Every later
phase uses `$TARGET` / `$TARGET_SHA` — **never a hardcoded `main`** (the operator may be on
a `docs`, feature, or wave-target branch).

**Never let the Agent tool create the worktree.** Its `isolation: worktree` cuts from a base
you cannot choose and names the branch itself, so agents land on an arbitrary commit that may
not contain their story file — and no after-the-fact repair helps, because the agent has
already failed. Orchestrator-created worktrees make base correctness a **launch-time
guarantee**, which is why Phase 3.5b is now a cheap assertion rather than a rebase.

Check **every** branch name for collision before creating **any** worktree — a stale
`story/04-04` from an unrelated feature must never be reused; on collision, ask once for a
run-scoped `$PREFIX` (e.g. `story/conn-`) and apply it to the whole run. Then verify each
worktree sits on `$TARGET_SHA` and contains its story file. Commands + the Agent-tool
contract: [`references/pipeline.md`](references/pipeline.md) Phase 3.0.

### 3.1 Model Selection

Pick a model **tier by reasoning complexity, not by story `Size:`** — Size reflects
scope (file count), not difficulty. **Default every story to `balanced` (Sonnet)**;
escalate to `advanced` (Opus) only on a clear high-reasoning signal, reserve
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
- **3.5 / 4 / 5** → a 🚫 BLOCKED or QA-failed story stays `in_progress` with the
  blocker recorded in its task.
- **6.5 manual-test gate** → mark `completed` once the merged story passes its gate (or
  the operator accepts it with a known issue). A reverted or escalated story stays
  `in_progress`.

Run TaskList at the 3.4, 5, and 6.5 checkpoints to print the board.

**Use Claude Tasks when the Task tools are available.** If they are not, skip the board
and rely on the per-story status tables already printed in Phases 3.4 / 5 / 6.

### 3.3 Dispatch All Agents — SINGLE MESSAGE, TRULY PARALLEL

**CRITICAL:** You MUST dispatch ALL sub-agents in a single response message (multiple
Agent tool calls in one turn). Do NOT dispatch them sequentially.

For each story, dispatch one Agent call with the model from 3.1 and the prompt template from
`references/agent-prompts.md`. The prompt instructs the agent to `cd` into its worktree, read
the story file there, and invoke `/ck-code:build` via the Skill tool, which handles TDD,
SOLID, QA, and commit.

**Pass no `isolation` parameter** — the worktree already exists (Phase 3.0c), and the tool
offers no way to point an agent at it. The working directory travels **in the prompt body**:
absolute path + mandatory first `cd` + a `git rev-parse --show-toplevel` STEP-0 guard that
aborts on mismatch. Omitting `isolation` *without* that guard silently runs the agent in the
main checkout. Why the tool leaves no alternative:
[`references/pipeline.md`](references/pipeline.md) → *The Agent-Tool Contract*.

**Preferred subagent_type:** if available, use `ck-code:story-implementer` (defined
in this plugin's `agents/` folder — it takes the worktree path as an input and enforces the
same STEP-0 guard). If that subagent_type is not registered, fall back to a
`general-purpose` agent with the same prompt.

Worktree rules:

- Each agent works in the `.claude/worktrees/agent-XX-YY` the orchestrator created for it.
- Agents must only modify files relevant to their story, inside their own worktree.
- Agents must NOT modify story files in `tasks/` (the build skill updates those).
- Agents must NOT run `git checkout -b`, `rebase`, or `reset` — the base is pinned and
  asserted on return (Phase 3.5b).
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
   agent can stop with work **uncommitted**. WIP-commit every dirty worktree so it is
   durable and rebaseable.
2. **Assert the base (3.5b).** Phase 3.0c cut every branch from `$TARGET_SHA`, so its
   merge-base must still *be* `$TARGET_SHA` — branches only move forward. Verify it. A
   mismatch is not routine drift; it means an agent rewrote history in its worktree or
   the target moved under the run. Flag 🚫 BLOCKED, keep the worktree, surface it — never
   auto-rebase, which would hide the cause and can drop commits.

Then verify the worktree **story file** reads `Status: DONE` (NOT the index — sub-agents
defer shared-index edits by design, reconciled post-merge; details in
[`references/pipeline.md`](references/pipeline.md) Phase 3.5) and run the
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
**never run the heavy commands inline** (CONTEXT BUDGET). **Dispatch one `ck-code:qa-validator`
agent per completed story**, pinned to the `fast` (Haiku) tier: each runs its stack's QA
commands inside its own worktree and its own cheap context, returning a compact PASS/FAIL
verdict. The orchestrator stays lean and the QA passes run in parallel, not one-by-one.

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
ck-code:qa-validator`, **no `isolation` parameter**, and the **Phase 5 QA-Validation
Sub-Agent** prompt from [`references/agent-prompts.md`](references/agent-prompts.md) carrying
that story's absolute worktree path and its concrete stack commands from 5.1. The agent `cd`s
into the worktree, guards on `git rev-parse --show-toplevel`, runs the commands, captures any
failing output, and returns the QA Report verdict line. **The guard is not ceremony:** an
unguarded QA agent runs the suite in the main checkout and green-lights an unbuilt branch
with a `QA: PASS` for code the story never wrote. If the `ck-code:qa-validator`
subagent_type is not registered, **fall back** to running the 5.1 commands inline per
worktree.

### 5.3 Aggregate Verdicts

Collect each agent's verdict and print the per-story QA Report (format in
`references/conflict-format.md`). Mark any story with QA failures as **BLOCKED from merge** —
keep its worktree. ◐ incomplete and 🚫 blocked stories from Phase 3.5 are not QA candidates.

Automated QA is the last gate before merge. **Manual testing runs after the merge**, on the
target branch — Phase 6.5.

## PHASE 6: CLEANUP PROMPT

Print the final summary with four options (format in `references/conflict-format.md`)
and use AskUserQuestion to wait for the choice:

1. Merge ready branches now (conflict-free order)
2. Review worktrees first, merge manually
3. Continue ◐ incomplete stories in place (resume the work in their existing worktrees)
4. Re-dispatch ✗ failed / empty stories from scratch (new worktrees)

Merge-eligible = Phase 3.5 ✓ COMPLETE (or ⚠ warning) + Phase 5 QA passing + conflict-free.
Manual testing is **not** a merge gate — it runs after the merge, in Phase 6.5.

**Option 1** — merge QA-passing, conflict-free branches in suggested order into the
**orchestrator's current branch** (never a hardcoded `main`; detached HEAD → stop and ask).
Resolve and confirm the target, then merge each branch. Procedure:
[`references/pipeline.md`](references/pipeline.md).

Final QA on the merged target catches cross-branch integration issues — **dispatch it to one
`ck-code:qa-validator` agent** (no `isolation` parameter, so it runs in the main checkout
where the merged target lives; it guards on branch name instead of path — prompt in
[`references/agent-prompts.md`](references/agent-prompts.md)) with the union of the merged
stories' Phase 5.1 commands — a merge does not make test output cheap
([`references/context-budget.md`](references/context-budget.md)). Inline is the fallback
only when that subagent_type is unregistered.

**After the merges land, reconcile the shared indexes once on the target branch** — the
sub-agents deferred every shared-index edit, so the merged tree carries each story file at
`Status: DONE` while the indexes still show the pre-build status. The orchestrator is the
sole writer here, so these edits never conflict. In one pass:

1. `tasks/<slug>/STORIES_INDEX.md` — flip each merged story's `Status` cell to match its
   merged story file: `DONE` for a normal story, or the restored `Prior status` for a
   Bug-Fix Mode story (its worktree `build` already moved the story file `BUG → DONE`)
   (mutation protocol: [`../../references/stories-index.md`](../../references/stories-index.md)).
2. Each merged story's parent `EPIC.md` — set its row in the stories table to `DONE`.
3. `tasks/FEATURE_INDEX.md` — recompute the built feature's `Stories` count and roll up its
   `Status`: mark the feature `DONE` if its last story is now merged, else `IN PROGRESS`. Never
   leave the rollup stale after a completed parallel build (per
   [`../../references/feature-index.md`](../../references/feature-index.md)).

Commit the reconciliation on the target branch. If clean, proceed to **Phase 6.5**
(manual testing), then **Phase 7**.

**Option 2** — print worktree paths and stop; worktrees stay intact for manual review.
Remind the user to run Phase 6.5 then Phase 7 after merging.

**Option 3 — Continue in place (◐ incomplete stories) — AUTO-CONTINUE UNTIL VERIFIED.**
One dispatch cannot be guaranteed to finish an XL story (the per-agent budget is the
harness's, not ours), so completion is reached by *looping*, not by hoping one retry lands.
For each ◐ incomplete story, dispatch a fresh Continue-Incomplete agent INTO its existing
worktree (**no `isolation` parameter** — `isolation: worktree` would hand it a new, empty
tree and discard the partial work; the prompt carries the absolute worktree path, the `cd`,
the STEP-0 guard, and the in-worktree story path) and **repeat until
the Phase 3.5 ✓ COMPLETE gate passes**, capped at 3 rounds. Loop mechanics + commands:
[`references/pipeline.md`](references/pipeline.md) Phase 6 Option 3. Three rules:

- **Done is the gate, never the message** — `complete` = criteria all `[x]` + clean tree +
  QA green (Phase 3.5), never the agent's "Done".
- **Zero-progress round = STUCK, not success** — if a round returns the same commit count
  AND same working-tree diff (the `0 tool uses · Done` no-op), break and flag `🚫 STUCK`;
  never accept it, never merge it.
- **CAP reached while still progressing** → too large for one budget: stop and **recommend
  splitting**. Do not claim done.

Verified complete → re-run Phase 4 → 5, then back to this prompt as merge-eligible.
The loop's only exits — *verified complete* or *flagged (stuck / too-large)* — guarantee a
worktree can never again silently report Done with unfinished or empty work.

**Option 4 — Re-dispatch from scratch (✗ failed / empty stories).** Re-run Phase 3 with
**new** worktrees only for stories that failed with an error or have an empty diff (no
salvageable progress). Do NOT use this for ◐ incomplete stories — it discards their work.

## PHASE 6.5: POST-MERGE MANUAL TESTING GATE (target branch, sequential)

Runs after the Option-1 merge, index reconciliation, and post-merge QA — **before** Phase 7
cleanup. Manual testing never happens inside an agent worktree: a throwaway
`.claude/worktrees/agent-XX-YY` tree has no installed dependencies, dev server, env, or
DB, and holds one story's code in isolation from its siblings'. The only place the operator
can exercise the software is the main checkout on `$TARGET`, where every merged story sits
together. Sub-agents also cannot prompt the user, so this gate is always orchestrator-level.

For each merged story, sequentially (cap 3 cycles per story):

**6.5.1** Present the manual-test prompt (template in `references/conflict-format.md`) with
scenarios from the story's acceptance criteria + one edge case. Extract **only** the
`## Acceptance Criteria` section (command in
[`references/context-budget.md`](references/context-budget.md)) — never `Read` the whole
story body. Ask `Result? PASS / ISSUES`.

**6.5.2** On `PASS` → mark the story `MANUAL-TEST PASS` and its Task `completed`.

**6.5.3** On `ISSUES` → capture the bug, then dispatch ONE Agent into the **main checkout on
`$TARGET`** (no `isolation` parameter — omitting it lands the agent in the main checkout,
which is the intent here; prompt in `references/agent-prompts.md` —
Phase 6.5.3 Bug-Fix Sub-Agent). The story is already merged, so the fix commits to `$TARGET`
— never to the story worktree, whose branch is no longer the source of truth. The agent
invokes `/ck-code:build`, which re-enters at Phase 8.5.3 (regression test → fix → Refactor →
QA). On return, loop back to 6.5.1 for the same story.

**6.5.4** On the third `ISSUES`, escalate (template in `references/conflict-format.md` Phase
6.5.4): **A) fix manually**, **B) accept as a known issue**, or **C) revert** the story's
merge commit (`git revert -m 1 <merge-sha>`), which reopens the story `IN PROGRESS` in the
indexes and keeps its worktree for Phase 6 Option 3.

**Wave mode runs this gate once per wave**, right after that wave's merge and before its
worktree cleanup — so a dependent wave never builds on code the operator has not exercised.

## PHASE 7: WORKTREE CLEANUP

Always run after the merge and its Phase 6.5 gate. List worktrees, remove each
`.claude/worktrees/agent-XX-YY` with `git worktree remove -f` (orchestrator-created
worktrees are not locked; `-f` only forces past a dirty tree), then `git worktree prune`
and confirm only main remains. Commands: [`references/pipeline.md`](references/pipeline.md).
Print cleanup confirmation (format in `references/conflict-format.md`).

## RULES

- **Never build inline in this orchestrator** — every story implementation is dispatched to a worktree agent, at any N, in every wave, terminal wave included (Phase 2.5).
- **Never run unbounded output inline** — builds, test suites, lint, diff bodies, and full story or source `Read`s all belong in a sub-agent. The orchestrator sees counts, names, statuses, and SHAs only ([`references/context-budget.md`](references/context-budget.md)).
- **Never read individual story files in Phase 1** — the index is the only discovery source; bootstrap is the sole exception.
- **Never let sub-agents edit `STORIES_INDEX.md`, `FEATURE_INDEX.md`, or `EPIC.md`** — the orchestrator is their single writer, reconciling once on the target branch after each merge.
- **Never modify story files in `tasks/` directly** — `/ck-code:build` owns them.
- **Never hardcode `main`** — freeze `$TARGET` / `$TARGET_SHA` once (Phase 3.0) and use it for integrity, conflict, and merge.
- **Never pass `isolation` or `cwd` to the Agent tool** — there is no `cwd`, and `isolation: none` is an invalid enum value, not an opt-out. A worktree agent is placed by prompt text: absolute path + first-call `cd` + STEP-0 `git rev-parse --show-toplevel` guard.
- **Never reuse an existing branch name** — check every `$PREFIX$ID` for collision before creating any worktree (Phase 3.0b); on collision take a run-scoped `$PREFIX`.
- **Never auto-rebase a drifted branch** — with a pinned base, a 3.5b assertion failure is an anomaly to surface, not drift to silently repair.
- **Never reattach to a returned sub-agent** — the worktree is its only durable state.
- **Never trust an agent's self-report** — completion is orchestrator-verified (Phase 3.5 gate); a zero-progress continue round is `🚫 STUCK`.
- **Never merge** a branch that has not passed Phase 5 QA.
- **Never manual-test inside a worktree** — the gate runs post-merge on `$TARGET` in the main checkout (Phase 6.5), once per wave in wave mode, and its bug fixes commit to `$TARGET`.
- **Never clean up worktrees before the Phase 6.5 gate settles** — a `C) revert` verdict needs the story's worktree back.
- **Never re-dispatch a ◐ incomplete story from scratch** — continue in place (Phase 6 Option 3); fresh worktrees are only for ✗ failed / empty-diff stories.
- **Never escalate the sub-agent model on `Size:` alone** (Phase 3.1) — tier by reasoning complexity.
- **Never run heavy QA commands inline** — delegate to `ck-code:qa-validator` (Haiku) agents, per-story (Phase 5) *and* post-merge (Phase 6); inline is the fallback when that subagent_type is unregistered.
- **Never run a deep wave chain silently** — the Wave Depth Guard requires `PROCEED / SPLIT` confirmation.
- **Never dispatch a wave story whose blocker is unresolved**, and never span epics in one wave plan.
- **Always dispatch agents in a single message** — one turn, multiple Agent calls.
- **Always create the worktrees in the orchestrator** (Phase 3.0c), one per story, cut from `$TARGET_SHA`, and verify base + story-file presence before dispatch.
- **Always WIP-commit dirty worktrees** before resume or cleanup (Phase 3.5a).
- **Always merge a wave before dispatching the next** (wave mode).
- **Always run final QA on the merged target** before cleanup (delegated), then delete every agent worktree.
- **A single story is a lean N=1 run, not a short-circuit** — same pipeline, minus cross-branch conflict analysis (Phase 2.5).

## NEXT

For each story branch that passed QA: run `/ck-code:ship <story-path>` to commit, open the PR, and update the linked GitHub Issues. Then `/ck-code:track next` to find the next batch.
