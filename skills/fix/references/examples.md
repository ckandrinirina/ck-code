# Worked Bug-Fix Walkthroughs

End-to-end examples of the `/ck-code:fix` workflow. These illustrate the
decision points but the rules in `SKILL.md` are authoritative — when in doubt,
follow `SKILL.md`.

---

## Example 1: Off-by-one in WebSocket message handler

### Phase 1 — Story Selection
- User runs `/ck-code:fix tasks/foundation/epics/01-foundation/stories/01-03-websocket-gateway.md`
- Story status: `DONE`
- Story implementation summary lists `src/server/ws/handler.rs` and tests.

### Phase 2 — Bug Description
- Expected: When a client sends 10 messages, the server logs 10 `received` events.
- Actual: Server logs only 9.
- Repro: Send 10 messages back-to-back via WebSocket client.
- Started: After the merge of story 01-03 (regression).

### Phase 3 — Skill Detection
- Files in `server/` → `expert-backend`.
- `.rs` extension → `guide-rust`.
- `expert-qa` and `expert-analyst` always loaded.

### Phase 4 — QA Reproduction & Diagnosis

**4.1 Locate code.** Read `src/server/ws/handler.rs`. Found loop:

```rust
for i in 0..msgs.len() - 1 {  // off-by-one
    log::info!("received: {:?}", msgs[i]);
}
```

**4.2 Reproduce.** Existing tests passed because they only sent 1 message.
Wrote new test `test_logs_all_messages_when_batch_sent` that sends 10 and
asserts log count == 10. Test FAILS with actual count = 9. Bug confirmed.

**4.3 Root cause.** `0..msgs.len() - 1` should be `0..msgs.len()` (or
`msgs.iter()`). Off-by-one error.

**4.4 Related patterns.** Grep for `len() - 1` in `src/server/`. Found one
similar pattern in `src/server/grpc/stream.rs:88` — flagged but NOT fixed
(separate scope; tell user to run `/ck-code:fix` on that story separately).

**4.5 Story update.** Append `Bug Report` section with status `DIAGNOSING`
(see `references/bug-section-template.md`).

**4.6 User confirms diagnosis.** Replies `YES`.

### Phase 5 — Fix Planning

**5.0 TDD gate.** Failing test exists. Test asserts log count == 10. Fix will
make ONLY that test pass. Gate passes.

**5.1 Minimal fix.** Change `0..msgs.len() - 1` to `0..msgs.len()`.
**5.2 Subtasks** created. **5.3 Story updated** with Fix Plan. **5.4 User
confirms.**

### Phase 6 — TDD Fix

- **RED.** Run repro test → fails (count=9).
- Apply 1-line fix.
- **GREEN.** Run repro test → passes. Run all tests → all pass.
- **Refactor.** None needed; consider replacing index loop with `for msg in &msgs`
  but that's a refactor — log says: skipped (out of fix scope).

### Phase 7 — QA Validation
- Full suite passes. All acceptance criteria still pass. Lint/type/format pass.
- Diff is 1 line. Minimalism PASS. Verdict: PASS.

### Phase 8 — Completion
- Append `Resolution` section to story (see template).
- `Files Touched`:
  ```
  MODIFIED src/server/ws/handler.rs:42
  CREATED  tests/ws_handler_batch_log_test.rs
  ```
- Story status stays `DONE`. User manual test PASS. Ship via `/ck-code:ship`.

---

## Example 2: Missing null-check causes intermittent panic

### Phase 2 — Bug
- Intermittent panic in mobile app when opening profile screen.
- Repro: ~1 in 5 logins. Stack trace shows `unwrap on None` in `profile_loader.rs:55`.

### Phase 4 — Diagnosis
- Code does `user.avatar_url.unwrap()`. Avatar may be `None` for new users.
- Reproduction test: create user without avatar, open profile → panics.
- Root cause: missing `Option` handling, not a flaky test.

### Phase 5 — Minimal Fix
- Replace `unwrap()` with `unwrap_or_default()` (or render placeholder).
- DO NOT refactor surrounding `ProfileLoader` even though it has other smells —
  out of scope. Document smells; don't touch them.

### Phase 6/7 — Fix + QA
- Test goes RED → GREEN. No regressions. Diff: 1 line + 1 new test.

### Key takeaway
Even when surrounding code is messy, the fix stays minimal. Smells go into
follow-up bug notes, never into this fix's diff.

---

## Anti-pattern: opportunistic refactor (DO NOT DO THIS)

> "While I'm in `handler.rs` fixing the off-by-one, I'll also rename
> `msgs` to `messages` and extract a helper function."

Wrong. Two reasons:
1. The diff is no longer minimal — reviewers can't tell what fixed the bug.
2. A rename or extraction could introduce a NEW regression that the
   reproduction test won't catch.

Stay focused. Open a separate refactor task if cleanup is warranted.
