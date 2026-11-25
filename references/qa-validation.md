# QA Validation — Shared Procedure

The **review** half of QA, used by `build` (S5, P7) through the `ck-code:qa-validator` agent, and
inline only when that agent is unregistered. Its other half, the commands, runs in the background
on the same commit ([`qa-lane.md`](qa-lane.md)): a review never runs one and never waits for one.

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

## Steps 2 and 3 — the background run's

The suite, lint, typecheck and build are the lane's, at the scope `build` resolved. A review
checks only what they cannot: a criterion a heavy spec alone proves passes on the spec's
assertions plus the builder's own run of that file (`ck-qa` log `EE-SS-heavy`), and
`ck-heavy unmarked <base> <id>` printing a file is an Issue ([`heavy-tests.md`](heavy-tests.md)).

## Step 3.5 — Redundancy, code-craft and test-prune check

Verify Phase 6.1's three scans actually ran, then spot-check the diff against the same
checks — [`reuse-first.md`](reuse-first.md#redundancy-scan-implementation) owns the five
redundancy checks, [`code-craft.md`](code-craft.md#comment--readability-scan-implementation)
the four comment & readability checks,
[`test-craft.md`](test-craft.md#test-prune-scan-implementation) the five test-prune checks and
their deletion guards; never restate any list here. QA re-runs a scan only when Phase 6
shows no evidence of it (no scan line, no collapse/delete/comment/prune fix in 6.2) or when
the diff grew after it. A prune that removed the sole test of a criterion, or a bug's
reproduction/regression test, is a HIGH finding: restore the test.

Anything found is an ordinary QA finding in the Issues Found table under the existing
iteration cap — never a new gate. Cite `file:line` and, for a redundancy hit, the existing
code the diff should have used; for a comment hit, the line to delete or the *why* it lacks;
for a test hit, the test to delete or merge and the test that already covers its path.

## Step 4 — Architecture compliance

Check the implementation against the story's **feature doc**
(`docs/architecture/features/<slug>/index.md`, routed via the `Docs` column of `EPICS_INDEX.md`) +
`folder-structure.md`:

- New files in correct directories per `folder-structure.md`.
- API shapes match the feature doc's `## API`.
- Data flow follows the feature doc's `## Flows`.
- DB changes consistent with the feature doc's `## Data` (and `_shared.md` for base tables).

## Step 5 — Edge-case analysis

Look for scenarios the code mishandles: null / undefined / empty inputs,
concurrent access (if applicable), resource cleanup (file handles,
connections), error propagation through the call chain. A missing test is a finding only
when the code has a branch for the scenario and no test drives it. A scenario the code has
no branch for is a code finding when it is a real defect, never a request for a speculative
test ([`test-craft.md`](test-craft.md#what-to-write)).

## Step 6 (bug-fix only) — Minimalism check

The fix must be the **smallest** change that resolves the bug — no
unrelated refactoring, no improvements outside scope, no added features.
Diff should be small and focused. If the diff is broader than the bug
report justifies, flag it and ask the user to narrow scope.

## Step 7 — Present QA report

Emit a QA Report with:

- Per-criterion PASS / FAIL.
- Background run: its id, and its result once it has one.
- Redundancy check (scan ran; findings, if any).
- Test-prune check (scan ran; tests pruned, if any).
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

- **Iteration < 3:** announce `[N]/3`, fix each issue (for a behaviour
  defect, write its failing test first if none exists, then fix code; a quality, lint or
  architecture finding gets no new test), re-run any refactor pass, commit,
  then review again from Step 1 beside a new background run.
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
2. **Off-card value** — a visual value in a changed UI file that differs from the value its
   mapped card declares for that element (a token rounded to, a library default kept). Cite
   `file:line`, the card path and the card's value.
3. **Unread card** — a component implemented in this story that maps to an inventory card
   whose cached source was never read. Its markup is unverified against its source.
4. **Undeclared new component** — a UI component with no matching card and no line in the
   story's `## Unplanned Changes` explaining it.
5. **Loop never ran** — no `Design fidelity` line in the story's `## Implementation Summary`:
   the [Design fidelity loop](design-system.md#design-fidelity-loop) was skipped.
6. **Remaining difference** — each difference that line lists as remaining, other than one
   marked `(content)`. `fidelity: visual review only` is accepted only for a stack the loop
   cannot shoot (not web, or no dev command).

Rules, lookup order and the loop: [`design-system.md`](design-system.md) § Fidelity rules.

## Replica fidelity (conditional)

**Skip entirely** unless the story's acceptance criteria cite an `S-NN` from a
`docs/replica/<slug>/REPLICA.md`. Then one ordinary finding when the story's
`## Implementation Summary` carries no `Fidelity S-NN:` line — the
[fidelity loop](replicate.md#fidelity-loop) never ran — and one per difference that line
lists as remaining where a replica token or component would have fixed it.

## Rules

- **Iteration cap is 3.** Never silently continue past iteration 3 —
  always escalate.
- **Always load the QA expert skills** before validating. A self-review
  without them is not QA.
- **Never hold a finding back for the background run**, and never run a command to support one.
- **Never accept a duplicate because the tests are green** — Step 3.5 findings are real
  issues; a passing suite says nothing about code the repo already had.
- **Never skip Step 4** (architecture compliance) — the bug or feature
  may have introduced an architectural drift even if tests pass.
