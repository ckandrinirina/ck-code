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

## Story Issue: Commit Only (no PR yet)

When the work was committed (or merged into an epic or plan branch) without a PR of its
own, comment — never close. The issue closes through the `Closes #` footer of the PR that
reaches the trunk, or through `ck-project reconcile` once the work is delivered:

```bash
gh issue comment <story_issue> --body "$(cat <<'EOF'
Committed in <commit_hash>.

<1–2 sentences in plain language: what users can now do or notice.>
EOF
)"
```

## Epic Issue: Update Checklist

Commands live in SKILL.md Phase 6.3. Resolve the epic issue by the `EPIC.md`
frontmatter `issue:` number, read its body with `gh issue view`, flip the story's item
(`- [ ] #<story_issue>`, or the bracketed padded token `- [ ] [EE-SS]` when no story
issue exists) to `- [x]`, and write it back with `gh issue edit`.

## Labels

None. Ship adds no status labels (SKILL.md 6.4): native sub-issues and the board carry
status.

## Things to avoid in issue comments

- "All acceptance criteria met" lines
- "<N> tests passing" tallies
- Class names, function names, file paths, test method names
- Internal tool / plugin names

## Things to include

- A 1–2 sentence plain-language summary of what users can now do or notice
- A link to the PR (if any) or the commit hash (if direct)
- Optional follow-up note for constraints, scope caveats, or rollout
