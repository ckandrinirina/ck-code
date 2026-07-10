# Orchestrator Context Budget — What Runs Inline vs. What Delegates

The parallel-build orchestrator is the **longest-lived and most expensive context in the
run**: it survives every phase, every wave, and every merge. Anything it reads or executes
is paid for once at load and then **re-paid on every subsequent turn** for the rest of the
run. A sub-agent's context, by contrast, is discarded the moment it returns — only its
final block survives.

This asymmetry is the whole design. The orchestrator's job is to **decide and route**, not
to read, build, or test. When in doubt, delegate: a wasted sub-agent costs one cheap
context; a wasted orchestrator read costs every turn that follows it.

## The Rule

> The orchestrator may run commands whose output is **bounded and small** (counts, names,
> statuses, SHAs). It may never run a command whose output scales with the size of the
> codebase, the diff, or the test suite.

## Delegation Table

| Work | Where it runs | Why |
| --- | --- | --- |
| Implementing a story (any N, including N=1) | worktree agent, Phase 3.3 | TDD cycles, file reads and test output would otherwise land in the orchestrator |
| Continuing an ◐ incomplete story | agent in the existing worktree, Phase 6 Option 3 | same, plus the partial work is already there |
| Per-story QA (build / test / lint) | `ck-code:qa-validator` (Haiku), Phase 5.2 | verbose suite output, absorbed by a cheap throwaway context |
| **Post-merge QA on `$TARGET`** | `ck-code:qa-validator` (Haiku), Phase 6 | same output, same reason — the merge does not make it cheap |
| Conflict analysis | `ck-code:conflict-analyzer`, Phase 4 | dry-run merges print conflict hunks |
| Post-merge bug fixes | agent in the main checkout, Phase 6.5.3 | a fix is a build; builds never run inline |
| Story selection from the index | **inline** | one table read, bounded |
| File-scope overlap (Phase 1.4) | **inline, paths only** | see Cheap Commands below |
| Integrity gates (Phase 3.5) | **inline, counts only** | see Cheap Commands below |
| Index reconciliation after merge | **inline** | the orchestrator is the sole writer; three small Edits |
| Manual-test gate (Phase 6.5) | **inline** | requires the user; sub-agents cannot prompt |

## Cheap Commands (bounded output — safe inline)

```bash
# file scope for overlap detection — paths only, never the table's description column
awk '/^## Files to Create\/Modify/{p=1;next} /^## /{p=0} p' "$f" \
  | grep -oE '`[^`]+`' | tr -d '`' | grep '/' | sort -u

# acceptance criteria only — never a full Read of the story body
awk '/^## Acceptance Criteria/{p=1;next} /^## /{p=0} p' "$f"

# integrity — counts and names, never diff bodies
git diff --shortstat "$TARGET_SHA"...story/XX-YY
git diff --name-status "$TARGET_SHA"...story/XX-YY
git diff --numstat "$TARGET_SHA"...story/XX-YY -- <file>   # "added<TAB>deleted<TAB>path"
git -C "$WT" rev-list --count HEAD
git -C "$WT" status --porcelain
```

## Forbidden Inline (unbounded output — always delegate or redirect)

```bash
cargo test              pnpm test            pytest            go test ./...
cargo clippy            eslint .             tsc --noEmit      cmake --build
git diff <sha>...<br>                        # diff BODY — use --numstat / --name-status
git merge --no-commit --no-ff story/XX-YY    # prints conflict hunks — Phase 4 agent
Read(<story file>)                           # full body — extract the one section instead
Read(<source file>)                          # the orchestrator never reads implementation code
```

## Why N=1 Still Uses a Worktree

Inlining a single-story build looks like a saving — one fewer worktree, one fewer agent —
but it inverts the cost. The build's entire transcript (every TDD red/green cycle, every
source file it read, every test run) is loaded into the orchestrator and then carried
through Phase 4, 5, 6, 6.5 and 7, and in wave mode through every remaining wave. Dispatching
it costs one worktree create/remove and returns four lines.

The orchestrator's own decision loop is the same whether N is 1 or 8. Keep it that way.
