# Pipeline Mechanics — Model Resolution, Integrity, Conflict, Merge, Cleanup

Bash-level procedures for Phases 3.0, 3.1, 3.5, 4, 6, and 7. SKILL.md holds the gates and
decisions; this file holds the exact commands.

## Phase 3.0 — Freeze the Target, Then Create the Worktrees (run before dispatch)

The orchestrator creates every worktree itself, pinned to the frozen base. **Never delegate
worktree creation to the Agent tool's `isolation: worktree`** (rationale: SKILL.md Phase 3.0
and *The Agent-Tool Contract* below).

### 3.0a — Freeze the target

Resolve the target **once** and reuse it in every later phase. `$MAIN` = the main checkout.

```bash
MAIN=$(git rev-parse --show-toplevel)
TARGET=$(git -C "$MAIN" branch --show-current)        # empty → detached HEAD → STOP, ask
TARGET_SHA=$(git -C "$MAIN" rev-parse HEAD)
git -C "$MAIN" status --porcelain                      # must be clean before dispatch
```

Carry `$TARGET` / `$TARGET_SHA` into Phases 3.5, 4, and 6. **Never substitute a literal
`main`** — the operator may be on `docs`, a feature branch, or a wave target.

### 3.0b — Branch collision guard (check ALL before creating ANY)

`git worktree add -b` fails on an existing branch. Check the whole set first so the run
never dies half-created, leaving orphan worktrees to clean up:

```bash
PREFIX="story/"                                        # operator may override once, below
for id in $STORY_IDS; do                               # e.g. "04-01 04-02"
  git -C "$MAIN" rev-parse --verify --quiet "refs/heads/${PREFIX}${id}" >/dev/null \
    && echo "COLLISION: ${PREFIX}${id} already exists"
done
```

Any collision → **STOP**. A stale `story/04-04` from an unrelated feature must never be
reused: its commits would ride into this merge. AskUserQuestion for a run-scoped `$PREFIX`
(e.g. `story/conn-`), apply it to **every** story in the run, and re-run this check.

### 3.0c — Create one pinned worktree per story

```bash
for id in $STORY_IDS; do
  WT="$MAIN/.claude/worktrees/agent-${id}"             # deterministic: Phase 6 Option 3 finds it
  git -C "$MAIN" worktree add -b "${PREFIX}${id}" "$WT" "$TARGET_SHA"
done
```

### 3.0d — Verify before dispatch (cheap, bounded, catches everything)

```bash
for id in $STORY_IDS; do
  WT="$MAIN/.claude/worktrees/agent-${id}"
  [ "$(git -C "$WT" rev-parse HEAD)" = "$TARGET_SHA" ] || echo "BAD BASE: $id"
  [ -f "$WT/<rel-story-path>" ]                        || echo "STORY FILE MISSING: $id"
done
```

Both lines silent → dispatch. Any output → **STOP**; the base pin or story path is wrong,
and every agent would fail the same way.

### The Agent-Tool Contract (why the dispatch looks the way it does)

The Agent tool takes `isolation: "worktree" | "remote"` and **nothing else** for placement.
There is **no `isolation: none`** and **no `cwd` parameter**.

- Passing `isolation: worktree` surrenders base and branch naming to the harness.
- Passing `isolation: none` is not a no-op-to-omitting — it is an **invalid enum value**.
- Omitting `isolation` runs the agent **in the main checkout**, not in a worktree.

So the working directory can only be conveyed **inside the prompt text**. Every dispatched
agent gets an absolute worktree path, a mandatory `cd` as its first Bash call (the Bash tool
keeps that directory across later calls), and a `git rev-parse --show-toplevel` STEP-0 guard
that aborts on mismatch. The guard is what turns "silently ran in the wrong tree and
reported PASS" into a loud `WRONG WORKTREE`.

## Phase 3.1 — Model Tier Resolution

Pick the tier by **reasoning complexity**, inferred from the story's technical notes,
acceptance criteria, and file scope — NOT from `Size:`. After plan consolidation, Size
measures scope (file count), not difficulty: a broad CRUD / UI / wiring story is L or
even XL yet routine, and Sonnet handles it well. Reserve Opus for work that genuinely
needs deep reasoning. Never hardcode a versioned model ID.

