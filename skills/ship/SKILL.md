---
name: ship
description: Use to commit work, open a PR, and update linked GitHub Issues after a story or fix is complete. Argument is an optional story file path. Also works for any standalone commit.
argument-hint: "[path-to-story.md]"
disable-model-invocation: false
allowed-tools: Bash(git *) Bash(gh *) Bash(sleep *)
---

# Ship — Commit, PR & Issue Management

Commit changes, optionally create a PR, and update linked GitHub Issues. Detects story context to link everything.

**CRITICAL RULE — No AI references in any artefact.** Full rule in [`../../../references/no-ai-references.md`](../../../references/no-ai-references.md): no co-author tags, no "Generated with…" lines, no Claude/AI/assistant mentions in commits, PRs, comments, branch names, or any GitHub output. Absolute and non-overridable.

## INPUT
`$ARGUMENTS` is an optional path to a story file.
- **Provided:** read the story for issue links and context.
- **Empty:** detect context from branch name or recent git activity. If none, run as standalone commit.

## PHASE 0: BRANCH & PR CHECK
**Goal:** ensure work is on a feature branch and detect any existing PR — never commit directly to `main` or `develop`.

### 0.1 Resolve Current Branch

```bash
git branch --show-current
```

- **Feature branch** (`story/01-03-*`, `fix/02-01-*`, etc.): continue to 0.2.
- **Protected branch (`main`, `develop`, …):** STOP before staging. Propose a name (`story/[EE]-[SS]-[slug]`, `fix/[EE]-[SS]-[slug]`, or `[type]/[slug]`) and offer A) CREATE, B) RENAME, C) SKIP (warn, not recommended). On A/B: `git checkout -b [branch-name]`.

This applies to standalone commits too — always offer a feature branch on protected branches.

### 0.2 Detect Existing PR for Current Branch

```bash
gh pr list --head "$(git branch --show-current)" --state open --json number,url,title,body
```

Store the result as `existing_pr`:
- **One open PR found:** record `number`, `url`, `title`, and `body`. Phase 4 will reuse this PR (push + update description) instead of creating a new one.
- **No open PR:** Phase 4 will run the standard create-PR flow.
- **Multiple open PRs (rare):** show the list and ask the user which to update, or `NONE` to open a new one.

If `gh` is missing or unauthenticated, treat as "no existing PR" and continue.

## PHASE 1: GATHER CONTEXT

### 1.1 Check Git State
```bash
git status
git diff --stat
git diff --staged --stat
git log --oneline -5
```
If clean and nothing staged: "Nothing to commit. Working tree is clean." → STOP.

### 1.2 Detect Story Context
Find the linked story in this order:
1. **`$ARGUMENTS`:** read the story file if a path was given.
2. **Branch name:** parse `story/[EE]-[SS]-*` or `fix/[EE]-[SS]-*`.
3. **Recent files:** match modified files against any story's "Files to Create/Modify".

If found, extract: title, epic, ID (EE-SS), status (DONE / IN PROGRESS), acceptance criteria, Implementation Summary or Bug Resolution, Files Touched.

### 1.3 Detect Linked GitHub Issues
If a story is found:
1. Scan the story file for `#123`, `GH-123`, etc.
2. Story issue: `gh issue list --label "story" --state open --json number,title | jq '.[] | select(.title | contains("[EE-SS]"))'`
3. Parent epic: `gh issue list --label "epic" --state open --json number,title | jq '.[] | select(.title | contains("Epic [NN]"))'`

Store `story_issue` and `epic_issue`.

### 1.4 Read Commit Style
`git log --oneline -10` — match the repo's existing commit message style.

## PHASE 2: PREPARE COMMIT

### 2.1 Stage Files
Run `git status`. **Auto-stage** modified/new source files for the story, test files, and story file updates. **Never stage** `.env`, credentials, secrets, `.DS_Store`, IDE configs. Present grouped lists (Source / Tests / Documentation / Excluded) and ask: "Stage these files? YES / ADJUST".

### 2.2 Craft Commit Message
Subject line stays in **conventional commits** format (`feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`, `perf`). Body is plain language readable by non-engineers.

- **Subject:** `<type>(<scope>): <imperative summary, ≤70 chars>`
- **Body:** describe what users can now do, see, or notice. No story IDs, no epic names, no acceptance-criteria counts, no test-count tallies. No class names, function names, or file paths.
- **Footer:** `Closes #<issue_number>` if linked.

Full message templates: [references/examples.md](references/examples.md).

### 2.3 Confirm Commit
Show preview (Branch / Files staged / full Message / Linked issues) and ask: "Commit? YES / EDIT MESSAGE / ABORT". On EDIT, let the user modify, then re-confirm.

## PHASE 3: COMMIT

### 3.1 Execute Commit
```bash
git add [specific files]
git commit -m "[message]"
```
Use a HEREDOC for multi-line messages — see [references/examples.md](references/examples.md).

### 3.2 Verify Commit
```bash
git log --oneline -1
git show --stat HEAD
```
Present hash, branch, file count, first message line.

## PHASE 4: PR (Create or Update)

### 4.1 Route by Existing-PR Detection

Use `existing_pr` from Phase 0.2:

- **Existing PR found** → go to **4.A** (push to current branch, update PR description).
- **No existing PR** → go to **4.B** (ask about creating one).

### 4.A Update Existing PR

**4.A.1 Confirm with user.** Show the PR (number, title, URL) and ask: `Push to <branch> and update PR #<n> description with this commit? YES / SKIP / NEW PR`. On `SKIP` → Phase 5 (no push). On `NEW PR` → go to 4.B.

**4.A.2 Push to current branch.**
```bash
git push origin "$(git branch --show-current)"
```

