# CHECKLIST.md — Format Contract

`tasks/<plan>/CHECKLIST.md` is the plan's manual-verification record. `verify` is its only
writer. It is **committed**: it is authored state, not a generated view, and it is what makes a
verification session resumable on another day or another machine.

## Template

````markdown
---
plan: <plan-slug>
feature: <feature-slug or empty>
updated: YYYY-MM-DD
---

# Manual verification — <plan title>

## Before you test

1. <runnable prerequisite — install, env var / config key, seed data, account or role>
2. <how to start the app>

## Epic NN — <epic title>

### C-01 · todo · NN-SS — <short scenario name>
- **Source:** NN-SS human check
- **Steps:** 1. <exact click, command or page> 2. <…>
- **Expected:** <what the tester sees>
- **Result:** —

### C-02 · pass · NN-SS — <short scenario name>
- **Source:** NN-SS human check
- **Steps:** …
- **Expected:** …
- **Result:** pass 2026-09-30

## Journeys

### C-07 · fail · NN-SS NN-SS — <flow name>
- **Source:** journey · features/<slug> § Flows › <flow name>
- **Steps:** …
- **Expected:** …
- **Result:** fail 2026-09-30 — <tester's words> → fix NN-SS

## Not yet testable

- NN-SS — <title> (status: todo)
````

## Fields

| Part | Rule |
|---|---|
| Heading | `### C-NN · <status> · <story ids> — <name>`. IDs are allocated once, sequentially, and never reused or renumbered. The status sits in the heading so one `grep` counts the open items |
| Status | `todo` · `pass` · `fail` · `blocked` · `skip`. **Open** = `todo`, `fail`, `blocked` |
| Source | `NN-SS human check` (one story criterion), `NN-SS criterion` (derived from a non-human-check criterion, when the story has none), or `journey · features/<slug> § Flows › <name>` |
| Result | `—` while `todo`. Otherwise the status, the date, and for `fail`/`blocked`/`skip` the tester's own words. A `fail` handed to `fix` ends `→ fix NN-SS` |

## Counting open items

```bash
grep -cE '^### C-[0-9]+ · (todo|fail|blocked) ·' tasks/2026-09-24_ariary-paid-games/CHECKLIST.md
```

## Refresh merge rules

A refresh (a re-run after more stories reach `done`) rewrites the file in place:

1. An item keeps its `C-NN`, status and Result when its Source still exists.
2. A new source (a story newly `done`, a new flow) appends an item with the next free `C-NN`.
3. An item whose Source is gone (the criterion was reworded or removed) stays and gets
   `(source removed)` appended to its Source line. It is never deleted, because its Result is history.
4. A story leaving `done` for `bug` does not reset its items. `fail` items whose story is back at
   `done` are **retest** candidates. Their status stays `fail` until the tester passes them.
