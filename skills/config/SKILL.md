---
name: config
description: Use when setting up or changing ck-code project settings — turning GitHub issue tracking on or off, setting the trunk branch every PR targets, creating or adopting the GitHub Project board that mirrors story status, re-mapping board columns, changing how a plan's work merges (story, epic or plan level), turning the team-skills question back on, or showing what is configured. Argument is `show`, `board`, `trunk <branch>`, `integration <tasks/plan> <level>`, `experts ask|none`, `on`, or `off`.
argument-hint: "[show | board | trunk <branch> | integration <tasks/plan> <story|epic|plan> | experts ask|none | on | off]"
effort: low
allowed-tools: Bash(ck-project*) Bash(ck-plan*) Bash(ck-doctor*) Bash(ck-bootstrap*) Bash(gh auth status*) Bash(git rev-parse*) Bash(git ls-files*) Bash(awk*) Bash(find*) Bash(grep*) Bash(ls*) Read Edit Write Skill
---

# Config — Project Settings, Board & Integration Level

Reads and writes `tasks/SETTINGS.md`, the per-project settings file — GitHub issue
tracking, the trunk branch, the Projects board mapping, and `experts:` — and, through
`ck-plan set`, one plan record's integration level. It is the only skill that creates or
adopts a Projects board.

The board contract — the seven roles, adoption, provisioning, delivery reconciliation — is
defined once in [`github-projects.md`](../../references/github-projects.md). Follow it;
never restate it here.

## ROUTING CHECK (do first)

- Publishing a plan to GitHub Issues → `/ck-code:plan --publish` (it turns issue tracking
  on; the board stays here).
- A card in the wrong column, or a merged PR the plan does not show → not a config
  problem. Run `/ck-code:doctor --fix`.
- Diagnosing a broken project → `/ck-code:doctor`.

## INPUT & MODE

Parse `$ARGUMENTS`:

- `show` (or empty) → **SHOW MODE**.
- `board` → **BOARD MODE**.
- `trunk <branch>` → **TRUNK MODE** (Phase 5).
- `integration <tasks/plan> <story|epic|plan>` → **INTEGRATION MODE** (Phase 6).
- `experts ask` / `experts none` → **EXPERTS MODE** (Phase 7).
- `on` / `off` → set `github_issues` and stop (Phase 4).

## PHASE 0: VERSION GATE

Layout stamp: !`cat "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tasks/VERSION.md" 2>/dev/null || echo "ABSENT — no tasks/VERSION.md"`

Reads `layout: v7` → PASS. Anything else → run the shared
[version gate](../../references/version-gate.md) (HARD GATE) before touching project state.

## SHOW MODE

```bash
ck-project show
grep '^experts:' tasks/SETTINGS.md
find tasks -mindepth 2 -maxdepth 2 -name OVERVIEW.md
```

