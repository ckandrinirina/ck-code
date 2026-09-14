# QA Validation — Shared Procedure

Used by `build` (Phase 7) and, for its acceptance-criteria and regression checks, by
`fix` (Phase 4) — both delegate to the `ck-code:qa-validator` agent and run these steps
inline only when that agent is unregistered.

## Step 0 — Load QA expert skills (mandatory)

**Whoever performs the QA runs this step** — the `ck-code:qa-validator` agent when the pass
is delegated (the normal path; it loads them itself), the calling skill only when it runs
these steps inline. It is never skipped on the assumption that the other side did it.

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

Run all applicable quality tools for the stack. Detect the component's
manifest and run that row of the per-stack command table in
[`parallel-mode.md`](../skills/build/references/parallel-mode.md#p7--qa-one-validator-per-story)
— the single source for both inline and PARALLEL MODE QA. Zero compiler
warnings in project-owned files is the bar.

## Step 3.5 — Redundancy and code-craft check

Verify Phase 6.1's two scans actually ran, then spot-check the diff against the same
checks — [`reuse-first.md`](reuse-first.md#redundancy-scan-implementation) owns the five
redundancy checks, [`code-craft.md`](code-craft.md#comment--readability-scan-implementation)
the four comment & readability checks; never restate either list here. QA re-runs a scan
only when Phase 6 shows no evidence of it (no scan line, no collapse/delete/comment fix in
6.2) or when the diff grew after it.

Anything found is an ordinary QA finding in the Issues Found table under the existing
iteration cap — never a new gate. Cite `file:line` and, for a redundancy hit, the existing
code the diff should have used; for a comment hit, the line to delete or the *why* it lacks.

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
- Redundancy check (scan ran; findings, if any).
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
  - **B) ACCEPT AS-IS** — proceed, recording each remaining issue under the story's
    Implementation Summary `### Notes` (bug-fix flow: under the Bug Report `### Resolution`).
  - **C) ABORT** — stop work and run `ck-story set <story-path> status=todo`, which writes the frontmatter and regenerates the views. A bug-fix flow instead leaves `status: bug` untouched — flipping it to `todo` discards the diagnosis, the Fix Plan and `prior_status`.

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
- **Never accept a duplicate because the tests are green** — Step 3.5 findings are real
  issues; a passing suite says nothing about code the repo already had.
- **Never skip Step 4** (architecture compliance) — the bug or feature
  may have introduced an architectural drift even if tests pass.
