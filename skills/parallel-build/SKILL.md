---
name: parallel-build
description: Use to implement multiple ready stories concurrently in isolated git worktrees. Argument is optional space-separated story IDs (e.g. `02-05 03-01`); if omitted, picks interactively.
argument-hint: "[story-ids...]  # optional: pre-select stories e.g. 02-05 03-01"
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

## INPUT

`$ARGUMENTS` is an optional space-separated list of story IDs (e.g. `02-05 03-01`).
- If provided: skip Phase 2, go directly to Phase 3 with those stories.
- If empty: run interactive selection (Phase 2).

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

This is a pre-flight heuristic from *declared* scopes — Phase 4 still runs the
authoritative dry-run merge on *actual* diffs after implementation. A story tagged
parallel-safe here can still surface a real conflict in Phase 4.

## PHASE 2: INTERACTIVE SELECTION

Show ready stories, let the user pick. Skip if `$ARGUMENTS` provided.

### 2.1 Display Table

Print the ready-stories table (format: `references/conflict-format.md`).

### 2.2 Wait for Input

Use AskUserQuestion. Parse:
- `"recommended"` → the parallel-safe set from Phase 1.4 (default suggestion)
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

## PHASE 3: PARALLEL EXECUTION

Create worktrees and dispatch all sub-agents in one parallel batch.

### 3.1 Model Selection

Pick a model **tier** by `Size:` — never hardcode versioned model IDs (they go
stale as new Claude generations ship). Resolve the tier to a concrete model
at dispatch time.

| Size | Tier                          | Why                                                 |
| ---- | ----------------------------- | --------------------------------------------------- |
| S    | `fast`                        | Single-file change, quick turnaround                |
| M    | `balanced`                    | Multi-file, moderate logic                          |
| L    | `advanced`                    | Significant logic, integration, or design          |
| XL   | `advanced-extended-context`   | Large story or one needing extended (1M) context    |

**Resolving a tier → concrete model at dispatch:**

1. **Operator override (highest priority).** Read these environment variables;
   if set, use the exact ID:
   - `CK_MODEL_FAST`, `CK_MODEL_BALANCED`, `CK_MODEL_ADVANCED`, `CK_MODEL_ADVANCED_EXTENDED`
2. **Latest-by-tier (default).** Otherwise pick the latest available model for
   the tier from the current Claude family:
   - `fast` → the smallest/fastest model in the latest Claude family (current example: `claude-haiku-4-5`)
   - `balanced` → the mid-tier model in the latest family (current example: `claude-sonnet-4-6`)
   - `advanced` → the top-tier model in the latest family (current example: `claude-opus-4-7`)
   - `advanced-extended-context` → the top-tier model with the long-context variant (current example: `claude-opus-4-7[1m]`)
   The "current example" hints are illustrative only — when newer model IDs
   are known to the running session, use those instead. If unsure, fall back
   to the model the orchestrating Claude is itself running, which is at least
   advanced-tier.
3. **Confirm with user before launch.** Print the resolved table (Size → Tier
   → Concrete Model) in the announce step (3.2) so the operator can override
   if a tier resolved to an unexpected model.

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

After all agents finish, verify each completed story is properly recorded and no implementation was silently lost. Run this before conflict analysis so that integrity issues are surfaced early.

### 3.5.1 Story Status Check (worktree-based)

For each **successfully completed** story, read its story file directly from the agent's worktree path — `<worktree-path>/<relative-story-path>` — and confirm the `Status:` field reads `DONE`.

Do NOT read `STORIES_INDEX.md` from the main checkout — it reflects pre-implementation state because the build skill updates the index inside the worktree, and those changes land on main only after merge.

If the story file in the worktree still shows `TODO` or `IN PROGRESS` → flag as ⚠️ **Story file not updated** — the build skill failed to complete Phase 8. Also check `<worktree-path>/tasks/<slug>/STORIES_INDEX.md` to confirm whether the index and story file are in sync (they must never disagree — see mutation protocol in `../../../references/stories-index.md`).

Acceptance-criteria checkboxes are validated by the build skill's QA phase, not here.

### 3.5.2 Code Change Integrity Check

For each successfully completed story, inspect what the agent actually changed in its
branch relative to `main`:

**3.5.2a — Non-empty diff**

```bash
git diff --stat main...story/XX-YY
```

If the output is empty (no files changed), flag as ⚠️ **No implementation detected** —
the agent may have exited without producing output.

**3.5.2b — Unexpected file deletions**

```bash
git diff main...story/XX-YY --diff-filter=D --name-only
```

Any deleted file is flagged as ⚠️ **Unexpected file deletion: [file]**. Deletion of a
file that was in scope (e.g. a file explicitly replaced by the story) is acceptable only
if a new file clearly supersedes it; otherwise treat it as potential code loss.

**3.5.2c — Pure-deletion files (code loss signal)**

For each modified file, check the addition/deletion balance:

```bash
git diff main...story/XX-YY -- <file> | grep -c "^+"   # additions
git diff main...story/XX-YY -- <file> | grep -c "^-"   # deletions
```

