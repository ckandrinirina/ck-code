# PR Templates

PR descriptions used by Phase 4. PR title is the same as the commit first line (keep under 70 chars).

## Story Implementation PR Body

```markdown
## Summary
- Implements story [EE]-[SS]: [title]
- Epic: [epic title]

## Changes
- [Key change 1]
- [Key change 2]
- [Key change 3]

## Acceptance Criteria
- [x] [Criterion 1]
- [x] [Criterion 2]
- [x] [Criterion 3]

## Testing
- [count] automated tests added/modified
- All tests passing
- Manual testing completed

[If GitHub issue exists:]
Closes #[story_issue_number]
```

## Bug Fix PR Body

```markdown
## Summary
- Fixes bug in story [EE]-[SS]: [title]
- Root cause: [explanation]

## Changes
- [What was fixed]
- Added regression test: [test name]

## Testing
- Reproduction test now passes
- No regressions detected
- [count] total tests passing

[If GitHub issue exists:]
Closes #[story_issue_number]
```

## gh pr create Command

```bash
gh pr create \
  --title "[title]" \
  --base [target-branch] \
  --body "$(cat <<'EOF'
[PR body]
EOF
)"
```

## Post-Create Output

```
## PR Created

**URL:** [PR URL]
**Title:** [title]
**Target:** [base branch]
**Linked issues:** #[numbers]
```
