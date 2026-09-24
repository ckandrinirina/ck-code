---
name: doctor
description: Use when checking a ck-code project for problems — a stale or newer layout stamp, unparseable story frontmatter, committed or stale views, unresolvable blocked_by dependencies, feature-doc slug drift, stale or invalid team skills, orphan epic branches, drifted spec metadata, or a missing ck-code-required guard. With `--fix`, also when a merged PR, a direct merge, a board card or a GitHub issue has drifted from the plan. Argument is an optional `tasks/<plan>` path, `--quiet` or `--fix`.
argument-hint: "[tasks/<plan>] [--quiet] [--fix]"
effort: low
model: haiku
allowed-tools: Bash(ck-doctor*) Bash(ck-project*) Bash(ck-story*) Bash(ck-index*) Bash(ck-bootstrap*) Bash(git status*) Bash(git add*) Bash(git commit*) Bash(git branch*) Bash(git rev-parse*) Bash(git ls-files*) Bash(gh auth status*) Bash(awk*) Bash(find*) Bash(grep*) Bash(ls*)
disallowed-tools: Write, Edit, NotebookEdit
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/no-ai-guard.sh"
---

# Doctor — Project Health Report (+ `--fix` Reconcile)

Reports what is broken in **this project**. Without `--fix` it writes nothing: every check
is a read, and the view-drift check regenerates into a throwaway copy rather than the
project. With `--fix` it also repairs the one class of drift it can repair safely — the
derived bookkeeping between the plan and GitHub — and commits the changed records.

The mechanical work lives in `scripts/ck-doctor.sh` and `ck-project` — this skill runs
them, then explains what each finding means and which command repairs it. Never
re-implement a check here in prose; the script is the single source of truth for what
"broken" means.

**CRITICAL RULE — No AI references in any artefact.** Full rule in
[`no-ai-references.md`](../../references/no-ai-references.md): no co-author tags, no
"Generated with…" lines, no Claude/AI/assistant mentions in the `--fix` commit or any
GitHub output. Absolute and non-overridable.

## INPUT & MODE

Parse `$ARGUMENTS`:

- A `tasks/<plan>` path → scopes the plan checks, and the `--fix` pass, to that plan.
- `--quiet` → the report drops its `OK` rows.
- `--fix` → **FIX MODE** after the report (Phase 3). Absent → read-only, Phases 1–2 only.

## VERSION GATE

Layout stamp: !`cat "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tasks/VERSION.md" 2>/dev/null || echo "ABSENT — no tasks/VERSION.md"`

- **No `--fix` — hint only.** Never block. The layout stamp is itself check 1 of the
  report, so an older or newer project is diagnosed rather than refused. On anything but
  `layout: v7`, print one hint line and continue read-only; never run Tier 2, never stamp.
- **`--fix` — hard gate.** Reads `layout: v7` → PASS. Anything else → run the shared
  [version gate](../../references/version-gate.md) (HARD GATE) before any write. The
  report (Phases 1–2) still runs first, since it writes nothing.

