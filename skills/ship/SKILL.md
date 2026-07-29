---
name: ship
description: Use to commit finished work, open or update a PR, and update the linked GitHub Issue after a story or fix is complete — or for any standalone commit. With `--to-issues [--mode feature|epics|stories]`, instead publishes a `tasks/` plan to GitHub Issues at feature, epic, or story granularity and writes each new issue number back into story/epic frontmatter. Argument is an optional story path (default) or a `tasks/<slug>/` path (`--to-issues`). Issue work needs `gh` authenticated.
argument-hint: "[path-to-story.md] | --to-issues [tasks-folder] [--mode feature|epics|stories]"
effort: medium
---

# Ship — Commit, PR, Issue Update & Plan Publishing

Ship delivers finished code (commit + PR + issue updates), and — in `--to-issues`
mode — publishes a `tasks/` plan to GitHub Issues. GitHub-issue linkage is by the
story/epic frontmatter `issue:` number (see [`data-model.md`](../../references/data-model.md)),
never by matching issue titles.

**CRITICAL RULE — No AI references in any artefact.** Full rule in [`no-ai-references.md`](../../references/no-ai-references.md): no co-author tags, no "Generated with…" lines, no Claude/AI/assistant mentions in commits, PRs, comments, branch names, or any GitHub output. Absolute and non-overridable.

References: [examples.md](references/examples.md) (worked ship walkthrough) · [pr-templates.md](references/pr-templates.md) (PR bodies + commands) · [issue-templates.md](references/issue-templates.md) (issue comment/close/checklist) · [issue-bodies.md](references/issue-bodies.md) (`--to-issues` issue-body templates per mode).

## ROUTING CHECK (do first)

- The story isn't implemented yet → `/ck-code:build` or `/ck-code:fix` first.
- Publishing the *plan* (not code) into GitHub Issues → this skill's `--to-issues` mode.

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:track next` or `/ck-code:explain`.

## INPUT & MODE

Parse `$ARGUMENTS`:

- Contains `--to-issues` → **PUBLISH MODE** (bottom half of this file). Also parse an
  optional `tasks/<slug>/` path and `--mode feature|epics|stories` (any order).
- Otherwise → **SHIP MODE** (default). `$ARGUMENTS` may be a story-file path:
  - **Provided** → read the story for its frontmatter `issue:` and context.
  - **Empty** → detect context from branch name or recent git activity; if none, run as a standalone commit (STANDALONE MODE).

## PHASE 0: VERSION GATE (hard gate — both modes)

Read `tasks/VERSION.md`. If it exists and `layout: v4` → **PASS**, proceed. If missing
or not `v4` → open the shared [version gate](../../references/version-gate.md) and run
Tier 2 (HARD GATE): it detects a pre-v4 layout, offers `/ck-code:migrate`, and stamps.
**Exception:** a SHIP-MODE standalone commit in a repo with **no `tasks/` directory** is
not a ck-code project — skip the gate and do not stamp; just commit.

---

# SHIP MODE (default) — commit, PR, issue updates

## PHASE 1: BRANCH & PR CHECK

**Goal:** ensure work is on a feature branch and detect any existing PR — never commit directly to `main` or `develop`.

### 1.1 Resolve current branch

```bash
git branch --show-current
```

- **Feature branch** (`story/02-01-*`, `fix/02-01-*`, `feat/*`, …): continue to 1.2.
- **Protected branch (`main`, `develop`, …):** STOP before staging. AskUserQuestion —
  "You are on a protected branch. How to proceed?" with options **Create branch**
  (propose `story/EE-SS-<slug>`, `fix/EE-SS-<slug>`, or `<type>/<slug>`), **Rename**
  (move current commits onto a new branch), **Commit here** (warn: not recommended).
  On create/rename: `git checkout -b <branch-name>`. Applies to standalone commits too.

### 1.2 Detect existing PR for current branch

```bash
gh pr list --head "$(git branch --show-current)" --state open --json number,url,title,body
```

Store as `existing_pr`:

- **One open PR** → record `number,url,title,body`; Phase 5 reuses it (push + update).
- **No open PR** → Phase 5 runs the create flow.
- **Multiple** (rare) → show the list, ask which to update (or `NONE` to open new).

If `gh` is missing or unauthenticated, treat as "no existing PR" and continue.

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
   `tasks/<slug>/epics/NN_*/stories/SS_*.md` (`NN`=`EE`, `SS`=story number).
3. **Recent files** — match modified files against story frontmatter `files:` lists.

If found, extract from frontmatter: `id` (EE-SS), `title`, `epic`, `status`, `issue`,
and the plan root `tasks/<slug>/`. From the body: acceptance criteria and the
Implementation Summary / Bug Resolution for the plain-language commit copy.

### 2.3 Resolve linked GitHub issues (by number — never by title)

- **Story issue:** the story frontmatter `issue:` number. Empty → no story issue linked;
  do commit + PR only and say so. Never search the repo by issue title.
- **Epic issue:** read the parent epic's `tasks/<slug>/epics/NN_*/EPIC.md` frontmatter
  `issue:` number. Empty → no epic checklist to update.

Store `story_issue` and `epic_issue` (both may be empty).

### 2.4 Read commit style

`git log --oneline -10` — match the repo's existing commit-message style.

## PHASE 3: PREPARE COMMIT

### 3.1 Select files to stage (no prompt yet)

Run `git status`. **Auto-select** the story's modified/new source files, test files, and
the story-file frontmatter change. **Never stage** `.env`, credentials, secrets,
`.DS_Store`, or IDE configs. Build the grouped lists (Source / Tests / Docs / Excluded)
but do **not** ask yet — 3.3 confirms the file set and the message in one round-trip.

### 3.2 Craft commit message

Subject stays in **conventional commits** (`feat`, `fix`, `refactor`, `test`, `docs`,
`chore`, `style`, `perf`). Body is plain language for non-engineers.

- **Subject:** `<type>(<scope>): <imperative summary, ≤70 chars>`
- **Body:** what users can now do, see, or notice. No story IDs, epic names, AC counts,
  test tallies, class/function names, or file paths.
- **Footer:** `Closes #<story_issue>` when a story issue is linked.

