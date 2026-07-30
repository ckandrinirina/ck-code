# Worked Triage Walkthroughs

End-to-end examples of the `/ck-code:fix` workflow. `fix` diagnoses and routes — it
never writes the source fix; `build` (Bug-Fix Mode) does. These illustrate the
decision points but the rules in `SKILL.md` are authoritative.

---

## Example 1: Off-by-one in WebSocket handler (easy → AUTO-BUILD)

### Phase 1 — Story Selection
- User runs `/ck-code:fix tasks/foundation/epics/01-foundation/stories/01-03-websocket-gateway.md`
- Story frontmatter `status: done`, `files: [src/server/ws/handler.rs]`.

### Phase 2 — Bug Description
- Expected: 10 messages → 10 `received` log events. Actual: 9. Regression after story 01-03.

### Phase 2.5 — Scope
- Only 01-03 scores ≥ 0.7. **Verdict A (single-story).** Combined `AskUserQuestion` prompt → `Proceed`.

### Phase 3–4 — Diagnosis
- Locate `for i in 0..msgs.len() - 1` — off-by-one.
- **4.2 Reproduce:** write `test_logs_all_messages_when_batch_sent` (sends 10, asserts 10). Runs → FAILS (count 9). This failing test stays in the tree — it's the RED target build inherits.
- **4.5 Story update:** append Bug Report (`Status: DIAGNOSED`); the pre-bug status `done` is recorded as `prior_status` at the Phase 6.1 flip.
- **4.6** User confirms diagnosis → `Confirm & continue`.

### Phase 5 — Fix Plan
- Strategy: change `0..msgs.len() - 1` to `0..msgs.len()`. Files: `src/server/ws/handler.rs`. Test target: the repro test. Risk: LOW. SOLID note: none.
- **5.2** Fix Plan recorded (status stays `DIAGNOSED`). **5.3** User confirms → `Record & route`.

### Phase 6 — Flip to bug & Route
- **6.1** `01-03` frontmatter: set `status: bug`, `prior_status: done`; run `ck-index tasks/foundation`. The views regenerate — `STORIES_INDEX.md` shows `bug`, `FEATURE_INDEX.md` rolls Foundation to `IN PROGRESS` automatically. No cell is hand-edited.
- **6.2 Auto-Build Eligibility Gate:** verdict A ✓, single cause ✓, 1 file ✓, LOW risk ✓, no new story ✓ → **AUTO-BUILD.**
- **6.3** Announce, then invoke `/ck-code:build tasks/.../01-03-websocket-gateway.md`.
  - `build` sees `status: bug`, enters Bug-Fix Mode, runs the repro test RED → applies the 1-line fix → GREEN → SOLID + QA + manual-test → ships (`fix/` branch, Bug ID in commit) → restores `01-03` frontmatter from `prior_status` (`done`) and regenerates the views (Foundation back to `DONE`).

### Key takeaway
`fix` never touched `handler.rs`. It proved the bug with a failing test and handed `build` an exact plan; the user experienced one continuous run.

---

## Example 2: Intermittent panic, uncertain cause (→ MANUAL BUILD)

### Phase 2 — Bug
- Intermittent panic opening the profile screen (~1 in 5 logins). Stack trace points at `profile_loader.rs:55`, but a second suspect path exists in `avatar_cache.rs`.

### Phase 4 — Diagnosis
- **4.1.5** Two competing hypotheses → dispatch 2 read-only investigators. One confirms `user.avatar_url.unwrap()` on `None`; the other (`avatar_cache`) is refuted but leaves low residual uncertainty.
- **4.2** Reproduction test: new user without avatar → panic. Written, FAILS.
- **4.5** Bug Report recorded (`Status: DIAGNOSED`); pre-bug status `done` captured as `prior_status` at the 6.1 flip.

### Phase 5–6 — Plan & Route
- Fix Plan: replace `unwrap()` with `unwrap_or_default()`. Files: 1. Risk: **MEDIUM** (intermittent, hard to fully reproduce).
- **6.1** frontmatter `status: done → bug`, `prior_status: done`; `ck-index` regenerates the views.
- **6.2 Gate:** Risk = MEDIUM fails a box → **MANUAL hand-off.**
- **6.3** Print the manual-build prompt: recommend `/ck-code:build tasks/.../profile-screen.md`. STOP.

### Key takeaway
A `MEDIUM`/`HIGH` risk or a lingering competing cause stops the auto-build so the user reviews before implementing. Everything is recorded; the fix resumes with one `build` call.

---

## Example 3: Bug already planned in TODO story 04-02 (verdict E)

- User runs `/ck-code:fix` (no args). Bug: profile form accepts blank `email`/`phone` → 500. File: `src/profile/profile_form.tsx`.
- **Pass 1 (active):** `[01-03] Profile screen scaffold` 0.62. **Pass 2 (todo):** `[04-02] Validate profile fields` 0.91 → `future_coverage_matches = [04-02]`.
- **Verdict E** takes precedence. Print the Phase 2.5e prompt recommending `/ck-code:build tasks/.../04-02-validate-profile.md`.
- User answers `Defer to build` → fix STOPS. No story write, no status flip.

### Key takeaway
Deferring keeps the planned story authoritative and the bug log clean — no duplicate one-line patch in 01-03.

---

## Example 4: Mixed — real bug + missing feature (verdict D)

- Bug: settings screen shows a stale device IP. Diagnosis pins a real bug in `[03-01] Settings screen` (`done`) AND surfaces that "persist IP to config" was never built (no story in epic 04).
- **Verdict D.** Phase 2.5c confirmation: UPDATE `[03-01]` (→ `bug`); CREATE one story via `/ck-code:plan --quick "persist device IP to config" --epic 04` (stays `todo`).
- **Phase 2.6** `plan --quick` scaffolds the new story's frontmatter + regenerates the indexes. `fix` diagnoses the real bug on `[03-01]`, records Bug Report + Fix Plan, flips `[03-01]` frontmatter to `bug` (`prior_status: done`) and runs `ck-index`.
- **6.2 Gate:** verdict D → **MANUAL hand-off.** Recommend `/ck-code:build tasks/.../03-01-settings-screen.md` for the bug; the new epic-04 story is normal `build` work later.

### Key takeaway
`fix` never scaffolds stories itself — missing functionality goes through `plan --quick` (existing epic) or `design` (no epic, verdict C). The real bug and the missing feature stay cleanly separated.

---

## Anti-pattern: fix implements the source fix (DO NOT DO THIS)

> "The off-by-one is one character — I'll just edit `handler.rs` and skip build."

Wrong. `fix` diagnoses and routes; `build` (Bug-Fix Mode) owns the TDD red→green, SOLID, QA, manual-test, and ship. Skipping build:
1. Bypasses the SOLID + QA + manual-test gates the fix must pass.
2. Leaves the `bug` status stuck — nothing restores the frontmatter from `prior_status` to `done`.

Record the Fix Plan and let `build` execute it. The only code `fix` writes is the failing reproduction test.
