# QA Validation — Shared Procedure

Used by `build` (Phase 7) and `fix` (Phase 7). Invoke the
`ck-code:qa-validator` agent in preference to running these steps inline if
the agent is registered.

## Step 0 — Load QA expert skills (mandatory)

Before any QA work:

```
Read(".claude/skills/experts/qa/SKILL.md")
Read(".claude/skills/experts/qa-project/SKILL.md")
```

Apply their standards throughout. A self-review without loading these
skills does NOT count as QA validation.

For bug-fix flows, also `Read(".claude/skills/experts/analyst/SKILL.md")`.

## Step 1 — Acceptance criteria verification

For EACH acceptance criterion in the original story:

- Confirm a test covers it (Phase 4 / Phase 6 should have produced it).
- Confirm the implementation fulfils it.
- Mark **PASS** or **FAIL** with explanation.

For bug-fix flows: re-check ALL acceptance criteria, not just the broken
ones — the fix may have side effects on previously-passing criteria.

## Step 2 — Run the full test suite

Run **all** tests (not just new ones) for the affected stack. Watch for
regressions in previously-green tests.

## Step 3 — Code-quality checks

Run all applicable quality tools for the stack. Detect what's available
per project; full command list (TypeScript / Rust / Python / C++ / JUCE)
lives in the `build` skill's `references/tdd-walkthrough.md`. Zero
compiler warnings in project-owned files is the bar.

## Step 4 — Architecture compliance

Check the implementation against the story's **feature doc**
(`docs/architecture/features/<slug>/index.md`, or a legacy flat
`docs/architecture/features/<slug>.md`, routed via `FEATURE_INDEX`) + `folder-structure.md`:

- New files in correct directories per `folder-structure.md`.
- API shapes match the feature doc's `## API`.
- Data flow follows the feature doc's `## Flows`.
- DB changes consistent with the feature doc's `## Data` (and `_shared.md` for base tables).

## Step 5 — Edge-case analysis

Look for scenarios tests might not cover: null / undefined / empty inputs,
concurrent access (if applicable), resource cleanup (file handles,
connections), error propagation through the call chain.

## Step 6 (bug-fix only) — Minimalism check

The fix must be the **smallest** change that resolves the bug — no
unrelated refactoring, no improvements outside scope, no added features.
Diff should be small and focused. If the diff is broader than the bug
report justifies, flag it and ask the user to narrow scope.

## Step 7 — Present QA report

Emit a QA Report with:

- Per-criterion PASS / FAIL.
- Test totals + new regressions.
- Code-quality results.
- Architecture compliance.
- Edge-case coverage.
- Issues Found table (severity).
- Final **Verdict: PASS / NEEDS FIXES**.

Skill-specific report templates: `build/references/examples.md` (Phase 7)
or `fix/references/qa-dialogue.md` (Phase 7.5).

## Step 8 — Handle the result

**PASS (no issues):** mark the QA task `completed`, proceed to the
calling skill's completion phase.

**NEEDS FIXES** — track iteration count (max 3):

- **Iteration < 3:** announce `[N]/3`, fix each issue (write a test for
  it first if missing, then fix code), re-run any refactor pass, then
  re-run QA from Step 1 with a fresh check.
- **Iteration = 3:** **escalate to user** with three options:
  - **A) FIX MANUALLY** — apply specific fixes the user suggests.
  - **B) ACCEPT AS-IS** — proceed with known issues, document them.
  - **C) ABORT** — stop work, revert story to TODO status.

Exact wording for the escalation lives in the calling skill's references
(`build/references/examples.md` or `fix/references/qa-dialogue.md`).

## Rules

- **Iteration cap is 3.** Never silently continue past iteration 3 —
  always escalate.
- **Always load the QA expert skills** before validating. A self-review
  without them is not QA.
- **Tests must stay green throughout** — if Step 2 turns up regressions,
  fix them before moving on.
- **Never skip Step 4** (architecture compliance) — the bug or feature
  may have introduced an architectural drift even if tests pass.
