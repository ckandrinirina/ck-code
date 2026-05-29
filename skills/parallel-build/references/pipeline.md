# Pipeline Mechanics — Model Resolution, Integrity, Conflict, Merge, Cleanup

Bash-level procedures for Phases 3.1, 3.5, 4, 6, and 7. SKILL.md holds the gates and
decisions; this file holds the exact commands.

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

## Phase 3.5 — Integrity Checks

Run per **successfully completed** story, before conflict analysis.

**Status check (worktree-based):** read the story file from `<worktree-path>/<rel-path>`
and confirm `Status: DONE`. Do NOT read `STORIES_INDEX.md` from the main checkout — it is
pre-implementation until merge. If the worktree story file still shows TODO/IN PROGRESS →
⚠️ **Story file not updated** (build failed to complete Phase 8); also check
`<worktree-path>/tasks/<slug>/STORIES_INDEX.md` for index/story sync (mutation protocol:
`../../../references/stories-index.md`). Acceptance-criteria checkboxes are validated by
build's QA phase, not here.

**Code integrity (relative to `main`):**

```bash
git diff --stat main...story/XX-YY                        # empty → ⚠️ No implementation detected
git diff main...story/XX-YY --diff-filter=D --name-only   # any line → ⚠️ Unexpected file deletion
git diff main...story/XX-YY -- <file> | grep -c "^+"      # 0 additions with 1+ deletions
git diff main...story/XX-YY -- <file> | grep -c "^-"      #   → ⚠️ Possible code loss in <file>
```

A deletion is acceptable only if a new file clearly supersedes the removed one; otherwise
treat it as potential code loss.

**Gate:**

- ⚠️ warning (incomplete criteria, pure-deletion ratio) → proceeds to QA/merge; surface
  in the Phase 6 summary.
- 🚫 BLOCKED (status not updated, no implementation, unexpected deletion) → removed from
  the merge-eligible set; keep its worktree; report under "Review needed".

## Phase 4 — Conflict Analysis (per successful branch)

```bash
git branch --list "story/*"                       # 4.1 confirm branch names
# 4.2 dry-run merge each onto main (record CONFLICT lines):
git checkout main
git merge --no-commit --no-ff story/XX-YY 2>&1
git merge --abort 2>/dev/null || true
# 4.3 cross-branch overlap (a file in 2+ branches is a potential cross-branch conflict):
git diff --name-only main...story/XX-YY
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

Run final QA on the merged target (types + tests) to catch cross-branch integration
issues before Phase 7.

## Phase 7 — Worktree Cleanup (after merge)

```bash
git worktree list
git worktree remove -f -f /path/to/.claude/worktrees/agent-XXXXXXXX   # double-force: locked by default
git worktree prune
git worktree list                                                     # only main should remain
```

Print cleanup confirmation (format: `conflict-format.md`).