If a file has zero additions and one or more deletions, flag as
⚠️ **Possible code loss in [file]** (lines were removed with nothing added back).

### 3.5.3 Report & Gate

Print the integrity report (format in `references/conflict-format.md`).

Escalation rules:
- ⚠️ **warning** (incomplete criteria, pure-deletion ratio) → story proceeds to QA/merge
  but the warning must appear in the Phase 6 summary so the operator can review.
- 🚫 **BLOCKED** (story file not updated, no implementation detected, unexpected file
  deletion) → story is removed from the merge-eligible set. Keep its worktree. Report
  in Phase 6 under "Review needed".

## PHASE 4: CONFLICT ANALYSIS

Detect file-level conflicts between completed story branches before any merge. Only
analyse branches for **successfully completed** stories.

**Preferred subagent_type:** delegate this phase to `ck-code:conflict-analyzer`
if available (defined in this plugin's `agents/` folder — runs dry-run merges,
classifies risk, recommends merge order, and always aborts cleanly). The
sub-agent returns a structured report which 4.4 reads for the conflict report
output. If the subagent_type is not registered, run the steps below inline.

### 4.1 Get Branch Names

Worktree branch is `story/XX-YY`. Confirm: `git branch --list "story/*"`.

### 4.2 Dry-Run Merge Each Branch

For each successful branch, dry-run merge onto main:

```bash
git checkout main
git merge --no-commit --no-ff story/XX-YY 2>&1
git merge --abort 2>/dev/null || true
```

Record files with conflicts (look for `CONFLICT` lines).

### 4.3 Cross-Branch Conflict Detection

Two branches may both merge cleanly onto main yet conflict with each other. Detect
overlap:

```bash
git diff --name-only main...story/XX-YY
```

Run per branch, collect modified file sets. Any file appearing in 2+ branches is a
potential cross-branch conflict.

### 4.4 Report

Print conflict report (format in `references/conflict-format.md`): per-branch
dry-run result, cross-branch overlaps, and suggested merge order (safest first —
branches with fewer overlaps merge first). If no conflicts at all: print
"No conflicts detected — all branches merge cleanly."

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

Print final summary with three options (format in `references/conflict-format.md`):
1. Merge ready branches now (conflict-free order)
2. Review worktrees first, merge manually
3. Re-run `/ck-code:build` on failing stories

Use AskUserQuestion to wait for the choice.

Stories without `MANUAL-TEST PASS` from Phase 5.5 are **not merge-eligible**
under Option 1, even if QA and conflict checks pass.

**Option 1:** merge QA-passing, manual-test-passing, conflict-free branches in suggested order.

**Determine merge target first.** The merge target is the **orchestrator's current branch** in the main checkout — not a hardcoded `main`. The operator may already be sitting on a feature branch they want all stories rolled into.

```bash
target_branch=$(git -C <main-checkout> branch --show-current)
```

Print the resolved target (e.g. `Merge target: feature/release-2026-05`) and confirm with the user before proceeding. If `target_branch` is empty (detached HEAD), stop and ask the user to check out a real branch first.

Then merge each ready branch:

```bash
git -C <main-checkout> checkout "$target_branch"
git -C <main-checkout> merge --no-ff story/XX-YY -m "feat: implement story XX-YY"
```

Run a final QA on the merged target branch (TypeScript + tests) to catch cross-branch integration issues. If all clean, proceed to **Phase 7**.

**Option 2:** print worktree paths and stop. Worktrees stay intact for manual review.
Remind user to run Phase 7 after merging.

**Option 3:** re-run Phase 3 only for failed/blocked stories (dispatch new agents).

## PHASE 7: WORKTREE CLEANUP

Remove all agent worktrees after a successful merge. Always run after merging.

### 7.1 List and Remove

`git worktree list`. For each worktree under `.claude/worktrees/agent-*`, remove with
double-force (agent worktrees are locked by default):

```bash
git worktree remove -f -f /path/to/.claude/worktrees/agent-XXXXXXXX
```

### 7.2 Prune Stale Refs

`git worktree prune`

### 7.3 Confirm

Run `git worktree list` — only main should remain. Print cleanup confirmation
(format in `references/conflict-format.md`).

## RULES

- **Never read individual story files in Phase 1** — `STORIES_INDEX.md` is the only source of truth for story discovery; bootstrap (absent index or wrong schema) is the sole exception.
- **Never merge** a story branch without QA passing first.
- **Always run per-story manual-testing gate (Phase 5.5)** before merge — sub-agents cannot perform manual testing inside their dispatch, so the orchestrator owns it. A story without `MANUAL-TEST PASS` is never merge-eligible. Cap = 3 cycles per story.
- **Always dispatch all agents in one message** — not sequentially. True parallelism
  requires multiple Agent calls in a single turn.
- **Always track each story as a Claude Task** (Phase 3.2.5) — create at dispatch, keep
  `in_progress` through QA/manual-test, mark `completed` at merge — so the parallel run
  has a live, visible progress board.
- **Always recommend the parallel-safe set** (Phase 1.4) from non-overlapping file
  scopes before selection — it is a pre-flight heuristic, not a substitute for the
  Phase 4 dry-run merge check.
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
