# GitHub Projects Board — Shared Contract

One definition, four consumers (`config`, `ship`, `build`, `doctor`). Never restate
these rules in a skill file — link here.

## The board is a generated view

A Projects v2 board is a **view of story frontmatter**, exactly like
`STORIES_INDEX.md` ([data-model.md](data-model.md)). Nothing about a card is
authoritative: `ck-project sync` reads every story's `status:` and `issue:`,
computes the column each card belongs in, and pushes only the differences.

That is why there is no board migration: a board that was never synced and a board
that is half-synced take the identical code path. The first sync of a plan published
before the board existed back-fills every card; the next sync of an unchanged plan
costs **two** `gh` calls and changes nothing.

## Configuration — `tasks/SETTINGS.md`

Flat frontmatter, same format contract as story files (one key per line, no block
scalars). `github_issues` is the master switch: `false` or absent makes every board
call a no-op.

Column **names** are authoritative; each `board_*_id` beside them is a cache.
`sync` re-derives ids from the live board on every run and rewrites the file when
one has gone stale, so renaming a column in the GitHub UI needs no edit here.

An **empty** `board_<role>` means the board has no such column — that transition is
skipped, never failed. This is what lets ck-code drive a three-column board and a
five-column one with the same code.

## Role → column

| Role | Set when |
|---|---|
| `todo` | `status: todo` and every `blocked_by` story is `done` or `skip` |
| `in_progress` | `status: in-progress` |
| `in_review` | `ship` opened a PR — **sticky** (below) |
| `blocked` | `status: bug`, or any `blocked_by` story not yet done |
| `done` | `status: done` |
| *(archive)* | `status: skip`, when `board_archive_skip: true` |

An epic issue is placed by rollup over its non-`skip` stories: all `done` → `done`;
any `in-progress` or `bug` → `in_progress`; otherwise `todo`.

**Sticky In Review.** `in_review` is not derivable from frontmatter — a story is
`in-progress` whether or not its PR is open. So `ship` pushes the card with
`ck-project set <issue> in_review`, and `sync` will never move a card *out* of the
review column except to `done`. Without the sticky rule the next sync would drag an
open PR's card back to In Progress.

## Commands

```bash
ck-project discover                      # projects for the owner + current settings, as JSON
ck-project init --project 7              # adopt an existing board (never mutates it)
ck-project init --project 7 --extend     # adopt it AND add any missing preset columns
ck-project init --create "My Roadmap"    # create, link to the repo, provision 5 columns
ck-project sync [tasks/<slug>]           # reconcile every card
ck-project set <issue> in_review         # one-shot push
ck-project show                          # print resolved settings
```

`--dry-run` on `init` and `sync` prints every change and makes none.

## Adopting an existing board

`init --project N` reads the live single-select field and matches its option names
to roles case-insensitively (`*progress*` → `in_progress`, `*review*` → `in_review`,
`*block*|*bug*|*hold*` → `blocked`, …). A column one role claims is not offered to a
later role, and `*review*` is rejected for `todo`/`in_progress` first, so a
"Ready for review" column maps to `in_review` rather than to `todo`.

Unmatched roles are left empty — the board keeps its own shape and those transitions
are skipped. **An existing board is never mutated without `--extend`.**

## Provisioning a new board

`gh project create` yields a Status field with Todo / In Progress / Done. `--extend`
then issues one `updateProjectV2Field` mutation sending the **union** — every
existing option unchanged, then the missing preset ones — because that mutation
replaces the whole option set and sending only the new ones would delete the user's
columns. Option order is column order: Todo, In Progress, In Review, Blocked, Done.

## Rules

- **Never let a board failure block a commit, a build, or a status write** — the board is a view; frontmatter is the record. Surface the error and carry on.
- **Never mutate an existing board's columns without `--extend`** — the user's board shape is theirs, and `updateProjectV2Field` replaces the entire option set.
- **Never move a card by hand with `gh project item-edit`** — call `ck-project`, which resolves ids, honours the sticky rule, and skips no-op writes.
- **Never treat a missing column as an error** — an empty `board_<role>` is a supported configuration, not a misconfiguration.
- **Never write board state into story frontmatter** — the board is derived from it, never the reverse.
- **Always run `ck-project sync` in the same phase** as the `ck-index` that follows a status change, so the view and the board move together.