Full templates: [examples.md](references/examples.md).

### 3.3 Confirm files + message (ONE batched gate)

Show a preview (Branch / Files to stage grouped per 3.1 / full Message / Linked issues),
then ask **both** questions in a **single `AskUserQuestion` call** — never two sequential
calls:

1. "Stage these files?" → **Stage all**, **Adjust** (user drops/adds specific files).
2. "Commit this message?" → **Commit**, **Edit message**, **Abort**.

Resolve the answers together: `Abort` stops regardless of Q1. On `Adjust` and/or `Edit
message`, apply the revisions and re-ask the same batched pair once — the happy path
(Stage all + Commit) costs one round-trip, not two.

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

### 5.1 Route by existing-PR detection

Use `existing_pr` from Phase 1.2: found → **5.A** (push + update); none → **5.B** (create).

### 5.A Update existing PR

1. AskUserQuestion — show PR (number, title, URL): "Push to `<branch>` and update PR
   #`<n>`?" options **Update PR**, **Skip push** (→ Phase 6), **New PR** (→ 5.B).
2. `git push origin "$(git branch --show-current)"`.
3. Read `existing_pr.body` and append under a `## Updates` section (create it if absent):
   `- <YYYY-MM-DD>: <commit subject> — <one-line plain-language summary>`. Write the
   **merged** body back — never overwrite prior content:
   ```bash
   gh pr edit <pr-number> --body "$(cat <<'EOF'
   <merged body>
   EOF
   )"
   ```
   Content rules identical to 3.2.

### 5.B Create new PR

1. **Resolve the base branch — never ask for it.** The repo already declares it:

   ```bash
   gh repo view --json defaultBranchRef -q .defaultBranchRef.name
   ```

   Use that as the PR base. If `gh` fails, fall back to `main`. Only when the repo has a
   `develop` branch **and** the default is not `develop` is the target genuinely ambiguous
   (`git rev-parse --verify --quiet origin/develop`) — in that case offer it as an option
   inside the single question below rather than as a second prompt.
2. AskUserQuestion — one call, "Open a PR into `<base>`?": **Yes** (create now),
   **Commit only** (→ Phase 6), **Push, PR later** (push branch, skip PR → Phase 6),
   **Different base** (only when step 1 found a genuine ambiguity — then ask for the base).
3. `git push -u origin <branch-name>`.
4. PR title = commit first line (≤70 chars). PR body is plain language for non-engineers
   — no story IDs, AC checkboxes, or test tallies. Bodies (feature / bug fix) + the exact
   `gh pr create` command + post-create output: [pr-templates.md](references/pr-templates.md).

## PHASE 6: MARK DONE & UPDATE ISSUES

### 6.1 Mark the story done (frontmatter is the source of truth)

