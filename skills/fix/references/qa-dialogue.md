# QA & User Dialogue Scripts

User-facing prompts emitted by the `fix` skill, indexed by phase. Use verbatim or with minor wording adjustments so the workflow stays predictable. Phase branching logic lives in `SKILL.md`; this file is templates only. Confirmation gates are asked via `AskUserQuestion` — the report body below is the context; the trailing options map to the question's choices.

`fix` diagnoses and routes — it never implements. The implement / QA / manual-test / ship prompts live in `build` (Bug-Fix Mode), not here.

---

## Phase 1.2 — Story Selection (no path provided)

```
## Select the Story with the Bug

| # | Story | Epic | Status |
|---|-------|------|--------|
| 1 | [01-01] Setup server scaffold | Foundation | done |
| 2 | [01-02] gRPC service definition | Foundation | done |
| 3 | [01-03] WebSocket gateway | Foundation | in-progress |
| 4 | [02-01] Login form | Auth | bug |

Which story has the bug? (number, path, AUTO, or NONE)
```

---

## Phase 2.1 — Bug Description Questionnaire

```
## Describe the Bug

Story: [EE-SS] [Title]

1. Expected behavior?
2. Actual behavior?
3. Steps to reproduce?
4. Error messages or logs?
5. When did it start? (always / regression?)
```

### Phase 2.2 — Targeted Follow-ups (max 1-2)
- "Does this happen every time or intermittently?"
- "Which specific input or action triggers it?"
- "Did this work before a recent change?"

---

## Phase 2.5 — Scope Analysis Report

```
## Scope Analysis

**Bug summary:** [1-line]
**Verdict:** [SINGLE-STORY | MULTI-STORY | NEW-FEATURE | MIXED | PLANNED-IN-FUTURE]

### Best matches (done / in-progress / bug)
| Score | Story | Why |
|-------|-------|-----|
| 0.92 | [01-03] WebSocket gateway | overlaps `src/ws/handler.rs` (criterion #2) |
| 0.41 | [02-01] Login form | shares 1 file but unrelated symptom |

### Future coverage (todo — only when any score ≥ 0.5)
| Score | Story | Why |
|-------|-------|-----|
| 0.91 | [04-02] Validate profile fields | criterion match + file overlap |

### Verdict
A) SINGLE-STORY — bug belongs to [EE-SS]. Diagnose + record + route.
B) MULTI-STORY — bug spans [EE-SS], [EE-SS], …. Shared Bug ID `BUG-YYYYMMDD-NN`. Manual build hand-off.
C) NEW-FEATURE — missing functionality, no epic covers it. Recommend `/ck-code:design`. STOP after confirm.
D) MIXED — real bug in [EE-SS] AND a missing piece elsewhere. Diagnose the bug + create the missing story via `/ck-code:plan --quick`. Manual build hand-off.
E) PLANNED-IN-FUTURE — todo story [EE-SS] [Title] already plans this. Default STOP; recommend `/ck-code:build <future-story>`. Override `PROCEED ANYWAY` falls through to A/B/D.

Confirm verdict? (AskUserQuestion: Confirm verdict / Adjust / Abort)
```

### Verdict A — Combined Prompt (fast-path, replaces Phase 2.5.5 gate)

When the verdict is A (single-story), append this block to the scope report instead of the generic verdict prompt above — it folds the verdict confirmation and the (trivial) story-set confirmation into one gate:

```
**Scope:** single-story `[EE-SS] [Title]` (no new stories to create, one status flip).

Proceed with diagnosis on this story? (AskUserQuestion: Proceed / Adjust / Abort)
```

On `Proceed`: go directly to Phase 3 (no Phase 2.5.5 gate). On `Adjust`: re-score with overrides and re-present. Verdicts B / D continue to use Phase 2.5.5 separately.

---

## Phase 2.5b — New-Feature Deferral (verdict C)

```
## Stop — This Looks Like a New Feature, Not a Bug

What you described isn't a regression — it's behavior that was never built, and no epic covers it. A new feature goes through the normal flow, which starts with architecture: `design` → `team` → `plan`. Don't skip straight to story planning.

Suggested next step:
  /ck-code:design <path-to-spec-or-feature-description>

`design` produces the architecture docs that `plan` later turns into epics and stories.

Proceed anyway? (AskUserQuestion: Stop — run design (recommended) / Force fix flow — treat as MIXED)
```

Default to stop. On force: fall through to verdict D handling.

---

## Phase 2.5e — Future-Story Coverage Deferral (verdict E)

