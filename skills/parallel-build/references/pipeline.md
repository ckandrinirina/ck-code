# Pipeline Mechanics — Model Resolution, Integrity, Conflict, Merge, Cleanup

Bash-level procedures for Phases 3.0, 3.1, 3.5, 4, 6, and 7. SKILL.md holds the gates and
decisions; this file holds the exact commands.

## Phase 3.0 — Freeze the Merge Target (run before dispatch)

Resolve the target **once** and reuse it in every later phase. `$MAIN` = the main checkout
path.

```bash
TARGET=$(git -C "$MAIN" branch --show-current)        # empty → detached HEAD → STOP, ask
TARGET_SHA=$(git -C "$MAIN" rev-parse HEAD)
git -C "$MAIN" status --porcelain                      # must be clean before dispatch
```

Carry `$TARGET` / `$TARGET_SHA` into Phases 3.5, 4, and 6. **Never substitute a literal
`main`** — the operator may be on `docs`, a feature branch, or a wave target.

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

## Phase 3.5b — Normalize the Base onto $TARGET_SHA (per story branch)

Strip any divergent base so each branch contains only its own story commits:

```bash
MB=$(git -C "$MAIN" merge-base story/XX-YY "$TARGET_SHA")
if [ "$MB" != "$TARGET_SHA" ]; then
  # branch was cut from a divergent point — replay only the story's commits onto the target
  git -C "$MAIN" rebase --onto "$TARGET_SHA" "$MB" story/XX-YY
  # on conflict: git rebase --abort, flag the story 🚫 BLOCKED (manual rebase), keep worktree
fi
```

After this, `git diff $TARGET_SHA...story/XX-YY` is exactly the story's work and the Phase 6
merge cannot drag in foreign base commits.

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

**Code integrity (relative to `$TARGET_SHA`):**

```bash
git diff --stat "$TARGET_SHA"...story/XX-YY                        # empty → ⚠️ No implementation detected
git diff "$TARGET_SHA"...story/XX-YY --diff-filter=D --name-only   # any line → ⚠️ Unexpected file deletion
git diff "$TARGET_SHA"...story/XX-YY -- <file> | grep -c "^+"      # 0 additions with 1+ deletions
git diff "$TARGET_SHA"...story/XX-YY -- <file> | grep -c "^-"      #   → ⚠️ Possible code loss in <file>
```

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
# 4. QA green — Phase 5 commands for this story's epic/component
```

All four true → ✓ COMPLETE. Any false → not complete (keep looping / flag). This is the
only definition of "done"; the agent's final message is never used as proof.

**Gate:**

- ⚠️ warning (incomplete criteria, pure-deletion ratio) → proceeds to QA/merge; surface
  in the Phase 6 summary.
- 🚫 BLOCKED (status not updated, no implementation, unexpected deletion) → removed from
  the merge-eligible set; keep its worktree; report under "Review needed".

## Phase 4 — Conflict Analysis (per successful branch)

```bash
git branch --list "story/*"                            # 4.1 confirm branch names
# 4.2 dry-run merge each onto the frozen target (record CONFLICT lines):
git -C "$MAIN" checkout "$TARGET"
git -C "$MAIN" merge --no-commit --no-ff story/XX-YY 2>&1
git -C "$MAIN" merge --abort 2>/dev/null || true
# 4.3 cross-branch overlap (a file in 2+ branches is a potential cross-branch conflict):
git -C "$MAIN" diff --name-only "$TARGET_SHA"...story/XX-YY
```

Report (format: `conflict-format.md`): per-branch dry-run, cross-branch overlaps,
suggested merge order (fewest overlaps first). No conflicts → "No conflicts detected —
all branches merge cleanly."

## Phase 6 Option 1 — Merge Procedure

Merge target = **orchestrator's current branch**, never hardcoded `main`:

```bash
target_branch=$(git -C <main-checkout> branch --show-current)
```

Print the resolved target and confirm. Empty (detached HEAD) → stop, ask the user to
check out a real branch first. Then merge each merge-eligible branch in suggested order:

```bash
git -C <main-checkout> checkout "$target_branch"
git -C <main-checkout> merge --no-ff story/XX-YY -m "feat: implement story XX-YY"
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
`chore: reconcile story/feature indexes after parallel merge`). Run final QA on the merged
target (types + tests) to catch cross-branch integration issues before Phase 7.

## Phase 6 Option 3 — Auto-Continue Loop (per ◐ incomplete story)

Loop until the ✓ COMPLETE gate (Phase 3.5) passes, with a work-proof guard so a no-op round
can never masquerade as success:

```bash
WT=<worktree path>; STORY=story/XX-YY; CAP=3; round=0
proof() { echo "$(git -C "$WT" rev-list --count HEAD)|$(git -C "$WT" status --porcelain | md5)"; }

while ! complete "$WT" && [ "$round" -lt "$CAP" ]; do
  before=$(proof)
  # dispatch ONE Continue-Incomplete agent: isolation:none, cwd:$WT, in-worktree story path
  #   (Agent tool — prompt in references/agent-prompts.md)
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
git worktree list
git worktree remove -f -f /path/to/.claude/worktrees/agent-XXXXXXXX   # double-force: locked by default
git worktree prune
git worktree list                                                     # only main should remain
```

Print cleanup confirmation (format: `conflict-format.md`).