**Skip when the frontmatter already reads `status: done`** — `/ck-code:build` Phase 8.6
flips it and regenerates the views before invoking this skill; a second flip and
regenerate here is duplicate work. Otherwise, if this ship completes the story's work:
set the story frontmatter `status: done` (Edit the `status:` line — do **not** cell-edit
any index or flip an EPIC checkbox), then regenerate views once:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh" tasks/<slug>
```

If the story is not yet fully done, leave `status` as is and skip issue-close steps.

### 6.2 Update the story issue (only if `story_issue` is set)

Resolve by the `story_issue` number from 2.3. Templates: [issue-templates.md](references/issue-templates.md).

- **New PR (5.B):** `gh issue comment <story_issue>` with the PR number + a 1–2 sentence
  plain-language summary. No AC lists, no test counts.
- **Existing PR updated (5.A):** `gh issue comment <story_issue>` noting the new commit
  hash + summary; don't repeat the PR number if already posted.
- **Commit-only on a protected branch:** `gh issue close <story_issue>` with the commit
  hash + summary.

### 6.3 Update the epic issue checklist (only if `epic_issue` is set)

Resolve the epic issue by the `epic_issue` number from 2.3 (never by title):

```bash
gh issue view <epic_issue> --json body -q .body
```

Flip this story's checklist item to `[x]`, then `gh issue edit <epic_issue> --body "<updated>"`.
Match the item exactly: `#<story_issue>` when a story issue exists, else the bracketed
padded token `[EE-SS]` (e.g. `[02-01]`, which never collides with `[02-10]`).

### 6.4 Labels (only if `story_issue` is set)

```bash
gh issue edit <story_issue> --add-label "status/done"
gh issue edit <story_issue> --add-label "has-bugfix"   # bug fix only
```

## PHASE 7: SUMMARY

Present: Commit (hash/branch/message), PR (url/status), Issues updated (story #, epic #),
Story (status/path), Next steps. Worked shape: [examples.md](references/examples.md).

- More stories remain → suggest `/ck-code:track next` then `/ck-code:build`.
- Epic complete → note the epic issue can be closed manually or auto-closes once all its
  checkboxes are checked.
- Remind the user: once the PR merges, delete the local story branch
  (`git branch -d <branch>`) — merged `story/*`/`fix/*` branches otherwise accumulate
  forever.

## STANDALONE MODE (no story)

1. Show `git diff --stat` and `git status`.
2. AskUserQuestion — change type (feat/fix/refactor/…).
3. Ask for a brief description.
4. Craft a conventional commit message (plain-language body).
5. Commit, optionally PR (Phase 5).
6. No issue updates and no frontmatter/index changes (no story to link).

---

# PUBLISH MODE (`--to-issues`) — plan → GitHub Issues

Publishes a generated `tasks/<slug>/` plan to GitHub Issues at the chosen granularity,
then **writes each new issue number back into frontmatter** (`issue:`) so SHIP MODE can
later resolve issues by number.

**Resolve the plan path.** If a `tasks/<slug>/` path was given, use it. Else
`Glob "tasks/*/PROJECT_OVERVIEW.md"` (or `FEATURE_OVERVIEW.md`): one → use it (confirm);
several → ask which; none → tell the user to run `/ck-code:plan` first.

| Mode | Issues created | Frontmatter write-back |
|---|---|---|
| `feature` | **1** whole-feature issue (epics + stories as nested checklists) | none (coarse tracking; no per-story issue) |
| `epics` | **1 per epic** (stories are an in-body checklist) | epic issue → each `EPIC.md` `issue:` |
| `stories` | epic issues **+** 1 per story (full hierarchy) | epic issue → `EPIC.md` `issue:`; story issue → story `issue:` |

## PHASE P1: VALIDATE ENVIRONMENT

```bash
gh auth status
gh repo view --json nameWithOwner -q .nameWithOwner
```

If either fails, stop and tell the user what to fix.

## PHASE P2: READ PLAN STRUCTURE

1. Read `PROJECT_OVERVIEW.md` (or `FEATURE_OVERVIEW.md`) for the project name and summary.
2. `Glob "tasks/<slug>/epics/*/EPIC.md"` — each epic (folder `NN_<slug>`, `EPIC.md` frontmatter).
3. Per epic, `Glob "tasks/<slug>/epics/NN_*/stories/*.md"` — each story
   (`SS_<slug>.md`, frontmatter `id,title,epic,size,blocked_by,issue`).
4. Read each `EPIC.md` and story to extract titles, descriptions, acceptance criteria,
   sizes, and dependencies. Build an in-memory map of the plan (keep each file's path so
   Phase P5 can write `issue:` back).

## PHASE P3: SELECT MODE & CONFIRM

**Mode:** if `--mode` was passed, use it; else AskUserQuestion — "How to publish this
plan?" options **feature** (1 issue), **epics** (1 per epic), **stories** (epics + one
per story).

