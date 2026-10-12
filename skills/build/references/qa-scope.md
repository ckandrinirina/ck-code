# QA Scope — commands, scope and re-runs

Which commands a QA pass runs, at which scope, and how a failed check is re-run. Read by the
builder ([story-cycle.md](story-cycle.md) 6.3 and 7), by every `qa-validator` dispatch
([agent-prompts.md](agent-prompts.md)), and by the orchestrator at S5, P7 and P8
([parallel-mode.md](parallel-mode.md)).

## Per-stack commands

Resolve each story's commands from the component its `files:` touch — detect the stack from
that directory's manifest. **This table is the one per-stack QA command list in ck-code** —
single-story QA uses it too:

| Manifest | QA commands |
| --- | --- |
| `Cargo.toml` | `cargo test && cargo clippy -- -D warnings && cargo fmt --check` |
| `package.json` | the declared `test`, `lint`, and typecheck scripts — typically `npm run test`, `npx eslint .`, `npx tsc --noEmit`, `npx prettier --check .` |
| `pyproject.toml` | `pytest`, plus the declared lint/format/type checks — typically `ruff check .`, `black --check .`, `mypy .` |
| `go.mod` | `go test ./... && go vet ./...` |
| `CMakeLists.txt` | `cmake --build build --config Release`, then verify the artifact (C++/JUCE build-log and `clang-format` rules: [tdd-walkthrough.md](tdd-walkthrough.md#juce-test-runner-rules)) |

A project's `guide-conventions` skill overrides this table when it names canonical commands.
No manifest match → ask once and reuse.

## Affected tests — the story-level test command

Every QA pass runs at one of two scopes. **Story scope** checks only what the story's diff
can affect. **Full scope** runs the full rows above and is the backstop that catches a
regression outside the story's reach, so every story-scope pass has a full-scope run after it.

| Run | Scope |
| --- | --- |
| delegated 6.3 + 7, P7 | story |
| single-story S5 QA (or inline-fallback 6.3 / 7), level `epic` or `plan` | story, except on the story that completes its epic |
| single-story S5 QA on the story that completes its epic (every other non-`skip` story of the epic reads `status: done`) | full, the single-story counterpart of P8 |
| single-story S5 QA, level `story` (or empty) | full — each story's PR goes straight to `<trunk>`, and nothing runs after it |
| P8 post-wave QA | full, always |

`<base>` is the dispatch's `Base SHA` (PARALLEL MODE, and the S3 SHA of a single-story
dispatch); in the inline fallback it is `git merge-base HEAD <the 3.5 base branch>`. The changed files are
`git diff --name-only --diff-filter=d <base>` plus `git ls-files --others --exclude-standard`.

**Tests at story scope** are those importing a changed file, plus the story's own new or
changed test files, e2e specs included:

| Runner | Affected-tests command (the `test=` label) |
| --- | --- |
| vitest | `npx vitest run --changed <base> --passWithNoTests` |
| jest | `npx jest --changedSince <base> --passWithNoTests` |
| Playwright e2e | `npx playwright test --only-changed=<base> --pass-with-no-tests` |
| go | `go test` on the touched packages (`go test ./internal/auth/... ./internal/api/...`) |
| anything else (pytest, cargo, CMake, a custom runner) | the full test row above, unchanged |

Run the command through the package's own runner when the suite needs its script's env
(`pnpm --filter web exec vitest run --changed <base> --passWithNoTests`). A project whose
test script adds setup, such as a test database or a `.env.test`, keeps that setup and only
appends the flag. An e2e suite that runs through a wrapper script appends the flag to the
script.

**Lint at story scope** checks only the changed files, by path, because a linter judges each
file on its own: `npx eslint <files>`, `npx prettier --check --ignore-unknown <files>`,
`ruff check <files>`, `black --check <files>`. Keep only the extensions the tool handles, and
leave out a label whose file list is empty. `cargo clippy`, `cargo fmt --check` and
`go vet` stay whole-crate and whole-package. A lint rule that reads other files (type-aware
or import-cycle rules) can still fire on an unchanged file. The full-scope run after it
catches that. **Typecheck and build are never scoped.** A fresh typecheck and build of the
committed branch is what catches a file the agent forgot to `git add`.

**Fall back to full scope** when the diff touches anything a per-file or import-graph check
cannot trace. That covers test or runner config (`vitest.config.*`, `jest.config.*`,
`playwright.config.*`, `tsconfig*.json`), lint or format config (`eslint.config.*`,
`.eslintrc*`, `.prettierrc*`, `ruff.toml`), `package.json`, `pyproject.toml` or a lockfile,
env files, DB migrations or schema, global test setup, and shared fixtures or seed data.
Never scope P8.

## Re-runs after a failure — only what is left

A check re-run on the same `ck-qa` id and label after its last run (a red 6.3, a failed
delegated run, or a NEEDS FIXES round) never repeats the whole scope. A test that passed on
the last run, and imports nothing changed since, cannot have changed its result. The re-run
therefore checks only:

- the test files that failed, read from the last run's log, **plus**
- the tests affected since that run's snapshot, `<snap>` = `ck-qa since <id> test`.

| Runner | Re-run command, passed with `ck-qa run <id> --rerun` |
| --- | --- |
| vitest | `npx vitest run <failed files> && npx vitest run --changed <snap> --passWithNoTests` |
| jest | `npx jest <failed files> && npx jest --changedSince <snap> --passWithNoTests` |
| Playwright e2e | `npx playwright test <failed specs> && npx playwright test --only-changed=<snap> --pass-with-no-tests` |
| go | `go test` on the failed packages plus the packages touched since `<snap>` |
| story-scope lint | the same lint command on the files that failed plus those changed since `<snap>` |
| anything else | the label's full command again, without `--rerun` |

`--rerun` makes `ck-qa` stamp the label's **recorded** full command when the narrowed run
passes. A later `--reuse` of that command, such as the single-story QA after the agent's run, then reports
`REUSED` ([`rtk.md` § QA runs go through `ck-qa`](../../../references/rtk.md#qa-runs-go-through-ck-qa)).
Drop the failed-files half when the last run passed. Re-run the full command, without
`--rerun`, when any of these holds:

- the change since `<snap>` hits a full-scope fallback above,
- the last run crashed before it reported per-test results (a setup error, a syntax error,
  a missing module),
- `ck-qa since` finds no recorded run.

Typecheck and build always re-run in full. P7 and P8 are never re-runs: each is a fresh
check of a tree nobody has run it on.

## How the commands run

Every QA pass hands them to `ck-qa run <id> …`, one
`<label>='<command>'` per independent command
([`rtk.md` § QA runs go through `ck-qa`](../../../references/rtk.md#qa-runs-go-through-ck-qa)).
Add `--parallel` when there are two or more labels, as with the `package.json` and
`pyproject.toml` rows: test, lint and typecheck then run concurrently, and one pass reports
every failing command instead of costing one QA iteration per failure. A row written as an
`&&` chain (`Cargo.toml`, `go.mod`, `CMakeLists.txt`) shares one build lock or tree, so it
stays **one label** and runs in order.
