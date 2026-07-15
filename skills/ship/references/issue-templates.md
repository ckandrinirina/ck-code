# Issue Templates

Templates for Phase 6 GitHub issue updates. `<story_issue>` is the story
frontmatter `issue:` number and `<epic_issue>` the parent `EPIC.md`
frontmatter `issue:` number — issues are always resolved by number, never
by matching titles.

These comments are read by PMs, designers, and stakeholders watching the
issue — not just engineers. Write them in plain language: describe what
the change means for users, not how many tests were added.

## Story Issue: PR Created Comment

When a PR was created, comment on the story issue:

```bash
gh issue comment <story_issue> --body "$(cat <<'EOF'
Implementation is complete and ready for review in PR #<pr_number>.

<1–2 sentences in plain language: what users can now do or notice.>

<Optional: a short follow-up note, scope caveat, or rollout reminder.>
EOF
)"
```

## Story Issue: Direct Close (commit only, on main/develop)

When committing directly without a PR, close the issue:

```bash
gh issue close <story_issue> --comment "$(cat <<'EOF'
Shipped in <commit_hash>.

<1–2 sentences in plain language: what users can now do or notice.>
EOF
)"
```

## Epic Issue: Update Checklist

Commands live in SKILL.md Phase 6.3. Resolve the epic issue by the `EPIC.md`
frontmatter `issue:` number, read its body with `gh issue view`, flip the story's item
(`- [ ] #<story_issue>`, or the bracketed padded token `- [ ] [EE-SS]` when no story
issue exists) to `- [x]`, and write it back with `gh issue edit`.

## Status Labels

Commands live in SKILL.md Phase 6.4: `--add-label "status/done"`, plus `"has-bugfix"` for bug fixes.

## Things to avoid in issue comments

- "All acceptance criteria met" lines
- "<N> tests passing" tallies
- Class names, function names, file paths, test method names
- Internal tool / plugin names

## Things to include

- A 1–2 sentence plain-language summary of what users can now do or notice
- A link to the PR (if any) or the commit hash (if direct)
- Optional follow-up note for constraints, scope caveats, or rollout
