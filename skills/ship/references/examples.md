# Worked Examples

Both commit body and PR body are written in plain language. Subject lines
stay in conventional-commit format for changelog and CI tooling.

## Example: Full Feature Ship (Commit + PR + Issue Updates)

### Phase 2.2 — Commit Message

```
feat(realtime): live updates without refresh

The app now receives live updates from the server. Logged-in users see
new messages, notifications, and shared state appear instantly without
needing to refresh the page.

- New realtime channel for live updates
- Compact message format reduces bandwidth on slow connections
- Connects through the existing service layer, no extra setup needed

Closes #42
```

### Phase 3.1 — Execute Commit (HEREDOC)

```bash
git commit -m "$(cat <<'EOF'
feat(realtime): live updates without refresh

The app now receives live updates from the server. Logged-in users see
new messages, notifications, and shared state appear instantly without
needing to refresh the page.

- New realtime channel for live updates
- Compact message format reduces bandwidth on slow connections
- Connects through the existing service layer, no extra setup needed

Closes #42
EOF
)"
```

### Phase 3.2 — Verify

```bash
git log --oneline -1
git show --stat HEAD
```

Output:
```
## Committed

**Hash:** a1b2c3d
**Branch:** story/01-03-server-setup
**Files:** 8
**Message:** feat(realtime): live updates without refresh
```

### Phase 4 — Push & Create PR

```bash
git push -u origin story/01-03-server-setup

gh pr create \
  --title "feat(realtime): live updates without refresh" \
  --base main \
  --body "$(cat <<'EOF'
## What's new
The app now receives live updates from the server without users needing
to refresh. Logged-in users see new messages, notifications, and shared
state appear instantly.

## Changes
- New realtime channel for live updates
- Compact message format reduces bandwidth on slow connections
- Connects through the existing service layer, no extra setup needed

## Notes
- Initial rollout covers logged-in users only; guests fall back to the
  existing refresh-based flow.

Closes #42
EOF
)"
```

### Phase 5 — Update Issues

Comment on the linked issue:
```bash
gh issue comment 42 --body "$(cat <<'EOF'
Implementation is complete and merged via PR #57.

Logged-in users now receive live updates without needing to refresh —
new messages and notifications appear instantly. Guests still fall
back to the existing refresh-based flow.
EOF
)"
```

Update parent checklist (parent issue #10):
```bash
gh issue view 10 --json body -q .body
# Replace "- [ ] #42" with "- [x] #42" then:
gh issue edit 10 --body "<updated body>"
```

Add label:
```bash
gh issue edit 42 --add-label "status/done"
```

### Phase 6 — Summary Output

```
## Ship Complete

### Commit
- **Hash:** a1b2c3d
- **Branch:** story/01-03-server-setup
- **Message:** feat(realtime): live updates without refresh

### PR
- **URL:** https://github.com/org/repo/pull/57
- **Status:** Open

### GitHub Issues Updated
- Issue #42: commented
- Parent #10: checklist updated

### Story File
- **Status:** DONE
- **Path:** tasks/01-foundation/01-03-server-setup.md

### Next Steps
- Run /ck-code:track next to find the next item
- Run /ck-code:build to implement it
```

## Example: Bug Fix Commit

```
fix(profile): no more crash on empty profile

Profile pages crashed for users who hadn't filled in their profile yet.
Visiting the page now shows the empty profile placeholder instead of an
error.

Closes #88
```

## Example: Bug Fix PR Body

```markdown
## What's fixed
Profile pages crashed for users who hadn't filled in their profile yet.
Visiting the page now shows the empty profile placeholder instead of an
error.

## Impact
- Affected newly registered users who hadn't completed onboarding.
- They can now reach their profile page without seeing an error screen.

Closes #88
```
