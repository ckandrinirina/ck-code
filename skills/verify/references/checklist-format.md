# Checklist — Format Contract (format 2)

A plan's manual-verification record, laid out like its stories: YAML frontmatter holds the
state, the Markdown body holds what a human reads. It is **optional**: only `/ck-code:verify`
creates it, and a plan without one is complete. It is **committed**: authored state, not a
generated view, which is what makes a session resumable on another day, machine or chat.

```
tasks/<plan>/CHECKLIST.md               index — plan, session state, Before you test, Not yet testable
tasks/<plan>/checklist/C-NN_<slug>.md   one item — its state and its test steps
```

**`ck-checklist` is the only writer of frontmatter.** It allocates IDs, records answers,
ticks story human checks and tracks the session. `verify` edits only the Markdown bodies
(the index's Before you test and Not yet testable, an item's steps). Never hand-edit a key.

| Command | Does |
|---|---|
| `ck-checklist init <plan> --feature <slug> --title "<plan title>"` | write the index |
| `ck-checklist new <plan> --title … --stories "NN-SS …" --source … [--criterion …] [--checks …] [--expected …] [--after C-NN] [--recorded]` | allocate the next `C-NN`, write an outline item. `--recorded` = the human check is already ticked, enters as `pass` |
| `ck-checklist summary <plan>` | counts, **Retest**, **Waiting on fix**, the open session |
| `ck-checklist list <plan> [--open]` | one line per item |
| `ck-checklist count <plan>` | open items (`0` without a checklist) |
| `ck-checklist start <plan> [--epic NN] [--all]` | open a new session |
| `ck-checklist next <plan> [-n 2]` | the next items of the open session, with their paths |
| `ck-checklist record <plan> C-NN pass\|fail\|blocked\|skip ["words"]` | write an answer; prints the files to stage |
| `ck-checklist set <plan> C-NN key=value…` | `detail`, `after`, `source`, `title`, `criterion`, `fix` |
| `ck-checklist close <plan>` | end the session |
| `ck-checklist import <plan>` | convert a format-1 `CHECKLIST.md` in place |

## Index — `CHECKLIST.md`

```markdown
---
plan: ariary-paid-games
feature: ariary-paid-games
format: 2
updated: 2026-09-30
session: 3
session_scope: epic 41
session_all: false
session_last: C-04
session_at: 2026-09-30
---

# Manual verification — Ariary paid games

## Before you test

1. <runnable prerequisite — the exact command, env var / config key and value, seed data, test account and role>
2. <how to start the app — the exact command, and the URL or screen it opens on>
3. <how to know it is ready — what the tester sees when it started correctly>

## Not yet testable

- NN-SS — <title> (status: todo)
```

| Key | Meaning |
|---|---|
| `format` | `2`. An index without it that holds `### C-NN` headings is format 1 → `import` |
| `session` | the last session number, never reused |
| `session_scope` | `all` or `epic NN` while a session is open, empty once closed |
| `session_all` | `true` when the session retests `pass` and `skip` items too |
| `session_last` | the last item answered — the resume point shown to the tester |

## Item — `checklist/C-NN_<slug>.md`

```markdown
---
id: C-04
title: "Real Ariary counter after sign-in"
status: todo
stories: 41-02
epics: 41
source: "41-02 human check"
criterion: "Human check — the games page shows the real N/10 counter after sign-in"
detail: full
after:
result:
was:
fix:
tested_in:
updated: 2026-09-30
---

- **Checks:** the games page shows the player's real paid-game count
- **Start:** signed out, on `/games`
- **Steps:**
  1. Header — click "Sign in", log in as `player1@test.mg` / `Test1234!` → back on `/games`
  2. Fifth card, "Soka" → counter under the title
- **Expected:** `7/10` (the seeded count for player1)
- **Fail if:** `3/10` (the fixture), `0/10`, or no counter
```

| Key | Rule |
|---|---|
| `id` | `C-NN`, allocated once by `new`, sequentially. Never reused or renumbered |
| `status` | `todo` · `pass` · `fail` · `blocked` · `skip`. **Open** = `todo`, `fail`, `blocked` |
| `stories`, `epics` | space-separated `NN-SS` ids, and the epics they belong to |
| `source` | `NN-SS human check`, `NN-SS criterion` (derived, when the story has no human check), or `journey · features/<slug> § Flows › <name>`. Gets ` (source removed)` appended when it is gone |
| `criterion` | the exact text of the human-check line (without `- [ ]`). `record … pass` ticks the story line containing it. Empty for other sources |
| `detail` | `outline` until the steps meet the detail standard, then `full` |
| `after` | `C-NN` this item must run after, or empty |
| `result` | empty while `todo`. Otherwise the status, date, and for `fail`/`blocked`/`skip` the tester's own words |
| `was` | the previous result on a retest (only the latest), with `→ fix NN-SS` when it had one |
| `fix` | the story a `fail` was handed to. Cleared by the next answer, kept in `was` |
| `tested_in` | the session that last answered it. `next` never offers an item twice in one session |

**Retest** = a `fail` item whose stories are all back at `done`. **Waiting on fix** = any
other `fail` item. `next` orders the open session as Retest, then `todo` and `blocked` (plus
`pass` and `skip` when `session_all`), each by `C-NN`, and never offers a Waiting item.

## Writing an item — the detail standard

An item starts as an **outline** (`detail: outline`, body `- **Steps:** outline`, a one-line
Expected, no Fail if) and is filled to this standard just before a session prints it.

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

Every label, route, value and message comes from a file read (source, fixtures, seed data,
i18n strings). When a value can only be known at run time (a generated ID, today's balance),
say where to read it and what it must match.

## Refresh merge rules

A refresh (a re-run after more stories reach `done`) changes the checklist in place:

1. An item keeps its `id`, state and body while its source still exists. Steps below the
   detail standard are rewritten when the item next comes up in a session, never on refresh.
   `result` and `was` are never touched.
2. A new source (a story newly `done`, a new flow) gets `ck-checklist new`: the next free `C-NN`.
3. An item whose source is gone (the criterion was reworded or removed) stays, with
   `set source="<source> (source removed)"`. It is never deleted, because its result is history.
4. A story leaving `done` for `bug` does not reset its items. A `fail` item whose stories are
   back at `done` is a Retest. Its status stays `fail` until the tester passes it.
5. `## Not yet testable` in the index is rewritten to list the stories not `done`.

## Format 1

Before format 2, the whole checklist was one `CHECKLIST.md` with each item as a
`### C-NN · <status> · <ids> — <name>` heading. `ck-checklist import` converts it in place:
the index keeps Before you test and Not yet testable, each item becomes a file, `(was …)`
and `→ fix NN-SS` become `was` and `fix`, and a human-check source finds its `criterion` in
the story (a WARN asks for `set criterion=…` when the story has several).
