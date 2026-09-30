# Test Craft — Minimal Test Standard

The bar for every test `build` writes: in the RED/GREEN loop (4.3–5.3), the REFACTOR phase
(6.1 prune scan), and QA (Step 3.5 verifies the scan ran). Sits beside
[`code-craft.md`](code-craft.md), which governs how production code reads, while this file
decides which tests exist. `team`'s conventions guide can refine it for one project but
never loosens it.

**The goal is the smallest test suite that would catch a real regression in this story's
behaviour.** Adding a test has a cost: it runs on every cycle and every QA pass, and it
breaks on every refactor that touches what it pins. A test that would catch no bug another
test misses costs that much and protects nothing.

## What to write

- **Behaviour, through the public surface.** Test what a caller or user observes: return
  values, emitted events, persisted state, rendered output. Test through the module's
  exported API, never a private helper, internal field or call order.
- **One test per behaviour, not per function.** Every acceptance criterion gets at least one
  test. A second test is justified only by a distinct branch or outcome.
- **Edge and error cases only where the code has them.** Add a test for empty input, a limit
  or a failure only when the story's code has a branch that handles it, or a criterion names
  it. Never add one because it appears on a generic checklist.
- **Small and focused.** One behaviour per test, with a setup that shows only what that
  behaviour needs. When several input/output pairs exercise the same behaviour, write one
  table-driven or parameterised test.
- **Mock only at boundaries.** Stub the network, clock, filesystem or other process. Never
  stub the code under test or its in-module collaborators. Assert on outcomes, never on
  which mocks were called in which order, unless the call *is* the behaviour (a sent email,
  a published message).

## Never write

- a test of the language, framework or library (a getter returns its field, a derive or
  decorator does what it documents, a type checker catches a type)
- a test of a constant, config value or static copy
- a snapshot of a large output when one assertion would pin the behaviour
- a second test of a path another test already drives to the same outcome
- a test whose only failure mode is a behaviour-preserving refactor

## Scaffolding tests

During the RED/GREEN loop, a small test that drives a tricky internal step is allowed as
**scaffolding**. It helps you build the code, but it is not meant to stay in the suite. Name
it so the prune scan finds it easily, then decide in 6.1: once a behaviour test drives the
same path, delete the scaffolding test. Keep it only when it is the sole test of a real
branch, and then move it to the public surface.

## Test-prune scan (implementation)

Run against the tests **added or changed by this story** in `build` Phase 6.1, after the
comment & readability scan. Five checks, in order. Each hit is an ISSUE for 6.2:

1. **Duplicate** — two tests drive the same path to the same outcome. Keep the clearer one,
   or merge them into one parameterised test.
2. **Scaffolding** — a scaffolding test whose path a behaviour test now covers. Delete it.
3. **Implementation-coupled** — the test reads internals, asserts on mock-call order, or
   would fail after a behaviour-preserving refactor. Rewrite it against the public
   surface, or delete it when a behaviour test already covers it.
4. **Trivial or speculative** — anything on the *Never write* list, or an edge case the code
   has no branch for. Delete it.
5. **Oversized** — one test asserts several unrelated behaviours, or its setup is mostly
   noise. Split it by behaviour or trim the setup to what the assertion needs.

**Deletion guards — never prune:**

- the **only** test that covers an acceptance criterion
- the reproduction or regression test of a bug (`fix` 4.2, Bug-Fix Mode, 8.5.3)
- a test the story did not add; pre-existing tests are out of scope
- a test the loaded conventions guide requires (a contract test, a smoke test)

Prune in 6.2 like any refactoring: remove or merge, then run the story's test files, which
must stay green. Report the count on the REFACTOR line (`2 tests pruned`). Pruning is not
"editing a test to force GREEN", because the suite was already green before the prune.

## Why

When all tests are written up front, you guess at a design that doesn't exist yet. That
leads to edge-case tests with no branch behind them, tests pinned to internals that later
change, and tests left over from helping build the code that nobody deletes. Each one makes
every later cycle, QA pass and refactor slower. Writing one behaviour at a time and
running a scan to delete leftovers keeps the suite at the size its behaviour needs: every
criterion covered, nothing covered twice.