Then `ck-plan get tasks/<plan> integration branch` for each plan found. Present the result
as prose — settings, `experts:` (when `none`: "the team-skills question is off; `config
experts ask` turns it back on"), and each plan's integration level — then name what is
unconfigured and the command that fixes it. If `tasks/SETTINGS.md` does not exist, say so
and offer BOARD MODE — do not write a settings file the user did not ask for.

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
yourself** — this is that call. This mode is the only place a board is created or
adopted: `plan --publish` publishes issues and points here for the board.

### 3. Choose the project (ONE batched gate)

Ask **both** questions in a **single `AskUserQuestion` call**:

1. "Which GitHub Project should mirror story status?" — one option per existing
   project from step 2 (title + number), plus **Create a new one** and **None**
   (writes `github_issues: false` and stops).
2. "This board's columns?" — **Adapt to the board** (map ck-code roles onto whatever
   columns it already has, changing nothing) or **Add missing columns** (`--extend`).
   Only meaningful when an existing project was chosen; ignore the answer on
   **Create a new one**, which always provisions the full preset.

On **Create a new one**, propose a title from the newest plan's `OVERVIEW.md` `title:`, or
the repo name.

### 4. Apply

```bash
ck-project init --project <N>              # adapt to the board as it is
ck-project init --project <N> --extend     # add the missing preset columns
ck-project init --project <N> --reorder    # rearrange the existing columns to the preset
ck-project init --create "<title>"         # create, link, provision all seven
```

The preset column order is fixed
([`github-projects.md`](../../references/github-projects.md#role--column)). `--extend`
appends missing ones at the *end* (it never disturbs
the user's order), so offer `--reorder` only when the user says the order bothers them —
it rewrites the whole option set and therefore re-places every card afterwards.

The command prints the resolved column per role and writes `tasks/SETTINGS.md`.
**Relay that mapping to the user verbatim** — a role showing "no column on this
board" is a transition that will be silently skipped forever, and this is the only
moment the user sees it.

### 5. Preview

Stories already carrying an `issue:` are not on the board yet, or sit in the wrong
column. Preview the full reconcile first — this changes nothing:

```bash
ck-project reconcile --dry-run
```

### 5.1 Recover delivery for work shipped before 6.4 (BEFORE applying)

**Read the preview for stories moving *into* Ready to Ship.** Work merged before 6.4 has no
`pr:`, so it reads as "finished, never shipped" and the sync would move long-merged cards
out of Done — backwards, and visible to everyone watching the board. Recover the anchors
first:

```bash
ck-project backfill --dry-run
ck-project backfill
ck-project reconcile --dry-run     # re-preview: those cards should now say → Done
```

`backfill` asks GitHub which PR closed each linked issue and writes it back as `pr:`, then
resolves `delivery` from it. Stories with no `issue:`, or none GitHub can link, are listed
and skipped — those get `pr:` from their next `ship`. Run it once per project.

Work that never had a PR at all — merged to the trunk by hand — is invisible to `backfill`,
because there is no closing PR for GitHub to name. That is `landed`'s half of the same
repair, and the first sync of such a project would otherwise pile every one of those
stories into Ready to Ship:

```bash
ck-project landed --dry-run        # proven landings + the ones only you can confirm
ck-project landed                  # applies the proven half
```

Leave its `likely` lines alone here and name them in the report
([github-projects.md](../../references/github-projects.md#work-that-never-had-a-pr)) — that
tier is a guess, and applying it would move a card to Done and close an issue.
`/ck-code:doctor --fix` reviews them with the user.

Skip both sub-steps only when the preview moves nothing into Ready to Ship.

### 6. Apply

Report the counts from the latest preview, then `AskUserQuestion` — "Apply these board
changes?" **Apply**, **Skip**. On **Apply**, run `ck-project reconcile` — the one full pass
after every board change: delivery, views, cards, and the issue repair when
`github_issues: true`. A plan with many stories paces its calls; say roughly how long
before starting.

## PHASE 4: TOGGLE (`on` / `off`)

Edit `github_issues` in `tasks/SETTINGS.md`. `off` leaves every other key intact, so
turning it back `on` restores the mapping without re-running BOARD MODE. Say which
commands go quiet: the board and issue calls in `build`, `ship` and `doctor --fix`.
`on` with no board configured turns on issue reconciliation only; say so and offer
BOARD MODE.

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
that value; the next `ck-project reconcile` re-checks each PR against the *new* trunk and
warns about any that merged elsewhere. Say so before writing, so a surprise warning later
reads as expected.

## PHASE 6: INTEGRATION (`integration <tasks/plan> <story|epic|plan>`)

Changes how one plan's work is proposed for review
([`branch-topology.md`](../../references/branch-topology.md)). `plan` asked it once when
it created the plan; this is the only later way to change it.

1. Validate the plan path (it holds an `OVERVIEW.md`) and the level. Missing path with one
   plan in the project → use it and say so; several → ask which.
2. Read the current record: `ck-plan get tasks/<plan> integration branch`.
3. Write it through the record's one writer:

   ```bash
   ck-plan set tasks/<plan> integration=<level>
   ```

   At `plan` it also records `branch: plan/<slug>` when the field is empty; a migrated plan
   may keep `branch: feat/<slug>`, and the field wins.
4. Say plainly what changed and what did not. **A level change is not retroactive**: it
   applies from the next story onward, creates no branch and moves nothing. Stories already
   merged into an epic branch stay there; name any epic or story PR already open, since it
   keeps its base.

`OVERVIEW.md` is real state: it travels with the next commit, like any story file.

## PHASE 7: EXPERTS (`experts ask` / `experts none`)

`experts: none` in `tasks/SETTINGS.md` means the project runs without team skills, so the
build/fix team gate never asks ([`skill-detection.md`](../../references/skill-detection.md)).
`experts none` writes the key (create the file with a frontmatter fence if absent);
`experts ask` removes it, so the gate asks again the next time no team skills exist. Edit
only that key.

## RULES

- **Never write `tasks/SETTINGS.md` by hand when `ck-project init` can write it** — the script resolves the project id, the field id and every option id in one pass; a hand-written file carries stale ids that only fail at the next sync.
- **Never call `gh project` directly** — `ck-project` is the only board interface ([github-projects.md](../../references/github-projects.md)).
- **Never mutate an existing board's columns without the user choosing "Add missing columns"** — adopting a board must leave it exactly as it was. `--reorder` is a separate, explicit ask; it never rides along with `--extend`.
- **Never set `trunk_branch` to a branch that does not exist** — verify with `git rev-parse` first; a wrong value silently mis-targets every future PR.
- **Never split the project choice and the column choice into two `AskUserQuestion` calls** — both are known at the same time; one call takes up to 4 questions.
- **Never run `ck-project reconcile` without showing `--dry-run` counts first** in this skill — the user is configuring, not shipping, and a first reconcile can move every card in the project.
- **Always run `ck-project reconcile` after a board change** (step 6) — a new or re-mapped board is empty or stale until it runs.
- **Never apply a reconcile that moves cards into Ready to Ship before running `ck-project backfill`** (5.1) — pre-6.4 work has no `pr:`, so applying first drags long-merged cards out of Done in full view, then repairs them on a second pass.
- **Never apply `ck-project landed --include-likely` here** — the likely tier is a guess; `/ck-code:doctor --fix` confirms it with the user.
- **Never write the plan record by hand** — `ck-plan set` is its one writer (Phase 6).
- **Never treat an integration change as retroactive** — it applies from the next story onward and moves no branch.
- **Always relay the resolved role→column mapping**, including roles with no column.

## NEXT

After a board mapping is applied or re-mapped (BOARD MODE step 6), hand off to
`/ck-code:doctor` per [`skill-invocation.md`](../../references/skill-invocation.md) — one
question, no arguments — so the new mapping is verified immediately. Ask nothing in SHOW
mode, which changed nothing.

Publish a plan to Issues with `/ck-code:plan --publish`.
