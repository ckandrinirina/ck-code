# Output Formats — Tables, Integrity, Conflict, QA, Summary

Reference output templates for PARALLEL MODE. Phase labels are the `P` steps in
[parallel-mode.md](parallel-mode.md).

## P1/P2 — Ready Stories Table

Printed by the SKILL.md 1.2 interactive menu and by P2 when scope is resolved there. The
`Parallel` column comes from the declared file-scope overlap: ✓ parallel-safe, or
⚠ overlaps [ID] (build in a separate wave).

```
Ready stories (N available):

 #  Story  Epic                        Size  Deps met            Parallel
──────────────────────────────────────────────────────────────────────────
 1  02-05  02 · JUCE Engine            M     02-01 ✓  02-02 ✓    ✓
 2  02-06  02 · JUCE Engine            M     02-03 ✓  02-04 ✓    ⚠ overlaps 02-05
 3  03-01  03 · Rust Server            S     01-01 ✓             ✓

Recommended parallel-safe set: 02-05  03-01
Pick: "recommended", "all", "1 3", or IDs like "02-05 03-01"
(or build whole epic NN in dependency-ordered waves)
```

## P5 — Integrity Report

```
Integrity (derived from git — not the agents' self-report):
─────────────────────────────────────────────────────
  02-05  →  ✓ complete   (+347 / -12, all criteria checked, clean tree)
  03-01  →  ◐ incomplete (+120 / -4, "rate limiting" unchecked)  → resume via SendMessage
  02-06  →  🚫 blocked   (empty diff — no implementation)         → re-dispatch fresh
─────────────────────────────────────────────────────
```

A **solo** wave reports the same three checks against the P4 base SHA:

```
Integrity (derived from git — not the agent's self-report):
─────────────────────────────────────────────────────
  01-04  →  ✓ complete   (+96 / -3 since <base-sha>, all criteria checked, clean tree)
            branch epic/01-auth · no worktree
─────────────────────────────────────────────────────
```

## P6 — Conflict Report

Skipped on a solo wave — print one line instead: `Conflicts: skipped (solo wave).`

```
Conflict analysis (dry-run merges onto <$TARGET>):
─────────────────────────────────────────────────────
  02-05  →  merges clean
  03-01  →  merges clean

  Cross-branch overlap:
    server/src/lib.rs  →  02-05 AND 03-01  ⚠️

  Suggested merge order (fewest overlaps first):
    1. story-03-01
    2. story-02-05
─────────────────────────────────────────────────────
```

No overlaps at all → "No conflicts detected — all branches merge cleanly."

## P7 — QA Report

```
QA (per branch, delegated to qa-validator):
─────────────────────────────────────────────────────
  02-05  →  QA: PASS
  03-01  →  QA: FAIL — cargo clippy — 2 warnings treated as errors  → BLOCKED from merge
─────────────────────────────────────────────────────
```

## P8 — Final Summary & Choices

```
Summary:
  ✓ Ready to merge:  story-02-05  (QA passed, conflict-free)
  ◐ Incomplete:      story-03-04  (stuck after resume cap — recommend splitting)
  ⚠ Review needed:   story-03-01  (QA failed: clippy errors)
  🚫 Blocked/failed: story-02-06  (empty diff)

What would you like to do?
  [1] Merge ready branches now (conflict-free order)
  [2] Review branches first, merge manually
  [3] Re-dispatch blocked/failed stories from scratch (new worktree; solo → same branch)
```

A solo wave already sitting on `$TARGET` drops option 1 — say
`Merge: none needed (solo on <$TARGET>).` and go straight to the regenerate.

## P8 — Post-Merge Check Prompt

Run on `$TARGET` in the main checkout, where every merged story sits together.

```
Merged into <$TARGET>: 02-05, 03-01 (merge SHA <sha>).
Please exercise the merged work in the main checkout:
- <scenario from acceptance criteria>
- <edge case>
Result? PASS / ISSUES
```

On `ISSUES`, a fix agent commits a regression test + fix on `$TARGET` (the story stays
merged), then re-ask.

## Wave Plan Table (wave mode)

Every wave carries its dispatch shape: `(parallel)` fans out one worktree agent per story,
`(solo)` sends one agent into the main checkout with no worktree.

```
Epic 01 — Wave plan (4 stories, depth 3):

  Wave 1  (parallel)   01-01  Login form          S
                       01-02  Session store       M
  Wave 2  (solo)       01-03  Auth middleware     M   ← needs 01-01, 01-02
  Wave 3  (solo)       01-04  Audit log           S   ← needs 01-03

Proceed with Wave 1? (PROCEED / DROP A STORY / ABORT)
```