```
## Stop — A Future Story Already Plans This Fix

The bug is already covered by acceptance criteria in a planned TODO story. Fixing now would duplicate planned work.

**Future stories covering this fix:**
- [EE-SS] [Title] (score: 0.XX) — matched on: [files / criteria / component]

Suggested next step:
  /ck-code:build tasks/<slug>/epics/<epic>/stories/<file>.md

That run implements the fix as part of the planned story.

Proceed anyway? (AskUserQuestion: Defer to build (recommended) / Proceed anyway — force fix now)
```

Default to defer. On proceed anyway: fall through to the A/B/D verdict from `active_scores`. Never create stories under verdict E.

---

## Phase 2.5c — Multi-Story / Missing-Story Confirmation (verdicts B / D)

```
## Story Set for This Fix

**Bug ID:** BUG-YYYYMMDD-NN

### Will UPDATE (append Bug Report, flip frontmatter status → bug)
- tasks/<slug>/epics/01_foundation/stories/03_websocket-gateway.md  [01-03]  (done → bug)
- tasks/<slug>/epics/02_auth/stories/01_login-form.md                [02-01]  (done → bug)

### Will CREATE via /ck-code:plan --quick (verdict D — missing functionality, stays todo)
- epic 03 · Mobile   — "show device IP on settings screen"   (size: S)
- epic 04 · Desktop  — "persist device IP to config"          (size: S)

These new stories are real feature work (todo), NOT part of this bug's bug set. `plan --quick` writes each story's frontmatter and regenerates the indexes.

### Routing
Multi-story / mixed bug → **manual build hand-off** after recording (Auto-Build Eligibility Gate fails). You'll run `/ck-code:build` per story, or pass several story IDs to build them at once.

Proceed? (AskUserQuestion: Proceed / Adjust / Abort)
```

---

## Phase 4.6 — Diagnosis Report

```
## Bug Diagnosis Report

**Story:** [EE-SS] [Title]  (prior status: done)
**Bug:** [1-line summary]
**Root cause:** [explanation]
**Location:** [file:line]
**Reproduction test:** Written and FAILING (the RED target build will take to GREEN)
**Story:** Updated with Bug Report (status DIAGNOSED)

### Related Issues
- [count] similar patterns found (documented for separate /ck-code:fix runs)

### Affected Acceptance Criteria
- [ ] [Criterion X] — BROKEN by this bug
- [x] [Criterion Y] — Still working

Confirm diagnosis and proceed to the Fix Plan? (AskUserQuestion: Confirm & continue / Investigate more)
```

---

## Phase 5.3 — Fix Plan Confirmation

```
## Proposed Fix Plan (build will implement this — fix does not)

**Root cause:** [1-line]
**Strategy:** [1-line — what build changes and why it fixes the root cause]
**Files to modify:** [exact paths]
**Test target:** [reproduction test name] must go GREEN
**Risk:** [LOW / MEDIUM / HIGH]

Record this plan into the story and route? (AskUserQuestion: Record & route / Adjust / Abort)
```

---

## Phase 6 — Auto-Build (easy fix)

Printed when the Auto-Build Eligibility Gate passes (verdict A, single confirmed cause, ≤ 3 files, LOW risk, no new story/design).

```
## Fix Recorded — Auto-Building

**Story:** [EE-SS] [Title]  →  status bug (was done; prior_status recorded)
**Bug ID:** BUG-YYYYMMDD-NN
**Fix Plan + failing test:** recorded in the story.

Easy fix — invoking /ck-code:build now to implement it (Bug-Fix Mode).
build will take the reproduction test RED → GREEN, run SOLID + QA + manual test,
ship, and restore the story to its prior status (done).
```

Then invoke `/ck-code:build <story-path>` via the Skill tool.

---

## Phase 6 — Manual Build Hand-off (complex fix)

Printed when the Auto-Build Eligibility Gate fails (multi-story, high-risk, large diff, uncertain cause, or a new story/design was needed).

```
## Fix Recorded — Manual Build Needed

This fix is complex, so it's recorded but NOT auto-built:
  reason: [multi-story | high-risk | >3 files | uncertain root cause]

**Stories flipped to bug:**
- [01-03] WebSocket gateway   (done → bug)
- [02-01] Login form          (done → bug)

Each carries its Bug Report, failing reproduction test, and Fix Plan.

Run when ready:
  /ck-code:build tasks/<slug>/epics/<epic>/stories/<file>.md      # one story
  /ck-code:build 01-03 02-01                                      # several at once

build enters Bug-Fix Mode, implements the recorded Fix Plan, and restores each story's prior_status.
```

STOP after printing — do not implement the fix inside `fix`.
