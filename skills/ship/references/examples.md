# Worked Examples

## Example: Full Story Ship (Commit + PR + Issue Updates)

### Phase 2.2 — Commit Message

```
feat(foundation): setup WebSocket server

Implements story 01-03: WebSocket gateway with MessagePack serialization

- Created ws handler with connection management
- Added MessagePack serialization/deserialization
- Integrated with existing gRPC client

5 acceptance criteria met
12 tests passing

Closes #42
```

### Phase 3.1 — Execute Commit (HEREDOC)

```bash
git commit -m "$(cat <<'EOF'
feat(foundation): setup WebSocket server

Implements story 01-03: WebSocket gateway with MessagePack serialization

- Created ws handler with connection management
- Added MessagePack serialization/deserialization
- Integrated with existing gRPC client

5 acceptance criteria met
12 tests passing

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
**Message:** feat(foundation): setup WebSocket server
```

### Phase 4 — Push & Create PR

```bash
git push -u origin story/01-03-server-setup

gh pr create \
  --title "feat(foundation): setup WebSocket server" \
  --base main \
  --body "$(cat <<'EOF'
## Summary
- Implements story 01-03: WebSocket gateway with MessagePack serialization
- Epic: Foundation

## Changes
- Created ws handler with connection management
- Added MessagePack serialization/deserialization
- Integrated with existing gRPC client

## Acceptance Criteria
- [x] WebSocket server accepts connections
- [x] MessagePack encode/decode round-trip
- [x] gRPC integration verified
- [x] Connection lifecycle handled
- [x] Errors logged

## Testing
- 12 automated tests added
- All tests passing
- Manual testing completed

Closes #42
EOF
)"
```

### Phase 5 — Update Issues

Comment on story issue:
```bash
gh issue comment 42 --body "$(cat <<'EOF'
Implementation complete. PR: #57

Changes:
- WebSocket gateway with connection management
- MessagePack serialization

All acceptance criteria met. 12 tests passing.
EOF
)"
```

Update epic checklist (epic issue #10):
```bash
gh issue view 10 --json body -q .body
# Replace "- [ ] #42" with "- [x] #42" then:
gh issue edit 10 --body "[updated body]"
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
- **Message:** feat(foundation): setup WebSocket server

### PR
- **URL:** https://github.com/org/repo/pull/57
- **Status:** Open

### GitHub Issues Updated
- Story #42: commented
- Epic #10: checklist updated

### Story File
- **Status:** DONE
- **Path:** tasks/01-foundation/01-03-server-setup.md

### Next Steps
- Run /ck-code:track next to find the next story
- Run /ck-code:build to implement it
```

## Example: Bug Fix Commit

```
fix(api): handle null user in profile lookup

Fixes bug in story 02-01: NullPointerException when user has no profile

- Added null guard in ProfileService.lookup()
- Added regression test: testLookupWithNullUser

Closes #88
```