| Complexity signal in the story                                                                                                                                                                                              | Tier                        | Model (default) |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- | --------------- |
| Trivial mechanical change — rename, config bump, single tiny file                                                                                                                                                           | `fast`                      | Haiku           |
| **Standard feature work — CRUD, endpoints, UI, wiring, glue, refactor, or integration that follows an existing pattern (most stories, any Size)**                                                                           | `balanced`                  | **Sonnet**      |
| High-reasoning — novel algorithms, concurrency/parallelism, distributed correctness, intricate state machines, security- or performance-critical paths, non-obvious architecture/design, gnarly cross-component integration | `advanced`                  | Opus            |
| High-reasoning **and** large surface (XL / many files / large existing code to hold in context)                                                                                                                             | `advanced-extended-context` | Opus (1M)       |

**Default is `balanced`.** Escalate to `advanced` only when at least one high-reasoning
signal is clearly present in the story; Size alone never escalates. When genuinely torn
between balanced and advanced on a security- or correctness-critical story, prefer
`advanced`. Two stories of the same Size can resolve to different models — that is the
point.

Resolve tier → concrete model at dispatch:

1. **Operator override (highest priority):** if set, use the exact ID from
   `CK_MODEL_FAST`, `CK_MODEL_BALANCED`, `CK_MODEL_ADVANCED`, `CK_MODEL_ADVANCED_EXTENDED`.
2. **Latest-by-tier (default):** pick the latest model in the current Claude family —
   `fast` → smallest/fastest (e.g. `claude-haiku-4-5`), `balanced` → mid-tier
   (e.g. `claude-sonnet-4-6`), `advanced` → top-tier (e.g. `claude-opus-4-8`),
   `advanced-extended-context` → top-tier long-context (e.g. `claude-opus-4-8[1m]`).
   Examples are illustrative — prefer newer IDs known to the session.
3. **Confirm before launch:** print the resolved Story → Complexity → Tier → Model table
   in the announce step (3.2) so the operator can override a mis-resolution.

## Phase 3.5a — Preserve Uncommitted Work (run FIRST, per worktree)

An early stop can leave real work uncommitted (transcript 01-01 had no commit at all). WIP-
commit any dirty worktree so it is durable and rebaseable before normalize / continue /
cleanup:

```bash
if [ -n "$(git -C "$WT" status --porcelain)" ]; then
  git -C "$WT" add -A
  git -C "$WT" commit -m "wip(XX-YY): preserve partial work before resume" --no-verify
fi
```

## Phase 3.5b — Assert the Base Is Still $TARGET_SHA (per story branch)

Phase 3.0c cut every branch from `$TARGET_SHA`, so its merge-base **must** still be
`$TARGET_SHA` — a branch can only move forward from where it started. This is now an
assertion, not a repair:

```bash
MB=$(git -C "$MAIN" merge-base "${PREFIX}${id}" "$TARGET_SHA")
if [ "$MB" != "$TARGET_SHA" ]; then
  echo "🚫 BLOCKED ${id} — base drifted from \$TARGET_SHA"
fi
```

A failure here is a **real anomaly**, not routine drift: an agent rebased or reset inside
its worktree, or the target branch was rewritten mid-run. Do not auto-rebase it away —
that would paper over a bug and could silently drop commits. Flag 🚫 BLOCKED, keep the
worktree, and let the operator inspect. Manual recovery, once the cause is understood:
`git -C "$MAIN" rebase --onto "$TARGET_SHA" "$MB" "${PREFIX}${id}"`.

With the assertion green, `git diff $TARGET_SHA...${PREFIX}${id}` is exactly the story's
work and the Phase 6 merge cannot drag in foreign base commits.

## Phase 3.5 — Integrity Checks

Run per **successfully completed** story, before conflict analysis. (`$TARGET_SHA` from
Phase 3.0 — never a literal `main`.)

