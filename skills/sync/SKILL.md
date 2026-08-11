---
name: sync
description: Use when a ck-code project's bookkeeping has drifted from GitHub — a PR merged without the story showing it, a story merged straight to the trunk with no PR and stuck in Ready to Ship, a card in the wrong column, a delivered issue still open, an epic checklist with unticked merged stories, or a PR whose body closes nothing. Reconciles indexes, delivery, the board and GitHub Issues in one pass, then commits the result. Argument is an optional `tasks/<slug>` path.
argument-hint: "[tasks/<slug>] [--apply] [--dry-run] [--local]"
effort: low
allowed-tools: Bash(ck-index*) Bash(ck-project*) Bash(git status*) Bash(git add*) Bash(git commit*) Bash(git diff*) Bash(git rev-parse*) Bash(gh auth status*) Read Glob Skill
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/no-ai-guard.sh"
---

# Sync — Reconcile Everything With GitHub

Nothing in ck-code observes a merge as it happens. `build`, `fix` and `ship` each
reconcile as a side effect of doing their own job, so a project used normally stays
correct — this skill is for when it has not been: work merged in the browser, issues
closed by hand, a story merged straight to the trunk with no PR, a plan published after
the fact, or a repo adopted from someone else.

It writes only what is **derived**: `delivery:`/`pr:` from a PR number the plan already
holds, indexes from frontmatter, board columns from both, and GitHub state from the plan.
It never edits a story body, never sets `status:`, and never re-opens a closed issue.

**CRITICAL RULE — No AI references in any artefact.** Full rule in
[`no-ai-references.md`](../../references/no-ai-references.md): no co-author tags, no
"Generated with…" lines, no Claude/AI/assistant mentions in commits, issue comments, PR
bodies, or any GitHub output. Absolute and non-overridable.

## ROUTING CHECK (do first)

- Want to know what is *broken* without changing anything → `/ck-code:doctor` (read-only).
- Want to commit finished code and open a PR → `/ck-code:ship`.
- Want to change which board or trunk branch is used → `/ck-code:config`.

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).

## INPUT & MODE

Parse `$ARGUMENTS`:

- A `tasks/<slug>` path → scope every step to that plan. Absent → every plan.
- `--dry-run` → preview only; never apply, never commit, never ask.
- `--apply` → skip the confirm gate; apply everything.
- `--local` → Phases 1–2 and 5 only; make no GitHub write at all.
- No flag → preview, then **one** confirm (Phase 3).

## PHASE 0: VERSION GATE

Layout stamp: !`cat "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tasks/VERSION.md" 2>/dev/null || echo "ABSENT — no tasks/VERSION.md"`

Reads `layout: v6` → **PASS**. Anything else runs the shared
[version gate](../../references/version-gate.md) (HARD GATE). No `tasks/` at all → say so
and stop; there is nothing to reconcile.

## PHASE 1: PREFLIGHT

```bash
gh auth status
ck-project show
```

- `gh` missing or unauthenticated → run Phase 2 and 5 only (local reconcile still works),
  and say which steps were skipped.
- No `tasks/SETTINGS.md`, or `github_issues` not `true` → the same: local only. Point at
  `/ck-code:config` once, then continue. Never stop the run over it.

## PHASE 2: LOCAL RECONCILE (preview)

Three calls, in this order — each depends on the one before:

```bash
ck-project backfill --dry-run          # pr: recoverable from a closed issue
ck-project landed --dry-run            # work on the trunk that never had a PR
ck-project sync --dry-run              # delivery from GitHub + card placement
```

`backfill` first: it recovers the anchor that `sync` then resolves. `landed` next, for the
work that has no anchor to recover — a story merged to the trunk by hand. Add the plan path
to all three when one was given.

`ck-index` is not previewed — it is a pure function of frontmatter, so it runs in Phase 4
after the writes that feed it, and both scripts already call it themselves.

