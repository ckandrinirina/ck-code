---
name: ship
description: Use when finished work needs committing and its PR and linked GitHub Issue opened or updated after a story or fix — or for any standalone commit. `--promote` promotes a completed epic (its PR, or its merge into the plan branch) or opens the PR for a whole plan. Argument is an optional story path, or `--promote` with `--epic NN` or a `tasks/<plan>` path. Issue work needs `gh` authenticated.
argument-hint: "[path-to-story.md] | --promote [--epic NN | tasks/<plan>]"
effort: medium
allowed-tools: Bash(ck-story*) Bash(ck-plan*) Bash(ck-index*) Bash(ck-project*) Bash(ck-bootstrap*) Bash(git status*) Bash(git diff*) Bash(git log*) Bash(git show*) Bash(git branch*) Bash(git rev-parse*) Bash(git rev-list*) Bash(git symbolic-ref*) Bash(git ls-files*) Bash(git fetch*) Bash(git add*) Bash(git commit*) Bash(git checkout*) Bash(git merge*) Bash(git stash*) Bash(git push*) Bash(gh auth status*) Bash(gh repo view*) Bash(gh pr*) Bash(gh issue*) Bash(gh api*) Bash(awk*) Bash(find*) Bash(grep*) Bash(ls*) Skill
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/no-ai-guard.sh"
---

# Ship — Commit, PR & Issue Update

Ship delivers finished code: commit + PR + issue updates, and with `--promote` the
promotion of a finished epic or plan. GitHub-issue linkage is by the story/epic/plan frontmatter
`issue:` number (see [`data-model.md`](../../references/data-model.md)), never by matching
issue titles.

**CRITICAL RULE — No AI references in any artefact.** Full rule in [`no-ai-references.md`](../../references/no-ai-references.md): no co-author tags, no "Generated with…" lines, no Claude/AI/assistant mentions in commits, PRs, comments, branch names, or any GitHub output. Absolute and non-overridable.

References: [examples.md](references/examples.md) (worked ship walkthrough) · [pr-templates.md](references/pr-templates.md) (PR bodies + commands) · [issue-templates.md](references/issue-templates.md) (issue comments + checklist).

## ROUTING CHECK (do first)

This skill **commits finished work**, opens or updates a PR, and updates the linked
issue. If the request is actually something else, STOP and recommend the better skill:

