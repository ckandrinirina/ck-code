# Issue Templates

Templates for Phase 5 GitHub issue updates.

These comments are read by PMs, designers, and stakeholders watching the
issue — not just engineers. Write them in plain language: describe what
the change means for users, not how many tests were added.

## Story Issue: PR Created Comment

When a PR was created, comment on the story issue:

```bash
gh issue comment <story_issue_number> --body "$(cat <<'EOF'
Implementation is complete and ready for review in PR #<pr_number>.

<1–2 sentences in plain language: what users can now do or notice.>

<Optional: a short follow-up note, scope caveat, or rollout reminder.>
EOF
)"
```

## Story Issue: Direct Close (commit only, on main/develop)

When committing directly without a PR, close the issue:

```bash
gh issue close <story_issue_number> --comment "$(cat <<'EOF'
Shipped in <commit_hash>.

<1–2 sentences in plain language: what users can now do or notice.>
EOF
)"
```

## Epic Issue: Update Checklist

Mark the completed item in the parent issue's task list:

1. Read the parent issue body:
   ```bash
   gh issue view <epic_issue_number> --json body -q .body
   ```
2. Replace `- [ ] #<story_issue_number>` with `- [x] #<story_issue_number>`
3. Update the body:
   ```bash
   gh issue edit <epic_issue_number> --body "<updated body>"
   ```

## Status Labels

Mark the issue as done:
```bash
gh issue edit <story_issue_number> --add-label "status/done"
```

For bug fixes:
```bash
gh issue edit <story_issue_number> --add-label "has-bugfix"
```

## Things to avoid in issue comments

- "All acceptance criteria met" lines
- "<N> tests passing" tallies
- Class names, function names, file paths, test method names
- Internal tool / plugin names

## Things to include

- A 1–2 sentence plain-language summary of what users can now do or notice
- A link to the PR (if any) or the commit hash (if direct)
- Optional follow-up note for constraints, scope caveats, or rollout
