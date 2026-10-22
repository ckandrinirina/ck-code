# QA Scope — commands, scope and re-runs

Which commands a QA pass runs, at which scope (story or area, resolved by `ck-affected`), and
how a failed check is re-run. Read by the
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
| `CMakeLists.txt` | `cmake --build build --config Release`, then verify the artifact (C++/JUCE build-log and `clang-format` rules: [tdd-walkthrough.md](tdd-walkthrough.md#juce-test-runner-rules)); with registered tests, `ctest --test-dir build --output-on-failure -j "${CK_QA_JOBS:-4}"` ([§ Parallel ctest](#parallel-ctest)) |

A project's `guide-conventions` skill overrides this table when it names canonical commands.
No manifest match → ask once and reuse.

### Parallel ctest

`ctest` runs one test at a time unless given `-j`, and a Catch2 or GoogleTest suite registers
hundreds of small tests: measured on a 590-test suite, 82 s serial against 10 s with `-j 8`,
same result. `CK_QA_JOBS` is the run's share of the cores, set by `ck-qa`. Once per project,
when `docs/architecture/dev-guide.md` `## Testing` names no `ctest` line yet, run the suite once
with `-j` and once without: record the `-j` command there only when both pass, otherwise the
serial one with the reason (tests sharing a file, port or directory). Later stories use the
recorded line. Never weaken a test to make it parallel.

## Affected tests — the story-level test command

Every QA pass runs at one of two scopes. **Story scope** checks only what the story's diff
can affect. **Area scope** runs every test of each area the diff reaches and is the backstop
that catches a regression outside the story's reach, so every story-scope pass has an
area-scope run after it. An area nothing reaches never runs: a backoffice change never runs
the client's suite.

| Run | Scope | `<base>` |
| --- | --- | --- |
| delegated 6.3 + 7, P7 | story | the dispatch's `Base SHA` |
| single-story S5 QA (or inline-fallback 6.3 / 7), level `epic` or `plan` | story, except on the story that completes its epic | the S3 SHA (inline fallback: `git merge-base HEAD <the 3.5 base branch>`) |
| single-story S5 QA on the story that completes its epic (every other non-`skip` story of the epic reads `status: done`) | area, the single-story counterpart of P8 | `git merge-base HEAD <the branch the epic merges into>` — the whole epic's diff |
| single-story S5 QA, level `story` (or empty) | area — each story's PR goes straight to `<trunk>`, and nothing runs after it | the S3 SHA |
| P8 post-wave QA | area, always | the wave's `Base SHA` — `$TARGET` before its merges |

### `ck-affected` — the scope, computed by script

`ck-affected <base>` (story) or `ck-affected <base> --area` resolves the scope with `git`
and `grep` alone. Never trace imports by reading files: the script prints a few lines
whatever the repo's size. Its first line decides:

| First line | Tests at that scope |
| --- | --- |
| `ck-affected: FULL — <reason>` | the full rows of [§ Per-stack commands](#per-stack-commands) — a change no area owns: repo-root config or manifest, a lockfile alone, migrations, schema, seeds, fixtures, env files |
| `ck-affected: NONE — …` | none: drop the `test=` label (lint, typecheck and build still run) |
| `ck-affected: AREA …` | `run` lines name the areas reached, `skip` lines the rest |

An **area** is a workspace package (the nearest manifest above a file) or a name declared in
`.ck-test-areas` at the repo root — `backoffice: src/admin/* e2e/admin/*`, one area a line,
first match wins. Declare areas when one package holds several (a backoffice and a client in
one app) or when e2e specs reach the code over HTTP rather than imports: the script cannot
trace those, and the file ties them to their area. Suggest it when an area-scope run is
still the whole package. A story never writes `.ck-test-areas` unasked; editing it is FULL.

**Story scope traces imports, transitively.** The tests that import a changed file, then the
tests of every file importing those — the service's test, then the controller that uses
the service and its test, up the chain. JS/TS and Python imports resolve to the file
(relative paths, `@/` aliases, workspace package names, dotted and relative modules). Ruby,
PHP and Go match by name, and Go adds a package's own tests. An area `ck-affected` marks
`all` (its own manifest or test config changed, a Rust/C++/JVM file, a trace over 2000
files) runs whole.

**Area scope** runs every test of each reached area, plus each workspace package whose
manifest depends on a reached one.

### The commands

Run the test command **from each component directory** of the story, as for
[§ Per-stack commands](#per-stack-commands). `--command` lists only the tests under the
current directory, so a component the scope never reaches gets `: no affected tests` and
costs nothing:

| Scope | `test=` |
| --- | --- |
| story, vitest | `npx vitest run --changed <base> --passWithNoTests` |
| story, jest | `npx jest --changedSince <base> --passWithNoTests` |
| story, Playwright e2e | `npx playwright test --only-changed=<base> --pass-with-no-tests` |
| story, any other runner | `"$(ck-affected <base> --command '<full row>' '<row narrowed>')"` |
| area, every runner | `"$(ck-affected <base> --area --command '<full row>' '<row narrowed>')"` |

The **narrowed row** is the full test row with the files spliced in: `{files}` is the test
files, `{dirs}` their folders — `pytest {files}`, `npx vitest run {files}`,
`npx playwright test {files}`, `bundle exec rspec {files}`, `vendor/bin/phpunit {files}`,
`go test {dirs}`. The script prints the full row itself on FULL, for an `all` area whose
tests live inside the source (cargo, CMake), and past 800 files. `"$(…)"` runs at the call,
so `ck-qa` stamps the resolved command, and the validator's identical expression on the same
tree resolves to the same string and reports `REUSED`. The vitest, jest and Playwright story
commands use the runner's own module graph, which a `ck-affected` story list matches; keep
them. When the summary marks a component `skip`, drop its `test=` label instead.

Run the command through the package's own runner when the suite needs its script's env
(`pnpm --filter web exec vitest run --changed <base> --passWithNoTests`). A project whose
test script adds setup, such as a test database or a `.env.test`, keeps that setup and only
appends the flag or the files. An e2e suite that runs through a wrapper script appends them
to the script.

**Lint at story scope** checks only the changed files, by path, because a linter judges each
file on its own: `npx eslint <files>`, `npx prettier --check --ignore-unknown <files>`,
`ruff check <files>`, `black --check <files>`. Keep only the extensions the tool handles, and
leave out a label whose file list is empty. `cargo clippy`, `cargo fmt --check` and
`go vet` stay whole-crate and whole-package. A lint rule that reads other files (type-aware
or import-cycle rules) can still fire on an unchanged file. **Lint at area scope** is the
full lint row of each reached component, and catches that. **Typecheck and build are never
scoped.** A fresh typecheck and build of the committed branch is what catches a file the
agent forgot to `git add`.

**Read the summary first**, once per pass: `ck-affected <base>` (story) or
`ck-affected <base> --area`. FULL → the full rows. A component marked `all` → the `--command`
form, even for vitest, jest and Playwright, whose `--changed` cannot see a config change. A
component marked `skip` → no `test=` label. Never narrow P8 below area scope.

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
| any other runner (a `ck-affected` label) | `"<row narrowed to the failed files> && $(ck-affected <snap> --command ':' '<row narrowed>')"` |

`--rerun` makes `ck-qa` stamp the label's **recorded** full command when the narrowed run
passes. A later `--reuse` of that command, such as the single-story QA after the agent's run, then reports
`REUSED` ([`rtk.md` § QA runs go through `ck-qa`](../../../references/rtk.md#qa-runs-go-through-ck-qa)).
Drop the failed-files half when the last run passed. Re-run the full command, without
`--rerun`, when any of these holds:

- `ck-affected <snap>` prints FULL or marks the component `all`,
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
