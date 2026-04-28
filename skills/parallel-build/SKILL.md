---
name: parallel-build
description: >
  Use when multiple stories are ready (dependencies met) and you want to
  implement them in parallel. Discovers unblocked stories, lets you select
  which to run, dispatches parallel sub-agents in isolated git worktrees each
  invoking /ck-code:build, then runs conflict analysis and integration QA before
  merge. Reports file conflicts before any merge happens.
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

## PHASE 1: DISCOVERY

Find all stories ready to implement.

### 1.1 Parse Story Files

Glob `tasks/*/epics/*/stories/*.md`. For each, Read and extract:
- `Status:` (`TODO` / `DONE` / `IN PROGRESS` / `SKIP`)
- `Size:` (`S` / `M` / `L` / `XL`)
- `Blocked by:` list in Dependencies section
- Story ID from path: epic `02_juce-engine` + story `05_mixer.md` → `02-05`
- Epic display name from parent folder (`02_juce-engine` → `02 · JUCE Engine`)

### 1.2 Resolve Dependency Graph

Build map: story ID → `{ status, size, epic, blockedBy: [] }`. A story is **ready** if
`Status: TODO` AND every ID in `Blocked by:` has `Status: DONE` (empty `Blocked by:`
is always ready).

### 1.3 Handle Empty Result

If no ready stories: tell the user which TODO stories are still blocked and which of
their blocking deps are not yet DONE. Stop.

## PHASE 2: INTERACTIVE SELECTION

Show ready stories, let the user pick. Skip if `$ARGUMENTS` provided.

### 2.1 Display Table

Print the ready-stories table (format: `references/conflict-format.md`).

### 2.2 Wait for Input

Use AskUserQuestion. Parse:
- `"all"` → every story in the table
- `"1 3 4"` → stories at those positions
- `"02-05 03-01"` → match by story ID directly

If invalid/empty, ask again once. If still invalid, stop.

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

## PHASE 6: CLEANUP PROMPT

Print final summary with three options (format in `references/conflict-format.md`):
1. Merge ready branches now (conflict-free order)
2. Review worktrees first, merge manually
3. Re-run `/ck-code:build` on failing stories

Use AskUserQuestion to wait for the choice.

**Option 1:** merge QA-passing, conflict-free branches in suggested order:

```bash
git checkout main
git merge --no-ff story/XX-YY -m "feat: implement story XX-YY"
```

Then run a final QA on merged main (TypeScript + tests) to catch cross-branch
integration issues. If all clean, proceed to **Phase 7**.

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

- **Never merge** a story branch without QA passing first.
- **Always dispatch all agents in one message** — not sequentially. True parallelism
  requires multiple Agent calls in a single turn.
- **Always isolate** each agent in its own worktree (`isolation: worktree`).
- **Always run dry-run merge conflict detection** (Phase 4) before any merge.
- **Always delete** agent worktrees after merging — `git worktree remove -f -f` then
  `git worktree prune`.
- **Never modify** story files in `tasks/` directly — `/ck-code:build` handles that.
- **Single-story runs:** full flow still runs (worktree + QA + dry-run merge); only
  the cross-branch overlap step is skipped.
- **Run final QA on merged main** before cleanup — cross-branch integration issues
  only appear after all merges.
