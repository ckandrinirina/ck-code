# Issue Templates

Templates for Phase 5 GitHub Issue updates.

## Story Issue: PR Created Comment

When a PR was created, comment on the story issue:

```bash
gh issue comment [story_issue_number] --body "$(cat <<'EOF'
Implementation complete. PR: #[pr_number]

Changes:
- [Key change 1]
- [Key change 2]

All acceptance criteria met. [count] tests passing.
EOF
)"
```

## Story Issue: Direct Close (commit only, on main/develop)

When committing directly without a PR, close the issue:

```bash
gh issue close [story_issue_number] --comment "$(cat <<'EOF'
Implemented in [commit_hash].

Changes:
- [Key change 1]
- [Key change 2]

All acceptance criteria met. [count] tests passing.
EOF
)"
```

## Epic Issue: Update Checklist

Mark the completed story in the epic's task list:

1. Read the epic issue body:
   ```bash
   gh issue view [epic_issue_number] --json body -q .body
   ```
2. Replace `- [ ] #[story_issue_number]` with `- [x] #[story_issue_number]`
3. Update the body:
   ```bash
   gh issue edit [epic_issue_number] --body "[updated body]"
   ```

## Status Labels

Mark the story as done:
```bash
gh issue edit [story_issue_number] --add-label "status/done"
```

For bug fixes:
```bash
gh issue edit [story_issue_number] --add-label "has-bugfix"
```
