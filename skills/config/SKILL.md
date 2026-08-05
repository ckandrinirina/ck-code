---
name: config
description: Use when setting up or changing this project's ck-code settings in `tasks/SETTINGS.md` — turning GitHub issue tracking on or off, picking or creating the GitHub Project whose board mirrors story status, re-mapping board columns after the board changes, or just showing what is currently configured. Argument is `show`, `board`, `on`, or `off`. Board work needs `gh` authenticated with the `project` scope.
argument-hint: "[show | board | on | off]"
effort: low
allowed-tools: Bash(ck-project*) Bash(ck-doctor*) Bash(gh auth status*) Bash(gh project list*) Read Edit Write
---

# Config — Project Settings & Board Mapping

Reads and writes `tasks/SETTINGS.md`, the per-project settings file. Today it holds
GitHub issue tracking and the Projects board mapping; it is the file future settings
land in too.

The board contract — roles, stickiness, adoption, provisioning — is defined once in
[`github-projects.md`](../../references/github-projects.md). Follow it; never restate it here.

## ROUTING CHECK (do first)

- Publishing a plan to GitHub Issues → `/ck-code:ship --to-issues` (it runs this
  setup itself on first use).
- A card in the wrong column → not a config problem. Run `ck-project sync`.
- Diagnosing a broken project → `/ck-code:doctor`.

## INPUT & MODE

Parse `$ARGUMENTS`:

- `show` (or empty) → **SHOW MODE**.
- `board` → **BOARD MODE**.
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
ck-project init --create "<title>"         # create, link, provision all five
```

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

## PHASE 4: TOGGLE (`on` / `off`)

Edit `github_issues` in `tasks/SETTINGS.md`. `off` leaves every other key intact, so
turning it back `on` restores the mapping without re-running BOARD MODE. Say which
commands go quiet: the board calls in `build` and `ship`.

## RULES

- **Never write `tasks/SETTINGS.md` by hand when `ck-project init` can write it** — the script resolves the project id, the field id and every option id in one pass; a hand-written file carries stale ids that only fail at the next sync.
- **Never call `gh project` directly** — `ck-project` is the only board interface ([github-projects.md](../../references/github-projects.md)).
- **Never mutate an existing board's columns without the user choosing "Add missing columns"** — adopting a board must leave it exactly as it was.
- **Never split the project choice and the column choice into two `AskUserQuestion` calls** — both are known at the same time; one call takes up to 4 questions.
- **Never run `ck-project sync` without showing `--dry-run` counts first** in this skill — the user is configuring, not shipping, and a first sync can move every card in the project.
- **Never enable `github_issues` without a resolvable project** — a `true` with no project makes every later board call fail noisily for no benefit.
- **Always relay the resolved role→column mapping**, including roles with no column.

## NEXT

Publish a plan to Issues with `/ck-code:ship --to-issues`. Check settings and the
rest of the project with `/ck-code:doctor`.