**Status check (worktree-based):** read the story file from `<worktree-path>/<rel-path>`
and confirm `Status: DONE`. Do NOT read `STORIES_INDEX.md` from the main checkout — it is
pre-implementation until merge. If the worktree story file still shows TODO/IN PROGRESS →
⚠️ **Story file not updated** (build failed to complete Phase 8). Do NOT check the
worktree's `STORIES_INDEX.md` / `EPIC.md` for sync — sub-agents defer all shared-index
edits in parallel mode, so those files are intentionally at their pre-build status and a
mismatch is expected, not drift. The orchestrator reconciles them post-merge (Phase 6).

**Code integrity (relative to `$TARGET_SHA`).** Every command below has bounded output —
never pipe a diff **body** into the orchestrator (`references/context-budget.md`):

```bash
B="${PREFIX}${id}"
git -C "$MAIN" diff --shortstat "$TARGET_SHA"..."$B"                  # empty → ⚠️ No implementation detected
git -C "$MAIN" diff --name-only --diff-filter=D "$TARGET_SHA"..."$B"  # any line → ⚠️ Unexpected file deletion
git -C "$MAIN" diff --numstat "$TARGET_SHA"..."$B"                    # "added<TAB>deleted<TAB>path" per file:
                                                                      #   added==0 && deleted>0 → ⚠️ Possible code loss
```

`--numstat` gives the per-file added/deleted counts that the old `grep -c "^+"` pipeline
extracted from full diff text, at a fraction of the tokens.

A deletion is acceptable only if a new file clearly supersedes the removed one; otherwise
treat it as potential code loss.

**`complete(worktree)` — the objective ✓ COMPLETE gate (used by Phase 6 Option 3):**

```bash
# 1. story file Status: DONE
grep -q '^Status: *DONE' "$WT/<rel-path>"
# 2. zero unchecked acceptance criteria (no "- [ ]" under the criteria section)
! grep -qE '^\s*-\s*\[ \]' "$WT/<rel-path>"
# 3. clean tree (all work committed)
[ -z "$(git -C "$WT" status --porcelain)" ]
# 4. QA green — a `ck-code:qa-validator` agent in $WT returns `QA: PASS` (never run inline)
```

Checks 1–3 are bounded greps the orchestrator runs itself. Check 4 is a dispatched agent —
so a re-check inside the Option 3 loop costs the orchestrator one verdict line per round,
not a full test suite per round.

All four true → ✓ COMPLETE. Any false → not complete (keep looping / flag). This is the
only definition of "done"; the agent's final message is never used as proof.

**Gate outcomes (✓ / ⚠️ / ◐ / 🚫):** defined in SKILL.md Phase 3.5.

## Phase 4 — Conflict Analysis (per successful branch)

Inline fallback only — prefer the `ck-code:conflict-analyzer` agent. Keep every command's
output bounded: grep the dry-run down to its `CONFLICT` lines, never let merge hunks land in
the orchestrator.

```bash
git -C "$MAIN" branch --list "${PREFIX}*"              # 4.1 confirm this run's branch names
# 4.2 dry-run merge each onto the frozen target (record CONFLICT lines only):
git -C "$MAIN" checkout "$TARGET"
git -C "$MAIN" merge --no-commit --no-ff "${PREFIX}${id}" 2>&1 | grep '^CONFLICT' || echo "clean"
git -C "$MAIN" merge --abort 2>/dev/null || true
# 4.3 cross-branch overlap (a file in 2+ branches is a potential cross-branch conflict):
git -C "$MAIN" diff --name-only "$TARGET_SHA"..."${PREFIX}${id}"
```

**N=1 (Phase 2.5 / a single-story wave):** run 4.1 and 4.2 only. Step 4.3 compares branches
against each other — with one branch there is nothing to compare.

Report (format: `conflict-format.md`): per-branch dry-run, cross-branch overlaps,
suggested merge order (fewest overlaps first). No conflicts → "No conflicts detected —
all branches merge cleanly."

## Phase 6 Option 1 — Merge Procedure