See [`version-gate.md`](../../references/version-gate.md#scope).

## PHASE 1: RUN

```bash
ck-doctor
```

Pass the `tasks/<plan>` path and `--quiet` through verbatim when present (never `--fix`,
which is this skill's flag, not the script's). Run it **once**; never loop it, and never
re-run a check by hand to "confirm" a finding.

If the script is missing or non-executable, say so and stop — do not fall back to
improvising the checks in prose, which is exactly the drift this skill exists to catch.

## PHASE 2: PRESENT

Return the script's output **verbatim** first — a summary would discard the report. Then
add the interpretation below.

Exit status is the verdict: `0` = healthy (warnings allowed), `1` = at least one ERROR.

### 2.1 What each finding means

| Row | Means | Fix |
|---|---|---|
| `layout` (ERROR) | the stamp is missing or older than v7 — every change-producing skill blocks | `/ck-code:migrate` |
| `layout` (ERROR, newer) | the stamp is newer than this plugin, or its `requires:` names a later ck-code — a newer layout can never be converted down | update the plugin: `/plugin update ck-code@ck-marketplace`. Never migrate |
| `team layout` (ERROR) | skills sit in nested `experts/`/`guides/` folders, so Claude Code registers none of them | `/ck-code:migrate` |
| `stories` (ERROR) | a story's frontmatter will not parse, or its status/size/delivery is outside the vocabulary. `delivery: pr`/`merged` with no `pr:` is the common one — nothing anchors it, so reconciliation can never re-check whether it merged. `delivery: direct` is the opposite case and legal with no `pr:` (it means no PR ever existed), but an ERROR *with* one | fix the frontmatter; `/ck-code:doctor --fix` recovers a missing `pr:` from the linked issue |
| `views` (ERROR, committed) | `STORIES_INDEX.md`/`EPICS_INDEX.md` (or a v6 `FEATURE_INDEX.md`) is tracked by git — a v6 leftover: every state change dirties the tree and parallel worktrees conflict on it | `/ck-code:migrate` |
| `views` (WARN) | `tasks/.gitignore` does not exclude the views, or a view is stale or missing. Stale is harmless — every reader regenerates it | `ck-index` |
| `epic ids` (ERROR) | the same epic number is used by more than one plan; branches and `blocked_by` are ambiguous | `/ck-code:migrate` (it renumbers) |
| `story ids` (ERROR) | one story id names two stories across plans — breaks `build EE-SS`, `blocked_by`, and branch names | `/ck-code:migrate` (it renumbers) |
| `plan overview` (ERROR) | an `epics/` dir has no `OVERVIEW.md`, so the plan is invisible to `ck-index` and `migrate` yet still feeds dependency checks | add the plan record; a v6 plan (`PROJECT_OVERVIEW.md`) → `/ck-code:migrate` |
| `plan naming` (WARN) | a hand-made plan folder name contains whitespace — `ck-issues`/`ck-project` silently skip spaced paths | rename to a hyphenated slug |
| `settings` (WARN) | `tasks/SETTINGS.md` has no frontmatter fence, issue tracking is on with no project configured, or the mapped board/columns are gone or unreachable | `/ck-code:config board` |
| `dependencies` (ERROR) | a `blocked_by` id resolves to nothing, a story blocks itself, there is a cycle, or a `done` story still depends on open work | fix `blocked_by` in the frontmatter |
| `feature docs` (WARN) | an epic slug has no `features/<slug>/index.md`, so its `EPICS_INDEX` `Docs` cell is `—` and `build` has no doc to read | `/ck-code:design sync` |
| `team skills` (ERROR) | a generated skill is invalid — folder and `name:` disagree, or its description holds a `: ` that silently drops all frontmatter | `/ck-code:team --refresh`, or fix the frontmatter |
| `team skills` (WARN) | none generated (OK when `tasks/SETTINGS.md` reads `experts: none`), or some were written against an older tech stack than `docs/architecture/` now describes | `/ck-code:team` (none) or `/ck-code:team --refresh` (stale — it regenerates only those, keeping MANUAL blocks) |
| `branches` (WARN) | an `epic/NN-*` branch has no matching epic folder, usually left by a rename | delete it once merged |
| `design system` (WARN) | a cached design-system card is missing or its content no longer matches the manifest digest, so `build` would copy markup that drifted from its source ([`design-system.md`](../../references/design-system.md)) | `/ck-code:design ds` |
| `spec metadata` (WARN) | a `docs/specs/*/.metadata.json` is not valid JSON, is missing a canonical key, carries a key no ck-code version writes, or has a `status` outside its enum — every reader of that file assumes one fixed shape | `/ck-code:spec <slug>` (its ADJUST pass rewrites the file canonically) |
| `design link` (WARN) | a Claude Design brief was handed out and never linked back, so UI stories are still building from improvised components | `/ck-code:design ds <url>` |
| `board` (WARN) | a Projects card sits in a column the story's `status:` + `delivery:` do not call for — someone dragged a card by hand, or a PR merged since the last reconcile ([`github-projects.md`](../../references/github-projects.md)) | `/ck-code:doctor --fix` |
| `bootstrap` (WARN) | `.claude/ck-code-required.sh` is missing, stale, or not wired into `.claude/settings.json` — so a clone of this repo on a machine without ck-code starts work with none of the `/ck-code:*` commands and no warning that they are gone | `ck-bootstrap install` |
| `bootstrap git` (WARN) | the guard is gitignored or uncommitted, so it protects only this machine — the one that already has the plugin | commit it; for a bare `.claude/` ignore rule the row prints the per-child replacement |
| `vendored copy` (WARN) | `.claude/skills/ck-code/` was left by the removed `vendor` skill. It loads as `ck-code@skills-dir`, a different plugin id from `ck-code@ck-marketplace`, so both run: every `/ck-code:*` command is listed twice and the vendored one never updates | delete the folder and its `ck-code@skills-dir` key, then `/plugin install ck-code@ck-marketplace` |
| `worktree` (WARN) | a gitignored `.env` exists but the project has no `.worktreeinclude`, so every `build` PARALLEL MODE worktree starts without it and its per-story QA fails for a reason unrelated to the story | list the file in `.worktreeinclude` (gitignore syntax; Claude Code copies it into each new worktree) |
| `rtk` | never an ERROR. `OK` covers both "wired" and "not installed" — [RTK](../../references/rtk.md) is optional and a project without it is healthy, just chattier. `WARN` means either RTK is installed with no `PreToolUse` hook (paid for, doing nothing) or a different tool named `rtk` is shadowing it on `PATH` | `rtk init` |

### 2.2 Report

Lead with the verdict in one line (`3 errors — this project will not build until they are
fixed`, or `Healthy — 2 warnings`). Then, **only for rows that are not OK**, give one
short paragraph each: what it means for the user's next command, and the exact command to
run. Order by severity, ERRORs first. Say nothing about OK rows beyond the table already
printed — a clean project deserves a short answer.

Without `--fix`, close with the single highest-value next command, never a list of every
fix at once. With `--fix`, go on to Phase 3.

## PHASE 3: FIX MODE (`--fix` only)

Nothing in ck-code observes a merge as it happens. `build`, `fix` and `ship` reconcile as a
side effect of their own job, so a project used normally stays correct — this pass is for
when it has not been: work merged in the browser, issues closed by hand, a story merged
straight to the trunk with no PR, a plan published after the fact, or a repo adopted from
someone else.

It writes only what is **derived**: `delivery:`/`pr:` from a PR number the plan already
holds or from git, the views, board columns, and GitHub issue state from the plan. It never
edits a story body, never sets `status:`, and never re-opens a closed issue. It repairs
none of the other findings — those keep the commands Phase 2 named.

The Phase 0 hard gate must have PASSed.

### 3.1 Preflight

```bash
gh auth status
ck-project show
```

`gh` missing or unauthenticated, or no `tasks/SETTINGS.md` / `github_issues` not `true` →
the pass still runs locally (delivery from git, views); say which GitHub steps are skipped.
Never stop the run over it.

### 3.2 Recover anchors, then reconcile

```bash
ck-project backfill [tasks/<plan>]      # pr: recoverable from a closed issue (needs gh)
ck-project reconcile [tasks/<plan>]     # landed + PR delivery + views + board + issues
```

`backfill` first: work finished before 6.4 has no `pr:`, and GitHub still knows which PR
closed its issue. Skip it when 3.1 found no `gh`. `reconcile` is the one full pass, in the
one order every caller uses: the provable direct landings and PR delivery, the views, the
board when there is one, then the issue repair when `github_issues: true` — closing a
delivered story's issue, ticking epic and plan checklists, and appending a missing
`Closes` footer to an open PR's body.

Report each script's own summary line. A failure in one is **never** fatal to the rest:
`ck-project` exits 1 when a `gh` call failed and still applies everything else, so relay
the failure and carry on. Relay every `WARN` — each names a file or issue the pass could
not fix.

### 3.3 Review the unproven landings (ONE multi-select)

```bash
ck-project landed [tasks/<plan>] --dry-run
```

`reconcile` already applied every `landed <id> → direct` line git can prove. What remains
are the `likely <id> …` lines — consistent with a direct merge, unprovable: the branch is
gone, or only the files are on the trunk, which is also true of files a later story created
([github-projects.md](../../references/github-projects.md#work-that-never-had-a-pr)).

None → skip to 3.4. Otherwise ask **one** `AskUserQuestion` call with `multiSelect: true`,
"These stories look merged into `<trunk>`, but git cannot prove it. Mark which as
delivered?" — one option per story, labelled with its id and the evidence, **none selected
by default**. More than four → spread them over up to four questions in the same call;
beyond sixteen, apply none and list them in the report instead.

Apply each selected story on its own — `--include-likely` would apply every likely line,
so it is never used here:

```bash
ck-story set <story-path> delivery=direct
```

When any was applied and `github_issues: true`, run `ck-project issues [tasks/<plan>]` once
so their issues close too.

### 3.4 Commit the records

```bash
git status --porcelain tasks/
```

Clean → say so and skip. Otherwise stage **only** the story, `EPIC.md` and `OVERVIEW.md`
files it lists — by name, never a view, never anything outside `tasks/` — and commit on
the current branch:

```bash
git add <changed story / EPIC.md / OVERVIEW.md paths>
git commit -m "chore(tasks): reconcile delivery with GitHub"
```

No PR, no branch, no prompt — every value written is derived from a PR number already in
the plan or from git ([`data-model.md`](../../references/data-model.md)). A tasks-only
commit is never read as a delivery by `ck-project landed`. On a protected branch
(`main`, `develop`) commit anyway — this is bookkeeping, not a change to review — and say
which branch it landed on.

### 3.5 Report

State what changed, then what could not be fixed automatically:

```
## Reconciled

Local     3 anchors recovered · 2 direct landings · 6 deliveries updated · 12 cards placed
GitHub    2 issues closed · 11 checklist items ticked · 1 PR footer repaired
Commit    <hash> on <branch>

## Still manual

- story 03-05 has no `issue:` — /ck-code:plan --publish tasks/<plan> publishes it
- PR #80 merged into `epic/04-instrument`, not `main` — not delivered until the epic PR lands
- story 02-07 left unconfirmed (its files are on `main`) — mark it with ck-story set … delivery=direct if it shipped
```

Name every `likely` story left unapplied: it is the one finding this pass cannot resolve on
its own, and the user is the only one who knows whether that work shipped. Nothing left to
do → say the project is in sync, in one line.

## RULES

- **Without `--fix`, never write, edit, or create any file** — including running `ck-index` against the project. The only permitted Bash call is `ck-doctor`, which is itself read-only.
- **Without `--fix`, never fix a finding** — report it and name the command. Repair belongs to `migrate`, `design`, `team`, `config`, a deliberate `ck-index` run, or `--fix`.
- **With `--fix`, repair only derived delivery, board and issue state** (Phase 3) — never `status:`, a story body, an acceptance criterion, or any other finding's cause.
- **Never mark a `likely` landing delivered without the user selecting it** (3.3) — the default is none, and `--include-likely` is never used.
- **Never re-open a closed issue, and never un-tick a checklist item** — frontmatter authorises closing, never the reverse.
- **Never overwrite a PR body** — `ck-project issues` appends missing `Closes` lines and leaves every existing one exactly as written.
- **Never stage a generated view or anything outside the story / `EPIC.md` / `OVERVIEW.md` files** (3.4) — the working tree may hold unrelated work, and the views are gitignored.
- **Never hand-drive the repair with per-issue `gh` calls or `gh project`** — `ck-project` batches the state lookup, paces the writes, and is the only board interface ([github-projects.md](../../references/github-projects.md)).
- **Never block on a GitHub failure** — report it and finish the local half.
- **Never call the `Skill` tool, and never edit a file directly** — doctor is a DIRECTIVE-tier skill, so it hands off with the `NEXT:` line; `--fix` writes only through `ck-project`, `ck-story` and `git`, which is why `Write`/`Edit` stay disallowed.
- **Always** end with one directive line and nothing after it, per
  [`skill-invocation.md`](../../references/skill-invocation.md) —
  `NEXT: /ck-code:<skill> <args>` for the **single most severe** finding that carries a
  repair command (after `--fix`: `/ck-code:plan --publish tasks/<plan>` when the report
  named entries with no `issue:`, else `/ck-code:track`). The main session offers it as a
  one-click run, so the user does not retype it. Emit none when the report is clean, and
  none when the top finding's repair is a plain shell command (`ck-index`) rather than a
  skill — print that command instead.
- **Never restate or re-derive a check in prose** — `ck-doctor` defines what is broken; this file only interprets its output.
- **Never summarise the script output away** — return it verbatim, then interpret.
- **Never treat a WARN as a blocker** — warnings are advisory; only an ERROR means the project is in a state a change-producing skill will trip over.
- **Always output in English.**

## NEXT

Fix the ERRORs in the order the report lists them, then re-run `/ck-code:doctor` to
confirm a clean bill. Delivery, board or issue drift → `/ck-code:doctor --fix`. With no
errors, `/ck-code:track next` picks the next story.
