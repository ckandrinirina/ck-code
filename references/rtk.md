# RTK — token-optimized command output

[RTK](https://github.com/ckandrinirina/rtk) ("Rust Token Killer") is a CLI proxy that
filters and summarizes command output *before* it reaches the model's context. A full
test suite that would cost thousands of tokens returns as the failing cases alone.

It is **optional** and **user-installed**. ck-code never requires it, never installs it,
and every command in every skill runs correctly without it. What ck-code does is emit
command forms RTK can recognize, so a user who has it gets the savings for free.

## Install

```bash
cargo install rtk-cli     # or: brew install ckandrinirina/tap/rtk
rtk init                  # registers the PreToolUse hook in ~/.claude/settings.json
```

`rtk init` writes a `PreToolUse` hook on the `Bash` matcher:

```json
{ "type": "command", "command": "rtk hook claude" }
```

Verify it took: `rtk --version`, then `rtk gain` (savings so far). If `rtk gain` errors,
a different tool named `rtk` (reachingforthejack/rtk, "Rust Type Kit") is shadowing it on
`PATH`.

## How the integration actually works

The hook rewrites the command **transparently, on the way to the shell**. Claude writes
`git status`; the hook runs `rtk git status`; the model sees the compact output. Nothing
in a skill has to know.

This has one hard consequence:

> **Never write `rtk` into a skill, agent, or reference command.**

A hardcoded `rtk` breaks every user who has not installed it — the command becomes
`rtk: command not found`. The hook is the only correct integration point. What a skill
*can* do is choose the phrasing of a plain command so the hook recognizes it.

## What the hook rewrites — and the one trap

Measured with `rtk hook check "<command>"` (a dry run that prints the rewrite):

| Written by a skill | Hook result |
|---|---|
| `git status`, `git diff`, `git log`, `git commit`, `git show`, `git add`, `git worktree list` | ✅ `rtk git …` |
| `gh pr …`, `gh issue …`, `gh run …` | ✅ `rtk gh …` |
| `npm run test`, `npm run build`, `npm run lint`, `pnpm run test`, `npm run test:unit` | ✅ `rtk test` / `rtk lint` / `rtk npm run …` |
| `cargo test`, `cargo clippy`, `pytest`, `go test ./...`, `go vet ./...`, `ctest`, `ruff check .` | ✅ |
| `npx tsc --noEmit`, `npx eslint .`, `npx jest`, `npx vitest run`, `npx playwright test` | ✅ `rtk tsc` / `rtk lint` / `rtk jest` / … |
| `bundle exec rspec`, `vendor/bin/phpunit`, `bun test` | ✅ |
| **`npm test`, `pnpm test`** | ❌ **no rewrite** |
| `yarn test`, `yarn run test` | ❌ no yarn filter exists in RTK |
| `python -m unittest discover` | ❌ |
| `npm run test \| tail -20`, `cargo test \| head` (piped) | ❌ the command feeding a pipe is left alone |

### The `npm test` trap

`npm test` is a plain alias for `npm run test` — **identical behaviour, identical exit
code** — but only the second form is rewritten. Since the test suite is the single
largest output ck-code ever puts in context, the long form is always the one to write.

The same holds for `pnpm test` → `pnpm run test`. `yarn` has no filter at all, so a yarn
project simply gets no test savings; that is RTK's gap, not something a command form fixes.

### Never pipe a stack command

A command that feeds a pipe is **not** rewritten: `cargo test | head` and
`npm run test 2>&1 | tail -20` both run unfiltered. Only later segments of the pipeline
are matched — in `git status | grep M` the `grep` is rewritten and the `git status` is not.

This is a double loss: the pipe defeats RTK's filter *and* duplicates the job RTK already
does better, since `rtk test` returns failures only. Run the bare command.

`&&` chains are fine. The hook rewrites every independently matchable segment, so
`cd sub && cargo test` becomes `cd sub && rtk cargo test` and `git add -A && git commit -m x`
rewrites on both sides. Running a stack command in a subdirectory costs nothing.

## Where ck-code gains the most

| Phase | Command | Why it matters |
|---|---|---|
| `build` Phase 4/6 — the TDD loop | the project's `test` command | run on every RED and GREEN cycle; `rtk test` returns failures only |
| `build` Phase 7 / `ck-code:qa-validator` | full suite + lint + typecheck | the biggest single output in the workflow, and it repeats per QA iteration (cap 3) |
| `build` PARALLEL MODE | per-worktree suites | multiplied by the number of stories in the wave |
| `ship`, `sync` | `git`, `gh` | many small calls whose boilerplate dominates their signal |
| `fix` Phase 4 | reproduction test runs | tight loop, repeated until the bug reproduces |

`qa-validator` already absorbs suite output in a throwaway context and returns only a
verdict — RTK shrinks what that agent pays *inside* its own context, so the two compose
rather than overlap.

## Checking it is working

```bash
rtk gain                  # tokens saved, cumulative
rtk gain --history        # per-command breakdown
rtk hook check "npm test" # dry-run one command's rewrite
rtk discover              # scan Claude Code history for missed opportunities
```

`/ck-code:doctor` reports whether `rtk` is on `PATH` and whether the hook is registered.
Never an ERROR, and *absence is not even a WARN* — a project without RTK is perfectly
healthy, just chattier. The row only warns when RTK is installed with no hook wired (paid
for, doing nothing), or when a different tool named `rtk` shadows it on `PATH`.

## Rules

- **Never write `rtk` into a skill, agent, or reference command** — the hook does the
  rewriting, and a hardcoded prefix breaks every user without RTK installed.
- **Always write `npm run test` / `pnpm run test`, never `npm test` / `pnpm test`** —
  same behaviour, and only the long form is filtered.
- **Never pipe a stack command** (`cargo test | head`, `npm run test | tail`) — the piped
  command is left unfiltered, and RTK already returns failures only. `&&` chains are fine.
- **Never make RTK a prerequisite** — no skill may block, warn inline, or change behaviour
  because RTK is absent. `doctor` is the only place its absence is mentioned.
