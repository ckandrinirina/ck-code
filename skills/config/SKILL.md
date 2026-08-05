---
name: config
description: Use when setting up or changing this project's ck-code settings in `tasks/SETTINGS.md` — turning GitHub issue tracking on or off, setting the trunk branch every PR targets, picking or creating the GitHub Project whose board mirrors story status, re-mapping board columns after the board changes, or just showing what is currently configured. Argument is `show`, `board`, `trunk <branch>`, `on`, or `off`. Board work needs `gh` authenticated with the `project` scope.
argument-hint: "[show | board | trunk <branch> | on | off]"
effort: low
allowed-tools: Bash(ck-project*) Bash(ck-doctor*) Bash(gh auth status*) Bash(gh project list*) Bash(git rev-parse*) Read Edit Write
---

# Config — Project Settings & Board Mapping

Reads and writes `tasks/SETTINGS.md`, the per-project settings file. Today it holds
GitHub issue tracking and the Projects board mapping; it is the file future settings
land in too.

The board contract — the seven roles, adoption, provisioning, delivery reconciliation — is
defined once in [`github-projects.md`](../../references/github-projects.md). Follow it;
never restate it here.

## ROUTING CHECK (do first)

- Publishing a plan to GitHub Issues → `/ck-code:ship --to-issues` (it runs this
  setup itself on first use).
- A card in the wrong column → not a config problem. Run `ck-project sync`.
- Diagnosing a broken project → `/ck-code:doctor`.

## INPUT & MODE

Parse `$ARGUMENTS`:

- `show` (or empty) → **SHOW MODE**.
- `board` → **BOARD MODE**.
- `trunk <branch>` → **TRUNK MODE** (Phase 5).
- `on` / `off` → set `github_issues` and stop (Phase 4).

## PHASE 0: VERSION GATE

Layout stamp: !`cat "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tasks/VERSION.md" 2>/dev/null || echo "ABSENT — no tasks/VERSION.md"`

Reads `layout: v6` → PASS. Anything else → run the shared
[version gate](../../references/version-gate.md) (HARD GATE) before touching project state.

## SHOW MODE

```bash
ck-project show
```

Present the result as prose, then name what is unconfigured and the command that
fixes it. If the file does not exist, say so and offer BOARD MODE — do not write
a settings file the user did not ask for.

## BOARD MODE

### 1. Check the environment

```bash
gh auth status
```

The board needs the `project` scope. If it is missing, stop and tell the user to run
`gh auth refresh -s project` — do not attempt the setup without it.

### 2. Discover

```bash
ck-project discover
```

One call returns the repo, the owner, whether `tasks/SETTINGS.md` exists, its current
values, and every project the owner already has. **Never call `gh project list`
yourself** — this is that call.

### 3. Choose the project (ONE batched gate)

Ask **both** questions in a **single `AskUserQuestion` call**:

1. "Which GitHub Project should mirror story status?" — one option per existing
   project from step 2 (title + number), plus **Create a new one** and **None**
   (writes `github_issues: false` and stops).
2. "This board's columns?" — **Adapt to the board** (map ck-code roles onto whatever
   columns it already has, changing nothing) or **Add missing columns** (`--extend`).
   Only meaningful when an existing project was chosen; ignore the answer on
   **Create a new one**, which always provisions the full preset.

On **Create a new one**, propose a title from the plan's `PROJECT_OVERVIEW.md` `# `
heading, or the repo name.

### 4. Apply

```bash
ck-project init --project <N>              # adapt to the board as it is
ck-project init --project <N> --extend     # add the missing preset columns
ck-project init --project <N> --reorder    # rearrange the existing columns to the preset
ck-project init --create "<title>"         # create, link, provision all seven
```

