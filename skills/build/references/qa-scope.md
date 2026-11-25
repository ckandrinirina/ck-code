# QA Scope — the commands and the scope of the background run

Which commands the background run of a story or wave runs ([qa-lane.md](../../../references/qa-lane.md)),
and at which scope (story or area, resolved by `ck-affected`). Read by the orchestrator at S5 and
P8, and by the builder for the rows of its own check.

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
| `CMakeLists.txt` | `cmake --build build --config Release`, then verify the artifact (C++/JUCE build-log and `clang-format` rules: [tdd-walkthrough.md](tdd-walkthrough.md#juce-test-runner-rules)); with registered tests, `ctest --test-dir build --output-on-failure -j "${CK_QA_JOBS:-4}"` ([§ Parallel ctest](#parallel-ctest)); story scope on Catch2 v3 runs each test binary once, filtered by file ([§ Catch2](#catch2--one-process-per-binary)) |

A project's `guide-conventions` skill overrides this table when it names canonical commands.
No manifest match → ask once and reuse.

**Heavy suites are never QA.** A database, container or e2e suite declared in
`.ck-heavy-tests` has no row here at any scope, FULL included: `ck-affected` drops its files,
and `ship` runs it once per PR ([heavy-tests.md](../../../references/heavy-tests.md)).

### Parallel ctest

`ctest` runs one test at a time unless given `-j`, and a Catch2 or GoogleTest suite registers
hundreds of small tests: measured on a 590-test suite, 82 s serial against 10 s with `-j 8`,
same result. `CK_QA_JOBS` is the run's share of the cores, set by `ck-qa`. Once per project,
when `docs/architecture/dev-guide.md` `## Testing` names no `ctest` line yet, **or names one
with neither `-j` nor `--parallel` and no recorded serial reason** (a line written before this
rule — measured at 2,745 cases and 13–21 min a run, every run), run the suite once with `-j`:
`PASS` → record the `-j` line; `FAIL` → run it once serially, and record the serial line with
the reason (tests sharing a file, port or directory) only when the serial run passes. Later
stories use the recorded line. Never weaken a test to make it parallel.

### Catch2 — one process per binary

`catch_discover_tests` registers every `TEST_CASE` as its own ctest test, so ctest starts the
binary once per case: the median case took 0.13 s, nearly all of it process start. Story
scope skips ctest. It builds the test targets, then runs **each test binary once** with
Catch2's file-name tags, which select the cases of the affected test files only — measured
at 0.2 s for two files against 13 min for the suite:

```
<the test row's configure and build> && for t in <the test binaries>; do if ! "$t" -# {tags} --allow-running-no-tests; then exit 1; fi; done
```

`{tags}` is `ck-affected`'s filter (`'[#ClipTests],[#TrackTests]'`, one tag per test file,
its name without the extension). A binary holding none of those files runs nothing and passes.
Record this line once per project in `dev-guide.md` `## Testing` beside the `ctest` one,
naming the binaries by the build folder's glob (`build/tests/tests/*_tests`). Catch2 v2 has
no `--allow-running-no-tests`, GoogleTest has no file tags: both keep the `ctest -j` row at
every scope. Area scope and P8 always run the `ctest -j` row: one process per case is what
catches a case that passes only because another ran before it in the same process.

## Affected tests — the story-level test command

Every background run has one of two scopes. **Story scope** checks only what the story's diff
can affect. **Area scope** runs every test of each area the diff reaches and is the backstop
that catches a regression outside the story's reach, so every story-scope run has an
area-scope run after it. An area nothing reaches never runs: a backoffice change never runs
the client's suite.

| Background run | Scope | `--base` |
| --- | --- | --- |
| single story, level `epic` or `plan` | story, except on the story that completes its epic | the S3 SHA |
| single story that completes its epic (every other non-`skip` story of the epic reads `status: done`) | area | `git merge-base HEAD <the branch the epic merges into>` — the whole epic's diff |
| single story, level `story` (or empty) | area — its PR goes straight to `<trunk>`, and nothing runs after it | the S3 SHA |
| a wave (P8), fan-out or solo | area, always | the wave's `Base SHA` — `$TARGET` before its merges |

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
PHP and Go match by name, and Go adds a package's own tests. C/C++ follows `#include`: a
changed `Foo.cpp` or `Foo.h` reaches every file that includes a `Foo` header, then their
includers; a test file is `*Tests.cpp`, `*_test.cc`, `test_*.c` or any source under `tests/`.
A nested `CMakeLists.txt` is traced through its code; the root one and `*.cmake` are FULL. An
area `ck-affected` marks `all` (its own manifest or test config changed, a Rust/JVM file, a
trace over 2000 files) runs whole.

**Area scope** runs every test of each reached area, plus each workspace package whose
manifest depends on a reached one.

### The commands

Run the test command **from each component directory** of the story, as for
[§ Per-stack commands](#per-stack-commands). `--command` lists only the tests under the
current directory, so a component the scope never reaches gets `: no affected tests` and
costs nothing:

| Scope | `test=` |
| --- | --- |
| story, every runner | `"@ck-affected {base} --command '<full row>' '<row narrowed>'"` |
| area, every runner | `"@ck-affected {base} --area --command '<full row>' '<row narrowed>'"` |

The **narrowed row** is the full test row with the files spliced in: `{files}` is the test
files, `{dirs}` their folders, `{tags}` their Catch2 file tags — `pytest {files}`,
`npx vitest run {files}`, `npx playwright test {files}`, `bundle exec rspec {files}`,
`vendor/bin/phpunit {files}`, `go test {dirs}`, the [§ Catch2](#catch2--one-process-per-binary)
line. The script prints the full row itself on FULL, for an `all` area whose tests live
inside the source (cargo), and past 800 files. `{base}` and `@` are written literally: the
lane resolves them on the commit it checks, so every later run of the same commands is
recognised as the same check. Never pass a runner's own
`--changed`, `--changedSince` or `--only-changed`: on the base commit it selects nothing, so the
lane could not tell an old failure from a new one. When the summary marks a component `skip`, drop its `test=` label instead.

Run the command through the package's own runner when the suite needs its script's env
(`pnpm --filter web exec vitest run {files}`). A project whose
test script adds setup, such as a test database or a `.env.test`, keeps that setup and only
appends the files. An e2e suite that runs through a wrapper script appends them
to the script.

**Lint, typecheck and build are never scoped in the background run**: the full row of each
reached component. A typecheck and build of the committed code is what catches a file the agent
forgot to `git add`. The builder's own check lints only its changed files, by path
(`npx eslint <files>`, `npx prettier --check --ignore-unknown <files>`, `ruff check <files>`),
keeping the extensions the tool handles.

**Read the summary first**, once per run: `ck-affected <base>` (story) or
`ck-affected <base> --area`. FULL → the full rows (the `@` form already prints them). A
component marked `skip` → no run there. Never narrow a wave's run below area scope.

## After a red run

Fix, commit, and start the same labels again with the same `--base`
([qa-lane.md § When it ends](../../../references/qa-lane.md#when-it-ends)). `{base}` then reaches
back to the last commit that passed, so the run covers the red work and everything after it, and
nothing that already passed.

## How the commands run

`ck-qa start <id> …`, one `<label>='<command>'` per independent command. Add `--parallel` when
there are two or more labels, as with the `package.json` and `pyproject.toml` rows: one pass then
reports every failing command. A row written as an `&&` chain (`Cargo.toml`, `go.mod`,
`CMakeLists.txt`) shares one build lock or tree, so it stays **one label** and runs in order.