- The story isn't implemented yet → `/ck-code:build` or `/ck-code:fix` first.
- Publishing the *plan* (not code) into GitHub Issues → `/ck-code:plan --publish`.
- Changing how a plan's work merges (story / epic / plan) → `/ck-code:config integration <tasks/plan> <level>`.

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:track next` or `/ck-code:explain`.

## INPUT & MODE

Parse `$ARGUMENTS`:

- Contains `--to-issues` or `--integration` → both left this skill in 7.0. Say where they
  went (`/ck-code:plan --publish`, `/ck-code:config integration <tasks/plan> <level>`) and
  stop.
- Contains `--promote` → **PROMOTE MODE** (§6.5 on demand). Also parse an optional
  `--epic NN` or `tasks/<plan>` path.
- Otherwise → **SHIP MODE** (default). `$ARGUMENTS` may be a story-file path:
  - **Provided** → read the story for its frontmatter `issue:` and context.
  - **Empty** → detect context from branch name or recent git activity; if none, run as a standalone commit (STANDALONE MODE).

## PROGRESS TRACKING

Open a `TodoWrite` list as the **first action of Phase 0** — one todo per phase this run will
actually execute — then flip each to `in_progress` when it starts and `completed` when its
gate passes. Drop a phase that mode routing skips; never leave it pending. A long run's only
view into where it is comes from this list, so update it as you go and never batch the
updates to the end.

## PHASE 0: VERSION GATE (hard gate — every mode)

The stamp is injected at skill-load time — **do not spend a `Read` on it**:

Layout stamp: !`cat "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tasks/VERSION.md" 2>/dev/null || echo "ABSENT — no tasks/VERSION.md"`

Reads `layout: v7` → **PASS**, proceed. Anything else (including `ABSENT`) → run the
shared [version gate](../../references/version-gate.md) (HARD GATE) — it detects an older
or newer layout, offers `/ck-code:migrate` or a plugin update, and stamps. Never read or
write project state before this PASSes.
**Exception:** a SHIP-MODE standalone commit in a repo with **no `tasks/` directory** is
not a ck-code project — skip the gate and do not stamp; just commit.

---

# SHIP MODE (default) — commit, PR, issue updates

## PHASE 1: BRANCH & PR CHECK

**Goal:** ensure work is on a work branch and detect any existing PR — never commit directly to `main` or `develop`.

### 1.1 Resolve current branch

```bash
git branch --show-current
```

- **Work branch** (`story/02-01-*`, `fix/02-01-*`, `epic/*`, `plan/*`, …): continue to 1.2.
- **Protected branch (`main`, `develop`, …):** STOP before staging. AskUserQuestion —
  "You are on a protected branch. How to proceed?" with options **Create branch**
  (propose `story/EE-SS-<slug>`, `fix/EE-SS-<slug>`, or `<type>/<slug>`), **Rename**
  (move current commits onto a new branch), **Abort** (stop; nothing is staged).
  On create/rename: `git checkout -b <branch-name>`. Applies to standalone commits too.
  **There is no "commit here" option** — the RULE below is absolute, so declining both
  moves leaves the work uncommitted rather than landing it on the trunk.

### 1.2 Detect existing PR for current branch

```bash
gh pr list --head "$(git branch --show-current)" --state open --json number,url,title,body
```

Store as `existing_pr`:

- **One open PR** → record `number,url,title,body`; Phase 5 reuses it (push + update).
- **No open PR** → Phase 5 runs the create flow.
- **Multiple** (rare) → show the list, ask which to update (or `NONE` to open new).

If `gh` is missing or unauthenticated, treat as "no existing PR" and continue.

### 1.3 Resolve branch topology (runs after 2.2)

It needs the story's plan, so run it once 2.2 has resolved the story and `tasks/<plan>/` —
never before. Read the plan record — the integration level is a **plan** property, never an
epic's:

```bash
ck-plan get tasks/<plan> integration branch
```

Empty `integration:` ≡ `story`. Then resolve `parent` and `pr_base` per
[`branch-topology.md`](../../references/branch-topology.md#resolution) — one call plus one
`git branch --list`. Do not restate the rule here.

At `story` the parent is the trunk and Phases 5–7 open one PR per story.
**STANDALONE MODE skips this step** — no story means no plan, so no topology.

## PHASE 2: GATHER CONTEXT

### 2.1 Check git state

```bash
git status
git diff --stat
git diff --staged --stat
git log --oneline -5
```

If clean and nothing staged: "Nothing to commit. Working tree is clean." → STOP.

### 2.2 Detect story context

Find the linked story in this order:

1. **`$ARGUMENTS`** — read the story file if a path was given.
2. **Branch name** — parse `story/EE-SS-*` or `fix/EE-SS-*`, then locate the story at
   `tasks/<plan>/epics/NN_*/stories/SS_*.md` (`NN`=`EE`, `SS`=story number).
3. **Recent files** — match modified files against story frontmatter `files:` lists.

If found, extract from frontmatter: `id` (EE-SS), `title`, `epic`, `status`, `issue`,
and the plan root `tasks/<plan>/`. From the body: acceptance criteria and the
Implementation Summary / Bug Resolution for the plain-language commit copy.

With the story and its plan resolved, run 1.3 now. No story found → STANDALONE MODE, and
1.3 never runs.

### 2.3 Resolve linked GitHub issues (by number — never by title)

- **Story issue:** the story frontmatter `issue:` number. Empty → no story issue linked;
  do commit + PR only and say so. Never search the repo by issue title.
- **Epic issue:** read the parent epic's `tasks/<plan>/epics/NN_*/EPIC.md` frontmatter
  `issue:` number. Empty → no epic checklist to update.

Store `story_issue` and `epic_issue` (both may be empty).

### 2.4 Read commit style

`git log --oneline -10` — match the repo's existing commit-message style.

### 2.5 Reconcile before staging (skip in STANDALONE MODE)

A PR merges on github.com with no skill running, so the `delivery: pr → merged` flip is
always discovered later. Run the one full pass **here**, before 3.1 picks files, and the
flip rides the commit this run was already making instead of needing a branch and PR of
its own:

```bash
ck-project reconcile tasks/<plan>
```

It runs with or without a board: delivery from recorded PRs and from git always, card
moves only when a board is configured, and the GitHub issue repair only when
`github_issues: true`. Never fatal: report a failure and continue to 3.1 — a board or a
network that is down must not block a commit.

The frontmatter it writes is derived: `delivery:`, and the `pr:` it materializes onto a
story that inherits its epic's or plan's PR. Both come from a PR number already in the
plan, so they need no confirmation of their own — 3.1 stages them and 3.3 shows them.

## PHASE 3: PREPARE COMMIT

### 3.1 Select files to stage (no prompt yet)

Run `git status`. **Auto-select** the story's modified/new source files, test files, the
story-file frontmatter change, and any story, `EPIC.md` or `OVERVIEW.md` file 2.5 just
rewrote — list those under a **Plan** group so the user sees plan bookkeeping travelling
with the code. The generated views (`STORIES_INDEX.md`, `EPICS_INDEX.md`) are gitignored
and never staged.

**Never stage a likely secret or local noise.** Move each to an **Excluded** group with
its reason: `.env*` (except `*.example`), `*.pem`, `*.key`, `id_rsa*`, `credentials*`
("likely secret"), and `.DS_Store` or IDE config ("local noise"). Build the grouped lists
(Source / Tests / Docs / Plan / Excluded) but do **not** ask yet — 3.3 confirms the file
set, the message and the PR in one round-trip.

**When 2.5's flip is the *only* change** (a merge landed, no code in flight), there is
nothing to ride along. Do not open a PR for it: offer a single commit on the current branch
— `chore(plan): record merged delivery` — then go to Phase 6. Bookkeeping derived from an
already-merged PR never needs review.

### 3.2 Craft commit message

Subject stays in **conventional commits** (`feat`, `fix`, `refactor`, `test`, `docs`,
`chore`, `style`, `perf`). Body is plain language for non-engineers.

- **Subject:** `<type>(<scope>): <imperative summary, ≤70 chars>`
- **Body:** what users can now do, see, or notice. No story IDs, epic names, AC counts,
  test tallies, class/function names, or file paths.
- **Footer:** the output of `ck-project closes <story-path>` when a story issue is linked
  (5.B step 4) — never typed by hand.

Full templates: [examples.md](references/examples.md).

### 3.3 The one confirmation (files + message + PR)

**Resolve the PR base first — never ask for it.** `<trunk>` is resolved exactly as
[`branch-topology.md`](../../references/branch-topology.md#resolution) orders it
(`trunk_branch` → `origin/HEAD` → the `gh` repo default → `main`); do not restate it. At
level `epic`/`plan` the story's target is `parent` (1.3), not the trunk.

Show a preview — Branch / Files grouped per 3.1 (Excluded with reasons) / full Message /
Linked issues — then ask **one** `AskUserQuestion`, "Ship this?":

1. **(Recommended)** at level `story`: `Commit and open a PR into <trunk>` — or
   `Commit, push and update PR #<n>` when 1.2 found one. At level `epic`/`plan`:
   `Commit and merge into <parent>`.