Merge target = `$TARGET`, frozen in Phase 3.0a — never hardcoded `main`, and never
re-derived here (the working branch may have moved since dispatch). Print it and confirm,
then merge each merge-eligible branch in suggested order:

```bash
git -C "$MAIN" checkout "$TARGET"
git -C "$MAIN" merge --no-ff "${PREFIX}${id}" -m "feat: implement story ${id}"
```

**Then reconcile the shared indexes on the target branch (orchestrator is the sole
writer — no conflict possible).** Sub-agents deferred these edits, so each merged story
file reads `DONE` but the indexes still show pre-build status. For each merged story, Edit
on the target checkout:

```
STORIES_INDEX.md  →  flip the story's row Status cell to DONE
EPIC.md           →  flip the story's row in the epic stories table to DONE
FEATURE_INDEX.md  →  recompute the feature's Stories count + Status rollup (DONE on last story)
```

Then `git -C <main-checkout> add` those index files and commit (e.g.
`chore: reconcile story/feature indexes after parallel merge`).

**Post-merge QA — delegate, do not run inline.** Cross-branch integration issues are caught
by running the merged target's suites, and that output is exactly as large after a merge as
before it. Dispatch ONE `ck-code:qa-validator` agent (**no `isolation` parameter** — the main
checkout is exactly where this one belongs; prompt in `agent-prompts.md` → *Phase 6 —
Post-Merge QA Sub-Agent*) with the **union** of the merged stories' Phase 5.1 stack commands,
de-duplicated. It returns a single verdict line.

- `QA: PASS` → proceed to Phase 6.5 (manual-test gate), then Phase 7.
- `QA: FAIL` → do **not** clean up worktrees. Report the failing command, and treat it as a
  cross-branch integration failure: the individual branches each passed Phase 5, so the
  breakage is in their combination. Offer `git revert -m 1 <merge-sha>` on the last-merged
  story, or a fix agent on `$TARGET` (Phase 6.5.3 prompt).

Inline execution is the fallback only when `ck-code:qa-validator` is unregistered.

## Phase 6 Option 3 — Auto-Continue Loop (per ◐ incomplete story)

Loop until the ✓ COMPLETE gate (Phase 3.5) passes, with a work-proof guard so a no-op round
can never masquerade as success:

```bash
WT="$MAIN/.claude/worktrees/agent-${id}"; CAP=3; round=0
proof() { echo "$(git -C "$WT" rev-list --count HEAD)|$(git -C "$WT" status --porcelain | md5)"; }

while ! complete "$WT" && [ "$round" -lt "$CAP" ]; do
  before=$(proof)
  # dispatch ONE Continue-Incomplete agent into the EXISTING worktree (it already exists —
  # never create a new one). NO `isolation` parameter; pass $WT as the absolute working
  # directory inside the prompt body. (Agent tool — prompt in references/agent-prompts.md)
  after=$(proof)
  if [ "$before" = "$after" ]; then
    echo "🚫 STUCK — resume round made zero progress ($STORY)"; break   # the 0-tool-uses no-op
  fi
  round=$((round + 1))
done
```

- `complete` = the four-part check in Phase 3.5 (`Status: DONE` + no `[ ]` criteria + clean
  tree + QA green). Re-evaluate after the loop.
- Loop exited COMPLETE → re-run Phase 4 → 5, then treat as merge-eligible (manual testing
  happens post-merge in Phase 6.5).
- Loop exited STUCK → flag `🚫 STUCK`, keep worktree, never merge.
- Loop hit `CAP` while still progressing → story too large; stop and recommend splitting.

## Phase 7 — Worktree Cleanup (after merge)

```bash
git -C "$MAIN" worktree list
git -C "$MAIN" worktree remove -f "$MAIN/.claude/worktrees/agent-XX-YY"   # -f: dirty trees
git -C "$MAIN" worktree prune
git -C "$MAIN" worktree list                                             # only main should remain
```

Orchestrator-created worktrees are **not locked**, so a single `-f` (which forces past a
dirty tree) is enough. Use `-f -f` only to clear a locked leftover from an older run.

Print cleanup confirmation (format: `conflict-format.md`).
