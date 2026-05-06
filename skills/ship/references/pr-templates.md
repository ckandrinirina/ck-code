# PR Templates

PR descriptions used by Phase 4. PR title is the same as the commit first
line (keep under 70 chars).

These bodies are read by PMs, designers, and leadership — not just
engineers. Write them in plain language: describe what users can now do
or notice, not which classes changed or how many tests pass.

## Feature PR Body

```markdown
## What's new
<1–3 sentences in plain language. What users can now do, see, or notice
once this ships.>

## Changes
- <Plain-language bullet — a user-visible outcome>
- <Plain-language bullet>
- <Plain-language bullet>

## Notes
- <Constraint, follow-up, or out-of-scope item — only if useful>

Closes #<issue_number>
```

The **Notes** section is optional. Drop it if there's nothing to flag.

## Bug Fix PR Body

```markdown
## What's fixed
<Plain-language description of the user-visible problem and how the app
behaves now.>

## Impact
- <Who was affected and what they'll now experience>

Closes #<issue_number>
```

## gh pr create Command

```bash
gh pr create \
  --title "<title>" \
  --base <target-branch> \
  --body "$(cat <<'EOF'
<PR body from a template above>
EOF
)"
```

## Post-Create Output

```
## PR Created

**URL:** <PR URL>
**Title:** <title>
**Target:** <base branch>
**Linked issues:** #<numbers>
```

## Things to avoid in the PR body

- Story IDs (`01-03`), epic names, internal ticket prefixes
- File paths (`apps/backend/src/...`)
- Class names, function names, test method names
- Acceptance-criteria checkbox lists
- Test-count tallies (`12 tests passing`, `all tests passing`)
- Internal tool names (slash commands, plugin names)
- "Validated by X" / "Approved by Y" lines

## Things to include

- A plain-language **What's new** / **What's fixed** lead
- A short **Changes** bullet list of user-visible outcomes
- An optional **Notes** subsection for constraints, follow-ups, or
  scope cuts
- A `Closes #N` footer when an issue is linked