`landed` prints two kinds of line, and **they are not equivalent**
([github-projects.md](../../references/github-projects.md#work-that-never-had-a-pr)):

| Line | Means | Phase 4 |
|---|---|---|
| `landed <id> → direct` | git proves it: the trunk already carries that story as `done`, and it arrived with code | applies anyway, as part of `sync` |
| `likely <id> …` | consistent with a direct merge, unprovable — the branch is gone, or only the files are there | applied **only** if the user says so |

Collect for the report: every `pr` line from `backfill`, every `landed`/`likely` line, every
`anchor` and `delivery` line from `sync`, and the card counts.

## PHASE 3: GITHUB REPAIR (preview + the one confirm)

Skip the `issues` preview under `--local`, or when Phase 1 downgraded to local-only — but
still run the gate below when Phase 2 reported `likely` lines: those need an answer whether
or not GitHub is in play.

```bash
ck-project issues --dry-run
```

It reports, without changing anything:

| Line | Means |
|---|---|
| `close #N` | the story is `done` + `delivery: merged`/`direct` but its issue is still open — a closing keyword that never fired, or work that never had a PR to fire one |
| `tick #N` | an epic checklist still shows merged stories unchecked |
| `footer PR #N` | an **open** PR whose body names none of the issues it delivers, so merging it will close nothing |
| `no issue` | a story or epic with no `issue:` — it can never close; publish with `/ck-code:ship --to-issues` |

Then present the **whole** plan — Phase 2's local changes and Phase 3's GitHub repairs
together — and ask **once**. One `AskUserQuestion` call, two questions when Phase 2
reported `likely` lines, naming each story and the evidence behind it:

```
Q1: "Apply <N> local and <M> GitHub changes?"
    > Apply everything
      Local only          skip every GitHub write
      Abort

Q2: "<K> stor(ies) look merged into <trunk>, but git cannot prove it. Mark delivered?"
    > Leave them          they stay in Ready to Ship
      Mark them direct    moves the card to Done and closes the issue
```

Q2 appears **only** when there are `likely` lines, and its default is *Leave them* — a
wrong yes marks unshipped work delivered. Never ask it when there are none, and never fold
it into Q1: they are different risks and Q1's answer does not imply Q2's.

Under `--apply` do not ask, and treat Q2 as *Leave them* — `--apply` says "no questions",
not "assume the unprovable". Under `--dry-run` stop here: report and exit.

## PHASE 4: APPLY

Same order as the preview, dropping `--dry-run`:

```bash
ck-project backfill
ck-project landed [--include-likely]  # the flag ONLY if Q2 answered "Mark them direct"
ck-project sync                       # unless the answer was Local only
ck-project issues                     # unless the answer was Local only
ck-index                              # belt and braces: cheap, and pure
```

`landed` runs on **every** path, flag or not. `sync` applies the proven tier itself, but
`sync` needs a configured board and stops early without one — so in a local-only run it is
the only thing that records a direct landing at all.

Report each script's own summary line. A failure in one is **never** fatal to the rest:
`ck-project` exits 1 when a `gh` call failed and still applies everything else, so relay
the failure and carry on. Relay every `WARN` — each names a file or issue the run could
not fix.

## PHASE 5: COMMIT

```bash
git status --porcelain tasks/
```

Clean → say so and skip. Otherwise stage **only** `tasks/` and commit on the current
branch:

```bash
git add tasks/
git commit -m "chore(plan): reconcile delivery and indexes"
```

No PR, no branch, no prompt — every value written is derived from a PR number already in
the plan ([`data-model.md`](../../references/data-model.md)). Never stage source files:
this skill did not write any, and a dirty tree from other work is not its business.

**On a protected branch** (`main`, `develop`) commit anyway — this is bookkeeping, not a
change to review. Say which branch it landed on.

## PHASE 6: REPORT

State what changed, then what could not be fixed automatically:

```
## Synced

Local     3 anchors recovered · 2 direct landings · 6 deliveries updated · 12 cards placed
GitHub    2 issues closed · 11 checklist items ticked · 1 PR footer repaired
Commit    <hash> on <branch>

## Still manual

- story 03-05 has no `issue:` — run `/ck-code:ship --to-issues` to publish it
- PR #80 merged into `epic/04-instrument`, not `main` — not delivered until the epic PR lands
- story 02-07 may be on `main` already (its files are) — `ck-project landed --include-likely` if it is
```

Name every `likely` story left unapplied. It is the one finding this skill cannot resolve
on its own, and the user is the only one who knows whether that work shipped.

Close with the single highest-value next command. Nothing left to do → say the project is
in sync, in one line.

## RULES

- **Never reference AI, Claude, or generated-by notes** in any artefact — [full rule](../../references/no-ai-references.md).
- **Never write `status:`, a story body, or any acceptance criterion** — this skill reconciles derived state only. A story that is wrong about its own work is `/ck-code:build` or `/ck-code:fix`, not this.
- **Never re-open a closed issue, and never un-tick a checklist item** — frontmatter authorises closing, never the reverse. GitHub may know something the plan does not.
- **Never close an issue whose story is not both `status: done` and `delivery: merged` or `direct`** — `done` alone means finished, not shipped.
- **Never mark a `likely` landing delivered without the user's yes** (Phase 3 Q2) — `--apply` and `--local` both default it to *Leave them*. Git proves the certain tier; the rest is a guess with a card move and an issue closure behind it.
- **Never overwrite a PR body** — `ck-project issues` appends missing `Closes` lines and leaves every existing one exactly as written.
- **Never run a GitHub write without the Phase 3 confirm**, unless `--apply` was passed. `--dry-run` writes nothing at all, locally or remotely.
- **Never split the confirmation into two `AskUserQuestion` calls** — local and GitHub changes are known at the same time and go in one gate.
- **Never move a card with `gh project`** — `ck-project` is the only board interface ([github-projects.md](../../references/github-projects.md)).
- **Never hand-drive the repair with per-issue `gh` calls** — `ck-project issues` batches the state lookup, paces the writes, and matches checklist items by the token that cannot collide. Improvising it costs one call per story and mis-ticks acceptance criteria.
- **Never stage anything but `tasks/`** (Phase 5) — the working tree may hold unrelated work.
- **Never block on a GitHub failure** — report it and finish the local half.

## NEXT

`/ck-code:track` for the refreshed picture, `/ck-code:doctor` to confirm nothing is left
broken, or `/ck-code:ship --to-issues` when the report named entries with no `issue:`.