The preset is seven columns in flow order: **Blocked · Todo · In Progress · Ready to Ship ·
In Review · Bugs · Done**. `--extend` appends missing ones at the *end* (it never disturbs
the user's order), so offer `--reorder` only when the user says the order bothers them —
it rewrites the whole option set and therefore re-syncs every card afterwards.

The command prints the resolved column per role and writes `tasks/SETTINGS.md`.
**Relay that mapping to the user verbatim** — a role showing "no column on this
board" is a transition that will be silently skipped forever, and this is the only
moment the user sees it.

### 5. Back-fill

Stories already carrying an `issue:` are not on the board yet, or sit in the wrong
column. Preview, then confirm:

```bash
ck-project sync --dry-run
```

Report the counts, then `AskUserQuestion` — "Apply these board changes?" **Sync**,
**Skip**. On **Sync**, run `ck-project sync`. A plan with many stories paces its calls;
say roughly how long before starting.

### 6. Recover delivery for work shipped before 6.4

Only when the dry run showed finished stories landing in **Ready to Ship** that the user
says are long since merged. They predate `pr:`, so nothing anchors their delivery:

```bash
ck-project backfill --dry-run
ck-project backfill
```

It asks GitHub which PR closed each linked issue and writes it back as `pr:`, then a sync
places the cards in Done. Stories with no `issue:`, or none GitHub can link, are listed and
skipped — those need `pr:` set by the next `ship`. Run it once per project.

## PHASE 4: TOGGLE (`on` / `off`)

Edit `github_issues` in `tasks/SETTINGS.md`. `off` leaves every other key intact, so
turning it back `on` restores the mapping without re-running BOARD MODE. Say which
commands go quiet: the board calls in `build` and `ship`.

## PHASE 5: TRUNK (`trunk <branch>`)

Set `trunk_branch:` in `tasks/SETTINGS.md` — the branch every PR targets and the one a
story must merge into to count as delivered
([`branch-topology.md`](../../references/branch-topology.md#resolution)). Set it when the
integration branch is not the repo default, e.g. a `develop` workflow; leaving it empty
keeps today's behaviour (repo default, `main` as fallback).

1. Verify the branch exists: `git rev-parse --verify --quiet "origin/<branch>"`. If it does
   not, say so and stop — a `trunk_branch` no branch matches makes every PR base wrong.
2. Write the key (create the file with `ck-project init` first if it is absent).
3. Say plainly what changed: new PRs target `<branch>`, `ship` stops asking about
   `main`/`develop`, and delivery now means "merged into `<branch>`".

**A change is not retroactive.** Stories already `delivery: merged` via the old trunk keep
that value; the next `ck-project sync` re-checks each PR against the *new* trunk and warns
about any that merged elsewhere. Say so before writing, so a surprise warning later reads
as expected.

## RULES

- **Never write `tasks/SETTINGS.md` by hand when `ck-project init` can write it** — the script resolves the project id, the field id and every option id in one pass; a hand-written file carries stale ids that only fail at the next sync.
- **Never call `gh project` directly** — `ck-project` is the only board interface ([github-projects.md](../../references/github-projects.md)).
- **Never mutate an existing board's columns without the user choosing "Add missing columns"** — adopting a board must leave it exactly as it was. `--reorder` is a separate, explicit ask; it never rides along with `--extend`.
- **Never set `trunk_branch` to a branch that does not exist** — verify with `git rev-parse` first; a wrong value silently mis-targets every future PR.
- **Never split the project choice and the column choice into two `AskUserQuestion` calls** — both are known at the same time; one call takes up to 4 questions.
- **Never run `ck-project sync` without showing `--dry-run` counts first** in this skill — the user is configuring, not shipping, and a first sync can move every card in the project.
- **Never enable `github_issues` without a resolvable project** — a `true` with no project makes every later board call fail noisily for no benefit.
- **Always relay the resolved role→column mapping**, including roles with no column.

## NEXT

Publish a plan to Issues with `/ck-code:ship --to-issues`. Check settings and the
rest of the project with `/ck-code:doctor`.
