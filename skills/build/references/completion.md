# Completion Mechanics — Implementation Summary, Files Touched, Bug-Fix Sub-Loop

Detail for build Phase 8. SKILL.md holds the gates and the phase order; this file holds
the field specs and the manual-test bug-fix sub-loop steps.

## 8.1 — Implementation Summary Fields (mandatory)

The Implementation Summary block (template in `story-template.md`) must record:

- TDD iteration count
- QA iteration count
- tests written
- files created / modified counts
- **unplanned changes count** (from `## Unplanned Changes` if present, else "none")
- what was implemented
- a precise Files Touched list (below)
- SOLID compliance summary
- notes

### Files Touched Precision (mandatory)

- CREATED files: path only — e.g. `CREATED src/ws/handler.rs`
- MODIFIED files: path + exact line numbers — e.g. `MODIFIED src/main.rs:12,45-48,92`
- Use `git diff --stat` and `git diff` to collect precise lines
- No descriptions — paths + line numbers only

## 8.5.3 — Manual-Test Bug-Fix Sub-Loop

Entered when 8.5.1 reports `ISSUES`. Every cycle MUST run all eight steps in order before
returning to 8.5.1:

1. Capture the bug from the user (what, repro, expected vs actual).
2. Append an `## Manual-Test Bugs` entry to the story file (template in
   `story-template.md`). Status: `OPEN`.
3. Write a failing regression test that reproduces the bug (TDD red).
4. Apply the minimum fix; full suite green (TDD green).
5. **MANDATORY:** Re-run **Phase 6 (Refactor)** on touched code — SOLID review, tests
   stay green.
6. **MANDATORY:** Re-run **Phase 7 (QA)** with the full procedure in
   `../../../references/qa-validation.md`. QA's own 3-iteration cap applies inside each
   bug-fix cycle.
7. Update the bug entry: `OPEN` → `FIXED` + fix summary + `path:line[,line]` Files Touched.
8. Return to 8.5.1 against the new build.

**Bug-Fix iteration cap = 3.** On the 3rd cycle, escalate `FIX MANUALLY / ACCEPT AS-IS /
ABORT` (template in `examples.md`). Never silently continue past 3.

## 8.6b — Feature-Doc Write-Back

Keep the feature doc current with what this story changed. Edit the canonical doc read
in Phase 2 (the `Docs` path for this story's feature, `features/<slug>/index.md`):

- If the story introduced a **new** component / endpoint / table / flow, add a concise
  entry to the matching section (`## Components` / `## API` / `## Data` / `## Flows`) —
  derive it from the story's Files Touched + Implementation Summary; keep it short.
- Append a one-line entry to its `## Changelog`: `[date] · <story ID> — <delta> ·
[./YYYY-MM-DD_<id>_<short>.md](./YYYY-MM-DD_<id>_<short>.md)` where `<delta>` names the
  component/endpoint/table/flow added or changed.
- **Write the dated delta doc** beside it:
  `features/<slug>/YYYY-MM-DD_<story ID>_<short>.md` from the Increment / Fix Delta Doc
  template (see `design`'s [architecture-templates.md](../../design/references/architecture-templates.md)) —
  the change narrative (what changed · why · surface touched). `index.md` stays the
  routed source of truth; this dated doc is an append-only journal entry.
- If the change is cross-cutting (reused by other features), put it in `_shared.md`
  instead and link it from the feature doc's `## Shared dependencies`.

**Skip** the write-back for changes with no architectural surface (pure refactors,
test-only stories, formatting). **Fallback:** if the `Docs` cell is `—`/missing, note
that the user should run `/ck-code:doc-optimizer sync`, and do not create the doc here.