2. `Commit only` — the work stays on this branch.
3. `Edit the message`
4. `Abort`

A change to the file set comes back as the free-text answer: apply it, show the new
preview, and re-ask the same question once. **Edit the message** does the same for the
message. At level `epic`/`plan` a free-text answer may also ask for a story PR into
`<parent>` instead of the merge (5.B with `--base <parent>`, keeping the story branch). The
happy path costs one round-trip.

Only with no `trunk_branch`, a `develop` branch present, and a default that is not
`develop` (`git rev-parse --verify --quiet origin/develop`) is the PR base genuinely
ambiguous — then add a **second question to the same call** ("PR base?" `<default>` /
`develop`) and suggest setting `trunk_branch` via `/ck-code:config trunk <branch>` so it
never returns. Never a second call.

## PHASE 4: COMMIT

### 4.1 Execute

```bash
git add <specific files>
git commit -m "<message>"
```

Multi-line messages use a HEREDOC — see [examples.md](references/examples.md).

### 4.2 Verify

```bash
git log --oneline -1
git show --stat HEAD
```

Present hash, branch, file count, first message line.

## PHASE 5: PR (CREATE OR UPDATE)

### 5.1 Route by the 3.3 answer

- **Commit only** → Phase 6.
- **Commit and open a PR** → 5.B. **Commit, push and update PR #n** → 5.A.
- **Commit and merge into `<parent>`** (level `epic`/`plan`) → the story merge in
  [`branch-topology.md`](../../references/branch-topology.md#story-merge): commands, the
  clean-tree guard and the conflict path — follow it exactly; do not improvise a merge
  here. An existing open PR for the story branch still routes to 5.A, whose base is
  already fixed.

### 5.A Update existing PR

1. `git push origin "$(git branch --show-current)"`.
2. Record the pointer when the story does not already carry it — a PR opened by hand, or
   before this step existed, still needs `pr:` or the story can never reach Done:

   ```bash
   ck-story set <story-path> pr=<n> delivery=pr
   ```

   One call writes both fields, regenerates the views and syncs the card. Re-running it when
   they already read that is harmless — it reports `already current — no change`.
3. Read `existing_pr.body` and append under a `## Updates` section (create it if absent):
   `- <YYYY-MM-DD>: <commit subject> — <one-line plain-language summary>`.
3b. **Repair a missing `Closes` footer in the same edit.** Run `ck-project closes` for this
   PR's level and add any line the body does not already contain, as its last block. A PR
   opened by hand, or before the footer was generated, closes nothing on merge — and this
   is the last moment ship can still fix that. Never remove a `Closes` line already there.

   Write the **merged** body back — never overwrite prior content:
   ```bash
   gh pr edit <pr-number> --body "$(cat <<'EOF'
   <merged body>
   EOF
   )"
   ```
   Content rules identical to 3.2.

### 5.B Create new PR

1. The base is the one 3.3 resolved and the user approved — never ask again.
2. `git push -u origin <branch-name>`.
3. PR title = commit first line (≤70 chars). PR body is plain language for non-engineers
   — no story IDs, AC checkboxes, or test tallies. Bodies (new behaviour / bug fix) + the
   exact `gh pr create` command + post-create output: [pr-templates.md](references/pr-templates.md).
4. **The `Closes` footer is generated, never written by hand** — GitHub closes an issue on
   merge only when the PR body names it, and an author-composed footer is exactly what let
   a promotion PR close every issue once, all but the epic issue the next time, and none
   the time after:

   ```bash
   ck-project closes <story-path>
   ```

   Paste its stdout verbatim as the body's last block. Empty output is a valid answer (no
   footer); relay any `WARN` — it names an entry that will **not** close on merge. Argument
   forms per PR level and the merge caveats: [pr-templates.md](references/pr-templates.md#the-closes-footer).
5. **Record the PR in frontmatter — this is what moves the card.**

   ```bash
   ck-story set <story-path> pr=<the new PR number> delivery=pr
   ```

   Leave `status` alone; the two axes are independent
   ([`data-model.md`](../../references/data-model.md#two-axes-status-is-work-delivery-is-integration)),
   and `ck-story` regenerates the views and syncs the card in the same call. In Review is
   derived from `delivery: pr` like every other column; there is no command that pushes a
   card there by hand. A story whose PR is never recorded here is stranded in *Ready to
   Ship* forever.

   A story PR opened into `<parent>` at level `epic`/`plan` (the free-text choice in 3.3)
   records nothing: it never reaches the trunk, and the epic or plan PR is the anchor its
   stories inherit (§6.5).

## PHASE 6: MARK DONE & UPDATE ISSUES

### 6.1 Mark the story done (frontmatter is the source of truth)

**Skip the status write when the frontmatter already reads `status: done`** —
`/ck-code:build` Phase 8.6 flips it before invoking this skill; a second flip is duplicate
work. Otherwise flip it **only when both of these hold in the story file** — there is no
judgment call here:

1. every acceptance criterion in the body is checked `[x]`, and
2. the body carries the record of a passed manual-test gate (build 8.5) — an
   `## Implementation Summary`, or a Bug Report `### Resolution` at `Status: FIXED`.

```bash
ck-story set <story-path> status=done
```

**A story this run only *inferred*** — matched from the branch name or the touched files at
2.2 steps 2–3 rather than given as `$ARGUMENTS` — **never flips**, even when both conditions
read true. An inferred link is a guess about which story the commit belongs to; say which
story was inferred in Phase 7 and leave its `status` untouched.

Never cell-edit a view or flip an EPIC checkbox for status.

`ck-story` regenerates the views and syncs the card on every call, so there is nothing
else to run after it. The sync places the card from both axes: `done` + `delivery: pr` is
In Review, and it becomes Done by itself once the PR merges and a later reconcile re-asks
GitHub ([`github-projects.md`](../../references/github-projects.md)). Nothing here needs to
predict the merge.

If the story is not yet fully done, leave `status` as is and skip issue-close steps.

### 6.2 Update the story issue (only if `story_issue` is set)

Resolve by the `story_issue` number from 2.3. Templates: [issue-templates.md](references/issue-templates.md).

- **New PR (5.B):** `gh issue comment <story_issue>` with the PR number + a 1–2 sentence
  plain-language summary. No AC lists, no test counts.
- **Existing PR updated (5.A):** `gh issue comment <story_issue>` noting the new commit
  hash + summary; don't repeat the PR number if already posted.
- **Commit only, or merged into `<parent>`:** `gh issue comment <story_issue>` with the
  commit hash + summary. Never `gh issue close` here — an issue closes through the
  `Closes #` footer of a merging PR (or `ck-project reconcile` once the work is
  delivered), and Phase 1.1 guarantees the commit is not on a protected branch anyway.

### 6.3 Update the epic issue checklist (only if `epic_issue` is set)

Resolve the epic issue by the `epic_issue` number from 2.3 (never by title):

```bash
gh issue view <epic_issue> --json body -q .body
```

Flip this story's checklist item to `[x]`, then `gh issue edit <epic_issue> --body "<updated>"`.
Match the item exactly: `#<story_issue>` when a story issue exists, else the bracketed
padded token `[EE-SS]` (e.g. `[02-01]`, which never collides with `[02-10]`).

### 6.4 Labels — none

Ship adds no status labels. Native sub-issues and the board carry status; a label would be
a third copy that drifts.

### 6.5 Promotion gate (levels `epic` and `plan` only)

Runs at the end of Phase 6 regardless of whether 6.1 did any work — 6.1 is **skipped** on the
normal path (`/ck-code:build` Phase 8.6 already flipped the status), so this gate keys off
project *state*, never off 6.1 having acted. Skip entirely at level `story`, and skip when
6.1 determined the story is not yet fully done.

**Detect from story frontmatter, never from a view cell:** the epic has reached DONE when
every non-`skip` story of epic `NN` reads `status: done`. Fire the gate only on the ship run
that completes the epic — if the epic was already DONE and already promoted, say nothing.

Then run the **epic gate**, and — at level `plan`, when its condition holds — the **plan
gate**, both defined with their staleness handling in
[`branch-topology.md`](../../references/branch-topology.md#promotion):

- **Level `epic`** — the epic PR goes `epic/NN-<slug>` → trunk.
- **Level `plan`** — an epic gets **no PR of its own**: promoting it merges
  `epic/NN-<slug>` into the plan record's `branch:` locally with `--no-ff` (the Story-merge
  guard and abort path) and pushes the plan branch. The plan PR, plan branch → trunk, is
  the one review. An epic PR into the plan branch would strand every story at
  `delivery: pr` — stories inherit the epic's `pr:` before the plan's, and only a PR merged
  into the trunk counts as delivered.

**A promotion PR records its number, on the record its stories inherit through:**

| PR | Record | Write |
|---|---|---|
| epic PR → trunk (level `epic`) | that `EPIC.md` | `pr: <n>` + `delivery: pr` (frontmatter edit) |
| plan PR → trunk (level `plan`) | `OVERVIEW.md` | `ck-plan set tasks/<plan> pr=<n> delivery=pr` |

Their stories inherit that pointer (story → epic → plan), which is the only way work
shipped through an epic or plan PR ever reaches Done.

Then **run `ck-project sync tasks/<plan>` again, in this phase** — the reconcile at 2.5 ran
before the record write and cannot have seen it. This second pass pushes the new `pr:` down
onto every story it covers, so no story is left with a `delivery:` and no anchor.

Its body takes the generated footer for the whole epic or plan — one call, not a
story-by-story guess:

```bash
ck-project closes tasks/<plan>/epics/NN_<slug>     # epic PR
ck-project closes tasks/<plan>                     # plan PR (emits only at integration: plan)
```

Declining is never a dead end — **Not yet** points at `/ck-code:ship --promote --epic NN`
(or `--promote tasks/<plan>`).

### 6.6 Commit the plan state onto the branch

6.1 and 6.5 wrote frontmatter, so `tasks/` may be dirty again after the Phase 4 commit:

```bash
git status --porcelain tasks/
```

Clean → nothing to do. Otherwise stage **only** the story, `EPIC.md` and `OVERVIEW.md`
files it lists — by name, never a view — and commit them **on the current branch**, saying
so:

```bash
git add <changed story / EPIC.md / OVERVIEW.md paths>
git commit -m "chore(plan): record delivery pointers"
```

No PR, no confirmation, no branch — every one of these values is derived from a PR number
the plan already holds. When 6.5 just opened a promotion PR, `git push` after this so the
pointers travel *inside* that PR rather than becoming a chore PR against the trunk later.

Skip this step in STANDALONE MODE (no `tasks/` writes) and when the repo has no `tasks/`.

## PHASE 7: SUMMARY

Present: Commit (hash/branch/message), PR (url/status), Issues updated (story #, epic #),
Story (status + delivery/path), Next steps. State the delivery plainly — "in review, not
yet on `<trunk>`" — so "done" is never mistaken for "shipped"; it turns to `merged` on the
first reconcile after the PR lands. Worked shape: [examples.md](references/examples.md).

- More stories remain → suggest `/ck-code:track next` then `/ck-code:build`.
- Epic complete → note the epic issue can be closed manually or auto-closes once all its
  checkboxes are checked.
- Merged story branches were already deleted at merge time. Remind the user only about
  branches ship cannot clean: a story branch with an **open** PR, and the epic or plan
  branch once its PR merges ([`branch-topology.md`](../../references/branch-topology.md#cleanup)).

## STANDALONE MODE (no story)

1. Show `git diff --stat` and `git status`.
2. AskUserQuestion — change type (feat/fix/refactor/…).
3. Ask for a brief description.
4. Craft a conventional commit message (plain-language body).
5. The same one confirmation as 3.3 (secret exclusion included), then commit and
   optionally open the PR (Phase 5).
6. No issue updates and no frontmatter changes (no story to link).

## PROMOTE MODE (`--promote`)

Runs the §6.5 gates on demand so **Not yet** is never a dead end. Uses the *promotable*
definition in [`branch-topology.md`](../../references/branch-topology.md#promotion).
Resolution order:

1. `--epic NN` given → promote that epic; if it is not promotable, say why and stop.
2. A `tasks/<plan>` path given → run the plan gate for that plan; the plan must be at
   `integration: plan` (`ck-plan get tasks/<plan> integration branch`), else say so and
   stop.
3. Exactly one promotable epic → use it, announcing which.
4. Several → `AskUserQuestion` which one.
5. None promotable but a plan-gate condition holds → run the plan gate.
6. Otherwise → report that there is nothing to promote, and why.

No staging of source, and no *authored* story change — this mode only promotes branches.
The writes it does make are all derived: a promotion PR records its `pr:` + `delivery: pr`
on `EPIC.md` or, for the plan PR, on `OVERVIEW.md` through `ck-plan set` (§6.5); then
`ck-project sync` materializes that anchor down onto the stories, and §6.6 commits the
result onto the branch so it rides the promotion PR. Run §6.5 then §6.6; skip every other
phase.

---

## RULES

- **Never reference AI, Claude, or generated-by notes** in any artefact — [full rule](../../references/no-ai-references.md).
- **Never resolve a GitHub issue by matching its title** — resolve by the frontmatter `issue:` number (story) or `EPIC.md` `issue:` (epic). No `contains("[EE-SS]")` title search.
- **Never store story status anywhere but frontmatter** — `ck-story set <story-path> status=done`; never cell-edit a view or flip an EPIC checkbox for status.
- **Never open or update a PR without recording `pr:` + `delivery: pr`** on the record its stories inherit through — the story, the `EPIC.md` for an epic PR into the trunk, or `OVERVIEW.md` (`ck-plan set`) for a plan PR (§6.5). An unrecorded PR strands the story in Ready to Ship, and `ck-project sync` has no anchor to re-check. The one exception is a story PR into `<parent>`, which never reaches the trunk and is anchored by the epic or plan PR.
- **Never write the plan record by hand** — `ck-plan set` is its one writer.
- **Never write `delivery: merged` by hand** — only `ck-project sync` (inside `reconcile`) promotes it, from GitHub's answer about the PR.
- **Never compose a `Closes #` footer by hand** — run `ck-project closes <story|epic-dir|plan-dir>` and paste its output. GitHub closes an issue on merge only when the PR body names it, and a hand-written footer silently omits the epic issue, or every issue.
- **Never open an epic PR at level `plan`** — the epic merges into the plan branch and the plan PR is the one review (§6.5).
- **Never open a promotion PR without re-running `ck-project sync` after recording its `pr:`** (§6.5) — the sync is what materializes the anchor onto the stories; without it they carry a `delivery:` with no `pr:`, which `ck-doctor` reports as an ERROR.
- **Always commit dirty story / `EPIC.md` / `OVERVIEW.md` files before finishing** (§6.6) — plan bookkeeping is derived from PR numbers already in the plan, so it belongs on the current branch with no PR and no prompt. Leaving it uncommitted is what forces a hand-made "record merged delivery" PR later.
- **Never stage or commit a generated view** — `STORIES_INDEX.md` and `EPICS_INDEX.md` are gitignored and regenerated on every read.
- **Never open a PR whose only content is a `delivery:`/`pr:` change** — it is derived state; commit it on the current branch (§3.1, §6.6).
- **Always relay `ck-index: WARN` lines** — a skipped story is invisible in every generated view while its file still exists ([stories-index.md](../../references/stories-index.md)).
- **Never commit directly to `main` or `develop`** (Phase 1).
- **Never ask the user for the PR base branch** — derive it from `trunk_branch` and the plan's `integration:` level via [`branch-topology.md`](../../references/branch-topology.md#resolution); fold a second question into the 3.3 call only on a genuine `main`/`develop` ambiguity with no `trunk_branch` set.
- **Never restate the branch-topology rule** in this file — link to [`branch-topology.md`](../../references/branch-topology.md). One definition, several consumers.
- **Never merge without the clean-tree guard**, and never leave a merge half-applied — `git merge --abort`, return to the story branch, report the conflicting paths, and stop.
- **Never auto-open a promotion PR** — §6.5 always confirms, and a level change is never retroactive.
- **Never ask more than the one 3.3 confirmation** for stage + commit + PR — `AskUserQuestion` takes up to 4 questions per call, and each extra call is a full round-trip.
- **Never `git add -A` or `git add .`** — stage files by name; never stage `.env*` (except `*.example`), `*.pem`, `*.key`, `id_rsa*` or `credentials*` — list each as Excluded with the reason.
- **Never mention story IDs, epic names, AC checklists, test counts, or file paths** in a commit body, PR body, or issue comment — they are plain-language, read by non-engineers.
- **Never overwrite a PR description** — append beneath the existing body and prior `## Updates` entries.
- **Never open a second PR for a branch** that already has an open one (Phase 1.2).
- **Never block the commit on GitHub failures** — if `gh` is missing, unauthenticated, or a lookup returns nothing, surface it and continue commit-only. This covers the board too: a failed `ck-project` call is reported, never fatal.
- **Never move a board card with `gh project`** — call `ck-project`, the only board interface ([github-projects.md](../../references/github-projects.md)).
- **Never publish a plan or change an integration level here** — `/ck-code:plan --publish` and `/ck-code:config integration` own those.
- **Always close issues with a `Closes #X` footer**, and only when the work is complete.

## NEXT

If more stories are ready, run `/ck-code:track next`. To explain what was just built
(verification commands + walkthrough), run `/ck-code:explain`. For a deeper pre-PR pass,
native `/code-review` (or `/code-review --fix`) reviews the diff before this skill opens
the PR — see [native-commands.md](../../references/native-commands.md).
