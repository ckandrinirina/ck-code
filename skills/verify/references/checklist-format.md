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

1. <runnable prerequisite — the exact command, env var / config key and value, seed data, test account and role>
2. <how to start the app — the exact command, and the URL or screen it opens on>
3. <how to know it is ready — what the tester sees when it started correctly>

## Epic NN — <epic title>

### C-01 · todo · NN-SS — <short scenario name>
- **Source:** NN-SS human check
- **What this checks:** <one plain sentence: the behavior under test and why it matters to a user>
- **Start from:** <the state before step 1: signed in as whom, on which page, which data exists>
- **Steps:**
  1. <one action: where (page / URL / screen / menu path), what to do (click the "Save" button,
     type `2500` in the "Amount" field)> → <what appears right after>
  2. <…>
- **Expected:** <the final observable outcome, with the exact text, value, count or state>
- **It failed if:** <what the tester would see instead: an error, a wrong value, nothing changing>
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
| Result | `—` while `todo`. Otherwise the status, the date, and for `fail`/`blocked`/`skip` the tester's own words. A `fail` handed to `fix` ends `→ fix NN-SS`. A `--all` retest of an item that already had a result appends the previous one, keeping only the latest: `pass 2026-10-02 (was fail 2026-09-30 — <words>)` |

## Writing an item — the detail standard

Write for a tester who has never seen the code, the stories or this feature. They must be able
to run the item from the checklist alone, without asking what a step means. A step that says
"check the dashboard works" or "test the payment flow" fails this standard.

| Part | Rule |
|---|---|
| What this checks | One plain sentence in user terms. No story IDs, file paths or internal names |
| Start from | Everything the item assumes that `## Before you test` does not already set up: the account, the page, the data that must exist, a previous item that must run first |
| Steps | **One action per step**, numbered. Each names *where* (page title, URL, screen, menu path such as Settings › Billing) and *what* (the exact button or field label in quotes, the exact value to type in backticks). Each ends with `→` and what the tester should see right after, so they notice at once which step went wrong. No "etc.", "and so on", or "as usual" |
| Expected | The concrete end state, with the real text, number, count, color or state change. Never "works correctly", "is displayed properly" or "behaves as expected" |
| It failed if | The likely wrong outcomes spelled out, so a near-miss (a fixture value, a stale count, a silent no-op) is not mistaken for a pass |
| Journeys | The same rules, step by step across every screen the flow crosses. Never collapse a hop into "go through checkout" |

Every label, route, value and message comes from a file read (source, fixtures, seed data,
i18n strings). When a value can only be known at run time (a generated ID, today's balance),
say where to read it and what it must match.

## Counting open items

```bash
grep -cE '^### C-[0-9]+ · (todo|fail|blocked) ·' tasks/2026-09-24_ariary-paid-games/CHECKLIST.md
```

## Refresh merge rules

A refresh (a re-run after more stories reach `done`) rewrites the file in place:

1. An item keeps its `C-NN`, status and Result when its Source still exists. Its Steps and
   the other fields are rewritten when they fall short of the detail standard or the code
   they name has changed. The Result is never touched.
2. A new source (a story newly `done`, a new flow) appends an item with the next free `C-NN`.
3. An item whose Source is gone (the criterion was reworded or removed) stays and gets
   `(source removed)` appended to its Source line. It is never deleted, because its Result is history.
4. A story leaving `done` for `bug` does not reset its items. `fail` items whose story is back at
   `done` are **retest** candidates. Their status stays `fail` until the tester passes them.