**Duplicate check** before proposing: `gh issue list --label "epic" --state all --json title,number`
(and `feature`/`story` for the mode). If matches exist, fold **Skip duplicates /
Proceed anyway / Abort** into the confirm prompt below.

**Confirm:** present the repo, project name, mode, labels to create, and the issue count
(`feature`=1; `epics`=N; `stories`=N epics + M stories). AskUserQuestion — "Proceed?"
options **Create**, **Dry-run** (print exactly what would be created, create nothing),
**Abort**.

## PHASE P4: CREATE LABELS

Create only the labels the chosen mode needs (`--force` updates existing). In `stories`
mode add one `size/<S>` label per size actually present.

```bash
gh label create "feature" --color "0E8A16" --description "Whole-feature tracking issue" --force
gh label create "epic" --color "6F42C1" --description "Epic-level issue" --force
gh label create "story" --color "0075CA" --description "Implementation story" --force
gh label create "size/S" --color "C2E0C6" --description "Small story" --force
gh label create "size/M" --color "BFDADC" --description "Medium story" --force
```

## PHASE P5: CREATE ISSUES & WRITE BACK

Follow the chosen mode's section in [issue-bodies.md](references/issue-bodies.md). `sleep 1`
between every `gh` call (GitHub rate-limits issue creation strictly).

- **`feature`** — create the one issue. No frontmatter write-back.
- **`epics`** — create each epic issue; for each, Edit its `EPIC.md` frontmatter `issue:`
  to the new number (add the line if absent).
- **`stories`** — create all epic issues first (record epic-slug → issue number and write
  each into `EPIC.md` `issue:`), then create each story issue and Edit that story's
  frontmatter `issue:` to the new number, then replace the `#TBD` placeholders in each
  epic body with the real story-issue numbers.

After all write-backs, regenerate the views once (frontmatter changed):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ck-index.sh" tasks/<slug>
```

If a single `gh issue create` fails, report it and continue; list all failures at the end.

## PHASE P6: SUMMARY

Fill the summary shape from [issue-bodies.md](references/issue-bodies.md) for the mode
that ran (created issue numbers, quick links, total). Note which stories/epics got an
`issue:` written back.

---

## RULES

- **Never reference AI, Claude, or generated-by notes** in any artefact — [full rule](../../references/no-ai-references.md).
- **Never resolve a GitHub issue by matching its title** — resolve by the frontmatter `issue:` number (story) or `EPIC.md` `issue:` (epic). No `contains("[EE-SS]")` title search.
- **Never store story status anywhere but frontmatter** — set `status: done` in the story file and run `ck-index.sh`; never cell-edit an index or flip an EPIC checkbox for status.
- **Always run `ck-index.sh` in the same phase** you change any story or epic frontmatter (status write, or `--to-issues` `issue:` write-back).
- **Never commit directly to `main` or `develop`** (Phase 1).
- **Never ask the user for the PR base branch** — read it from `gh repo view --json defaultBranchRef` (Phase 5.B); prompt only on a genuine `main`/`develop` ambiguity.
- **Never split a confirmation into sequential `AskUserQuestion` calls** when the questions are known at the same time — `AskUserQuestion` takes up to 4 questions per call, and each extra call is a full round-trip. Phase 3.3 batches file-set + message.
- **Never `git add -A` or `git add .`** — stage files by name; never stage secrets or env files.
- **Never mention story IDs, epic names, AC checklists, test counts, or file paths** in a commit body, PR body, or issue comment — they are plain-language, read by non-engineers.
- **Never overwrite a PR description** — append beneath the existing body and prior `## Updates` entries.
- **Never open a second PR for a branch** that already has an open one (Phase 1.2).
- **Never block the commit on GitHub failures** — if `gh` is missing, unauthenticated, or a lookup returns nothing, surface it and continue commit-only.
- **Never create issues outside the chosen `--to-issues` mode** — `feature`=1 issue, `epics` makes no story issues, only `stories` builds the full hierarchy.
- **Never create a story issue before every epic issue exists** — story bodies cross-reference epic numbers.
- **Always `sleep 1` between every `gh` call** in `--to-issues` mode — GitHub rate-limits strictly.
- **Always close issues with a `Closes #X` footer**, and only when the work is complete.

## NEXT

If more stories are ready, run `/ck-code:track next`. To explain what was just built
(verification commands + walkthrough), run `/ck-code:explain`. For a deeper pre-PR pass,
native `/code-review` (or `/code-review --fix`) reviews the diff before this skill opens
the PR — see [native-commands.md](../../references/native-commands.md).