**4.A.3 Update PR description.** Read the existing PR body (`existing_pr.body` from 0.2). Append a new entry under a `## Updates` section (create the section if absent):

```markdown
## Updates

- <YYYY-MM-DD>: <commit subject line> — <one-line plain-language summary of what users can now do or notice>
```

Then write the merged body back:

```bash
gh pr edit <pr-number> --body "$(cat <<'EOF'
<merged body>
EOF
)"
```

The original body and existing `## Updates` entries are preserved. No story IDs, no AC checkboxes, no test counts — same rules as 2.2.

### 4.B Create New PR

**4.B.1 Ask about PR.** A) YES (create now), B) NO (commit only → Phase 5), C) LATER (push branch, skip PR → Phase 5).

**4.B.2 Determine PR target.** A) `main` (default), B) `develop`, C) other (specify).

**4.B.3 Push branch.**
```bash
git push -u origin [branch-name]
```

**4.B.4 Craft PR.** PR title = commit first line (under 70 chars). PR body is read by PMs, designers, and stakeholders — write it in plain language with no story IDs, no AC checkboxes, and no test-count tallies. Body templates (feature / bug fix): [references/pr-templates.md](references/pr-templates.md).

**4.B.5 Create PR.** Use `gh pr create --title ... --base ... --body "$(cat <<'EOF' ... EOF)"`. Exact command and post-create output block: [references/pr-templates.md](references/pr-templates.md).

## PHASE 5: UPDATE GITHUB ISSUES

### 5.1 Update Story Issue
- **New PR created (4.B):** comment on the linked issue with the PR number and a 1–2 sentence plain-language summary of what users can now do or notice. No AC lists, no test counts.
- **Existing PR updated (4.A):** comment on the linked issue noting the new commit hash and a 1–2 sentence plain-language summary. Do not duplicate the PR number if it was already posted earlier in the thread.
- **Commit only on protected branch:** close the issue with the commit hash and the same plain-language summary.

Exact `gh issue comment` / `gh issue close` templates: [references/issue-templates.md](references/issue-templates.md).

### 5.2 Update Epic Issue
If an epic issue is linked, mark the completed story in its checklist:
1. `gh issue view [epic_issue_number] --json body -q .body`
2. Replace `- [ ] #[story_issue_number]` with `- [x] #[story_issue_number]`
3. `gh issue edit [epic_issue_number] --body "[updated body]"`

### 5.3 Add Labels
```bash
gh issue edit [story_issue_number] --add-label "status/done"
# bug fix:
gh issue edit [story_issue_number] --add-label "has-bugfix"
```

## PHASE 6: SUMMARY
Present a final block covering: Commit (hash/branch/message), PR (url/status), GitHub Issues Updated (story / epic), Story File (status/path), and Next Steps. Worked summary: [references/examples.md](references/examples.md).

**Hand-off rules / Next Steps:**
- More stories remain: suggest `/ck-code:track next` then `/ck-code:build`.
- Epic complete: note the epic issue can be closed manually or will auto-close once all checkboxes are checked.

## STANDALONE MODE (No Story)
1. Show `git diff --stat` and `git status`.
2. Ask the user the change type (feat/fix/refactor/etc.).
3. Ask for a brief description.
4. Craft a conventional commit message.
5. Commit, optionally PR.
6. No issue updates (no story to link).

## IMPORTANT GUIDELINES

### No AI references — absolute

See [`../../../references/no-ai-references.md`](../../../references/no-ai-references.md) for the full rule. It applies to commits, PRs, issue comments, branch names, and any GitHub artefact this skill produces.

### Commit Messages Must Be Clean
- Conventional commits format on the subject line; under 70 characters
- Body is plain-language and readable by non-engineers — what users can now do, see, or notice
- Body never mentions story IDs, epic names, AC checklists, test counts, file paths, class/function names
- `Closes #123` footer when applicable
- No emoji unless the repo convention uses them

### Stage Selectively
- Never `git add -A` or `git add .`; stage specific files by name
- Never stage secrets, credentials, or environment files; review before committing

### Issue Updates Are Careful
- Only close issues when work is complete; use `Closes #X` so GitHub auto-closes on merge
- Comments are plain-language outcome summaries — no AC lists, no test counts
- Update parent checklists on completion

### Branch Naming
- Story: `story/[EE]-[SS]-[slug]`; Bug fix: `fix/[EE]-[SS]-[slug]`; Standalone: `[type]/[slug]`
- **Never commit directly to `main` or `develop`** — Phase 0 enforces this

### Existing PR Reuse
- **Always check for an existing open PR on the current branch (Phase 0.2)** before opening a new one. Duplicate PRs for the same branch fragment review history.
- **Always append, never overwrite.** When updating a PR description, preserve the original body and prior `## Updates` entries — add the new entry beneath them.
- **Always push to the current branch when updating an existing PR** — `git push -u` is reserved for fresh branches (Phase 4.B.3).

### gh CLI Requirements
- `gh` must be installed and authenticated for Phases 1.3, 4, and 5.
- If `gh` is missing/unauthenticated: skip GitHub steps, surface the error, continue with commit-only flow.
- If an issue/epic lookup returns nothing, proceed without linking — do not block the commit.

### Reusability
Works with any project using the `tasks/` story format, and standalone without one. No project-specific references.

---

## NEXT

If more stories are ready, run `/ck-code:track next`. To explain what was just built (verification commands + walkthrough), run `/ck-code:explain`.

For a deeper pre-PR pass, the native `/code-review` (or `/code-review --fix`) reviews the diff before this skill opens the PR. See [native-commands.md](../../references/native-commands.md).
