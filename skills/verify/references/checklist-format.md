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
- **Checks:** <the behavior under test, in user terms>
- **Start:** <only what Before you test does not set up — account, page, data, or "after C-NN">
- **Steps:**
  1. <where> — <action with exact label / value> → <visible change>
  2. <…>
- **Expected:** <final state, with the exact text, value or count>
- **Fail if:** <the likely wrong outcomes>
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

An item is written as an **outline** first (`- **Steps:** outline`, with a one-line Expected
and no Fail if), and filled to this standard just before a session prints it.

Write for a tester who has never seen the code, the stories or this feature. They must be able
to run the item from the checklist alone, without asking what a step means. A step that says
"check the dashboard works" or "test the payment flow" fails this standard.

| Part | Rule |
|---|---|
| Checks | One short line in user terms. No story IDs, file paths or internal names |
| Start | Only what `## Before you test` does not set up: the account, the page, the data, or `after C-NN`. Omit the line when there is nothing to add |
| Steps | **One action per step**: *where* (page, URL, screen, menu path such as Settings › Billing) — *what* (exact label in quotes, exact value in backticks) `→` the visible change. The `→` part is omitted when nothing visible changes. No "etc.", "and so on", or "as usual" |
| Expected | The concrete end state, with the real text, number, count or state. Never "works correctly" or "is displayed properly". Never repeat a step's `→` |
| Fail if | One line, the near-misses that could pass for success: a fixture value, a stale count, a silent no-op |
| Journeys | The same rules across every screen the flow crosses. Never collapse a hop into "go through checkout" |

**Precise and terse.** Every word carries a location, a label, a value or an outcome. Write
fragments, not sentences, and no explanations of why or restated context. Put shared setup in
`## Before you test` once, never in each item. Short is fine. Vague is not.

```markdown
### C-04 · todo · 41-02 — Real Ariary counter after sign-in
- **Source:** 41-02 human check
- **Checks:** the games page shows the player's real paid-game count
- **Start:** signed out, on `/games`
- **Steps:**
  1. Header — click "Sign in", log in as `player1@test.mg` / `Test1234!` → back on `/games`
  2. Fifth card, "Soka" → counter under the title
- **Expected:** `7/10` (the seeded count for player1)
- **Fail if:** `3/10` (the fixture), `0/10`, or no counter
```

Every label, route, value and message comes from a file read (source, fixtures, seed data,
i18n strings). When a value can only be known at run time (a generated ID, today's balance),
say where to read it and what it must match.

## Counting open items

```bash
grep -cE '^### C-[0-9]+ · (todo|fail|blocked) ·' tasks/2026-09-24_ariary-paid-games/CHECKLIST.md
```

## Refresh merge rules

A refresh (a re-run after more stories reach `done`) rewrites the file in place:

1. An item keeps its `C-NN`, status, Result and Steps when its Source still exists. Steps
   that fall short of the detail standard are rewritten when the item next comes up in a
   session, never on refresh. The Result is never touched.
2. A new source (a story newly `done`, a new flow) appends an item with the next free `C-NN`.
3. An item whose Source is gone (the criterion was reworded or removed) stays and gets
   `(source removed)` appended to its Source line. It is never deleted, because its Result is history.
4. A story leaving `done` for `bug` does not reset its items. `fail` items whose story is back at
   `done` are **retest** candidates. Their status stays `fail` until the tester passes them.
