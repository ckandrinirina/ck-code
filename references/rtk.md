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

## Slow commands — run once, read the log

A pipe is also how agents lose output they later need. `npm run test | tail -40` hides the
first failure, so the agent runs the whole suite again with `| grep FAIL`, then again with
`| grep -A 5`. Across 83 measured `build` and `qa-validator` runs, **about 20% of suite runs
repeated the identical command on an unchanged tree**. One QA pass ran jest six times and a
five-minute e2e suite twice.

The full suite, lint, typecheck, build, and e2e commands therefore run **once per code
state**, redirected to a log outside the repo, in a single Bash call:

```bash
npm run test > "${TMPDIR:-/tmp}/ck-02-05-test.log" 2>&1; echo "exit=$?"; tail -n 60 "${TMPDIR:-/tmp}/ck-02-05-test.log"
```

- **Exit 0** — the command passed, and the tail is all you need.
- **Non-zero** — the tail usually names the failure. When it does not, `grep -n` or `sed -n`
  **the log** (for example `grep -n -E 'FAIL|✕|error' <log>`) as often as you need. Never
  re-run the command to see a different slice of output it already produced.
- **Re-run only after the code changed**, or narrowed to the one failing test file.

Name the log `ck-<story id>-<command>.log`. It stays under `$TMPDIR` and never goes in the
working tree: a log in the tree dirties it, which fails P5's clean-tree check and breaks a
read-only QA agent's contract.

This is RTK-compatible, checked with `rtk hook check`: a redirect is not a pipe, so
`npm run test > log` becomes `rtk npm run test > log` and the log holds the filtered output,
while `tail -n 60 <log>` becomes `rtk read <log> --tail-lines 60`. A fast targeted run of the
story's own test files may run bare. The rule is for the commands that cost minutes.

### QA runs go through `ck-qa`

The full-suite check (`build` 6.3) and every QA pass (Phase 7, P7, P8) run their commands
through `ck-qa`, which applies this rule mechanically and extends it **across** agents:

```bash
ck-qa run 02-05 --parallel test='npm run test' lint='npx eslint .' types='npx tsc --noEmit'
```

- It writes the same `ck-<id>-<label>.log` files, prints one line per command plus the last
  40 lines of each failure, and ends with `ck-qa: PASS` or `ck-qa: FAIL — <labels>`. Read
  more of a failure from its log. Those logs are not RTK-filtered, because the commands run
  inside the script, and the 40-line tail is the cap instead.
- Each pass is stamped with its **code state**, meaning the git tree of the working copy
  (untracked files included), plus the directory and the exact command. With `--reuse`, a
  command that already passed on that exact triple reports `REUSED` and does not run. Only
  the QA steps named in `build` pass `--reuse`, and P7 never does.
- `--parallel` runs independent commands concurrently and reports every failure in one
  pass. Never pass it for commands that share a build lock or output directory (cargo's
  `target/`, one CMake build tree). Those stay one chained `label='a && b'` command.
- A command that edits the tree (a formatter, a snapshot update) prints a `WARN` and is never
  stamped. Fix the command rather than trusting that pass.

## Where ck-code gains the most

| Phase | Command | Why it matters |
|---|---|---|
| `build` Phase 4/6 — the TDD loop | the project's `test` command | run on every RED and GREEN cycle; `rtk test` returns failures only |
| `build` Phase 7 / `ck-code:qa-validator` | full suite + lint + typecheck | the biggest single output in the workflow, and it repeats per QA iteration (cap 3). `ck-qa` keeps it out of RTK's reach, so its tail cap is what bounds it |
| `build` PARALLEL MODE | per-worktree suites | multiplied by the number of stories in the wave |
| `ship`, `doctor --fix` | `git`, `gh` | many small calls whose boilerplate dominates their signal |
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
- **Never re-run a slow command on an unchanged tree** — capture it once to a `$TMPDIR` log
  and read slices of the log ([§ Slow commands](#slow-commands--run-once-read-the-log)). QA
  commands go through `ck-qa`, which enforces this across agents too.
- **Never make RTK a prerequisite** — no skill may block, warn inline, or change behaviour
  because RTK is absent. `doctor` is the only place its absence is mentioned.
