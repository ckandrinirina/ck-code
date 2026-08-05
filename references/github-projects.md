# GitHub Projects Board — Shared Contract

One definition, four consumers (`config`, `ship`, `build`, `doctor`). Never restate
these rules in a skill file — link here.

## The board is a generated view

A Projects v2 board is a **view of story frontmatter**, exactly like
`STORIES_INDEX.md` ([data-model.md](data-model.md)). Nothing about a card is
authoritative: `ck-project sync` reads every story's `status:`, `delivery:` and `issue:`,
computes the column each card belongs in, and pushes only the differences.

That is why there is no board migration: a board that was never synced and a board
that is half-synced take the identical code path. The first sync of a plan published
before the board existed back-fills every card; the next sync of an unchanged plan
costs **two** `gh` calls and changes nothing.

## Configuration — `tasks/SETTINGS.md`

Flat frontmatter, same format contract as story files (one key per line, no block
scalars). `github_issues` is the master switch: `false` or absent makes every board
call a no-op. `trunk_branch` (optional) names the branch a merged PR must land on for a
story to count as delivered; absent, it is the repo's default branch
([`branch-topology.md`](branch-topology.md#resolution)).

Column **names** are authoritative; each `board_*_id` beside them is a cache.
`sync` re-derives ids from the live board on every run and rewrites the file when
one has gone stale, so renaming a column in the GitHub UI needs no edit here.

An **empty** `board_<role>` means the board has no such column — that transition is
skipped, never failed. This is what lets ck-code drive a three-column board and a
five-column one with the same code.

## Role → column

Seven roles, listed in **board order** — the order a newly provisioned board's columns
get. Both axes feed it: `status` ([data-model.md](data-model.md#two-axes-status-is-work-delivery-is-integration))
places the card up to "finished", `delivery` carries it the rest of the way to the trunk.

| # | Role | Column | Set when |
|---|---|---|---|
| 1 | `blocked` | Blocked | any `blocked_by` story not `done`/`skip` |
| 2 | `todo` | Todo | `status: todo` and every `blocked_by` story is `done` or `skip` |
| 3 | `in_progress` | In Progress | `status: in-progress`, no open PR |
| 4 | `ready_to_ship` | Ready to Ship | `status: done` and `delivery` empty — finished, nothing opened yet |
| 5 | `in_review` | In Review | `delivery: pr` — a PR is open |
| 6 | `bug` | Bugs | `status: bug`, at any delivery |
| 7 | `done` | Done | `status: done` and `delivery: merged` |
| — | *(archive)* | — | `status: skip`, when `board_archive_skip: true` |

**Precedence, first match wins: `bug` → `blocked` → `delivery` → `status`.** A bug story
is never in another column, and Bugs sits at 6 rather than 1 because a defect is work that
came *back* late — after review, before Done — not work that never started.

Bugs and Blocked are separate columns because they are opposites: a bug is **always
actionable** and outranks all `todo` work in `track next`, while a blocked story cannot be
started at all. One column for both hides the most urgent item on the board.

An epic issue is placed by rollup over its non-`skip` stories: all `done` **and**
`delivery: merged` → `done`; all `done` otherwise → `ready_to_ship`; any `bug` → `bug`;
any `delivery: pr` → `in_review`; any `in-progress` → `in_progress`; else `todo`.

## Reconciliation — how `delivery: merged` happens

A PR is merged on github.com, with no ck-code skill running. So `sync` re-derives delivery
before it places any card:

1. collect every `pr:` in the plan (story frontmatter, then `EPIC.md` for inherited ones);
2. **one batched call** — `gh pr list --state all --limit 200 --json number,state,baseRefName`
   — never one call per story;
3. `MERGED` into `trunk_branch` → write `delivery: merged`; `OPEN` → `delivery: pr`;
   `CLOSED` unmerged → reset `delivery` to empty and warn; merged into some *other* base →
   leave as `pr` and warn;
4. regenerate the views, then place the cards.

**Inheritance is materialized, never re-derived.** A story that resolved its state through
its epic's `pr:` gets that answer written onto its **own** `delivery:`. So `ck-index`,
`track` and `ck-doctor` each read one field on one file and no consumer implements the
walk-up a second time — the rule lives in `sync` alone.

`delivery` is therefore a **cache with an immutable anchor**: `pr:` is a pointer that
cannot drift, and every sync re-answers the question from GitHub. This is the same
"authoritative name, cached id" shape as the `board_*_id` fields below. The cache exists so
`track` and `STORIES_INDEX.md` render offline.

There is no sticky rule. Before `delivery` existed, `in_review` was not expressible in
frontmatter — a story was `in-progress` whether or not its PR was open — so `ship` pushed
the card and `sync` was forbidden from moving it back. `delivery: pr` is that fact, stored
where every other fact lives, so In Review is now an ordinary derived column and `sync` may
move cards freely in both directions.

## Commands

```bash
ck-project discover                      # projects for the owner + current settings, as JSON
ck-project init --project 7              # adopt an existing board (never mutates it)
ck-project init --project 7 --extend     # adopt it AND add any missing preset columns
ck-project init --project 7 --reorder    # rewrite the existing option order to the preset
ck-project init --create "My Roadmap"    # create, link to the repo, provision 7 columns
ck-project sync [tasks/<slug>]           # reconcile delivery from GitHub, then every card
ck-project backfill [tasks/<slug>]       # recover pr: for work shipped before 6.4
ck-project set <issue> <role>            # one-shot push (manual escape hatch)
ck-project show                          # print resolved settings
```

`--dry-run` on `init`, `sync` and `backfill` prints every change and makes none.

**`backfill`** exists because a project upgrading to 6.4 has stories that are `done` and
long since merged, but carry no `pr:` — so they would land in *Ready to Ship*. It asks
GitHub which PR closed each linked `issue:`
(`gh issue view <n> --json closedByPullRequestsReferences`), writes the number back as
`pr:`, and lets the following `sync` mark them `merged`. It works because `ship` always
writes a `Closes #<issue>` footer; a story with no `issue:`, or none that GitHub can link,
is reported and skipped. Run it once per plan.

**Run it before the first sync that has a Ready to Ship column to place cards into.** With
no `pr:` recovered, that sync moves every long-merged card out of Done and into Ready to
Ship — correct by the rules, and alarming to anyone watching the board.

**`--reorder`** rewrites an existing board's option order to the preset, rearranging only
the columns already there — it does **not** imply `--extend`, because `--extend` matches
preset *names* and would add a duplicate "Todo" beside a board's own "Backlog". Plain
`--extend`
deliberately appends new columns at the end (preserving the user's order), so an upgraded
board otherwise reads `… Blocked, Done, Ready to Ship, Bugs`. Because
`updateProjectV2Field` replaces the whole option set, `--reorder` **always runs a full
`sync` immediately afterwards** — if GitHub re-mints option ids, that sync re-places every
card and no state is lost.

## Adopting an existing board

`init --project N` reads the live single-select field and matches its option names
to roles case-insensitively (`*progress*` → `in_progress`, `*review*` → `in_review`,
`*block*|*hold*` → `blocked`, `*bug*|*defect*` → `bug`, `*ship*|*to merge*` →
`ready_to_ship`, …). A column one role claims is not offered to a later role, and the
ambiguous words are rejected before they can be claimed by the wrong role:

- `*review*` is rejected for `todo`/`in_progress`, so "Ready for review" → `in_review`;
- `*bug*` is rejected for `blocked`, so a "Bugs" column → `bug`, not Blocked;
- `*ship*` is rejected for `todo`, so "Ready to Ship" → `ready_to_ship`, not Todo — `todo`
  matches bare `*ready*` ("Ready", "Ready for dev") and would otherwise swallow it.

Unmatched roles are left empty — the board keeps its own shape and those transitions
are skipped. **An existing board is never mutated without `--extend`.**

## Provisioning a new board

`gh project create` yields a Status field with Todo / In Progress / Done. `--extend`
then issues one `updateProjectV2Field` mutation sending the **union** — every
existing option unchanged, then the missing preset ones — because that mutation
replaces the whole option set and sending only the new ones would delete the user's
columns. A fresh board therefore gets the preset order: Blocked, Todo, In Progress,
Ready to Ship, In Review, Bugs, Done. An adopted board keeps its own order and receives
the missing columns at the end, unless `--reorder` is passed.

## Rules

- **Never let a board failure block a commit, a build, or a status write** — the board is a view; frontmatter is the record. Surface the error and carry on.
- **Never mutate an existing board's columns without `--extend`** — the user's board shape is theirs, and `updateProjectV2Field` replaces the entire option set.
- **Never reorder an adopted board without `--reorder`**, and never `--reorder` without the `sync` that follows it.
- **Never add the Ready to Ship column to a board with pre-6.4 history without running `backfill` first** — the next sync would move every long-merged card out of Done.
- **Never move a card by hand with `gh project item-edit`** — call `ck-project`, which resolves ids and skips no-op writes.
- **Never treat a missing column as an error** — an empty `board_<role>` is a supported configuration, not a misconfiguration. A board with no Ready to Ship or Bugs column is fully supported.
- **Never write board state into story frontmatter** — the board is derived from it, never the reverse. `delivery` is not board state: it is GitHub's answer about a PR, cached where every fact lives.
- **Never resolve PR state one story at a time** — one batched `gh pr list` per plan, never a `gh pr view` per card.
- **Always run `ck-project sync` in the same phase** as the `ck-index` that follows a status change, so the view and the board move together.
