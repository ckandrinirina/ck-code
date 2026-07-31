# QA Validation — Shared Procedure

Used by `build` (Phase 7). (`fix` does not run this procedure — its reproduction
and diagnosis live in its own Phase 4, delegated to `ck-code:qa-validator`.)
Invoke the `ck-code:qa-validator` agent in preference to running these steps
inline if the agent is registered.

## Step 0 — Load QA expert skills (mandatory)

Before any QA work:

```
Read(".claude/skills/expert-qa/SKILL.md")
Read(".claude/skills/expert-qa-project/SKILL.md")
```

Apply their standards throughout. A self-review without loading these
skills does NOT count as QA validation.

For bug-fix flows, also `Read(".claude/skills/expert-analyst/SKILL.md")`.

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
(`docs/architecture/features/<slug>/index.md`, routed via `FEATURE_INDEX`) +
`folder-structure.md`:

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

Skill-specific report templates: `build/references/output-blocks.md` (Phase 7)
or `fix/references/qa-dialogue.md` (the fix diagnosis report, Phase 4.6).

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
  - **C) ABORT** — stop work, set the story frontmatter `status: todo` and regenerate the views (`ck-index`).

Exact wording for the escalation lives in the calling skill's references
(`build/references/output-blocks.md` or `fix/references/qa-dialogue.md`).

## Design fidelity (conditional)

**Skip entirely** when `docs/architecture/design-system/index.md` does not exist, or when
the story touched no UI files. No design system means no fidelity check.

When both hold, add these to the normal findings — they are ordinary QA findings inside the
existing iteration cap of 3, never a new gate type:

1. **Hardcoded value** — a literal hex, `rgb()`, `px` font-size, `font-family`, radius, or
   spacing value in a changed UI file where `## Foundations` defines a token. Cite
   `file:line` and the token that should have been used.
2. **Unread card** — a component implemented in this story that maps to an inventory card
   whose cached source was never read. Its markup is unverified against its source.
3. **Undeclared new component** — a UI component with no matching card and no line in the
   story's `## Unplanned Changes` explaining it.

Rules and lookup order: [`design-system.md`](design-system.md) § Fidelity rules.

## Rules

- **Iteration cap is 3.** Never silently continue past iteration 3 —
  always escalate.
- **Always load the QA expert skills** before validating. A self-review
  without them is not QA.
- **Tests must stay green throughout** — if Step 2 turns up regressions,
  fix them before moving on.
- **Never skip Step 4** (architecture compliance) — the bug or feature
  may have introduced an architectural drift even if tests pass.
