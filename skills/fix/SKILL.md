---
name: fix
description: Use to diagnose a bug tied to one or more existing stories and record it into the backlog for implementation. Reproduces the bug, writes a diagnosis + failing test + Fix Plan into the story, flips its status to BUG, then routes — auto-runs build for an easy single-story fix, or stops and hands off to build/parallel-build when complex. Defers to design (no epic) or quick-story (missing story). Argument is an optional story file path.
argument-hint: "[path-to-story.md]"
disable-model-invocation: true
---

# Fix — Bug Triage & Routing Orchestrator

Diagnoses a story-linked bug, records the diagnosis + failing reproduction test + Fix Plan into the story, flips the story's status to `BUG`, and routes the fix. `fix` does NOT implement the fix — `build` does (Bug-Fix Mode). An easy single-story fix auto-invokes `build`; a complex one stops for a manual `build` / `parallel-build`. Always confirms scope before writing.

References: [examples.md](references/examples.md) (worked triage walkthroughs) · [qa-dialogue.md](references/qa-dialogue.md) (user-facing prompt scripts) · [bug-section-template.md](references/bug-section-template.md) (story-file bug sections — the fix→build contract) · [`stories-index.md`](../../references/stories-index.md) (index/epic sync contract) · [`feature-index.md`](../../references/feature-index.md) (feature rollup).

## ROUTING CHECK (do first)

This skill **diagnoses a bug** tied to an existing story and hands the fix to `build`.
If the request is actually something else, STOP and recommend the better skill:

- New functionality / new acceptance criteria (not a bug) → `/ck-code:quick-story` then `/ck-code:build`
- Just committing a finished change → `/ck-code:ship`

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:build <story-path>` (auto-invoked when the fix is easy).

## INPUT

`$ARGUMENTS` is an optional path to the story file. If provided, read it as a starting candidate (Phase 2.5 may still expand scope). If empty, enter interactive story selection (Phase 1.2) with `AUTO` as a supported answer.

## PHASE 1: CANDIDATE STORY SELECTION

**Goal:** Pick the initial candidate story (the scope analyzer in Phase 2.5 may add more).

### 1.1 If Story Path Provided

Read `$ARGUMENTS`, validate it exists and has the expected format, then confirm: "Starting candidate is story [EE-SS]: [Title]. Scope analysis after bug description may expand this — correct?"

### 1.2 If No Story Path (Interactive)

Read `tasks/<slug>/STORIES_INDEX.md` (bootstrap if missing — see [`../../references/stories-index.md`](../../references/stories-index.md) Read Protocol). Filter to `Status: DONE`, `IN PROGRESS`, or `BUG`, then present the selection table from `references/qa-dialogue.md` (Phase 1.2). Supported answers:

- A row number / story path → use as candidate.
- `AUTO` → skip manual pick; Phase 2.5 will score every candidate after the bug description.
- `NONE` → ask for a free-form bug description and component; map to a story by file path. If no match, create a standalone bug report (no story linkage) and proceed.

### 1.3 Load Story Context

Once a candidate is selected (or `AUTO`):

**Batch 1 (parallel tool-call message):** read the candidate story file AND parent `EPIC.md` — the index row's `File` column encodes the epic folder, so EPIC.md is computable without parsing the story first.

From the story file extract: acceptance criteria, Files Touched, technical notes, Implementation Summary (from `/ck-code:build`).

**Batch 2 (parallel tool-call message, after parsing Batch 1):** read this bug's **feature doc** — `folder-structure.md` + the feature doc named in the affected feature's `FEATURE_INDEX` `Docs` column (+ `_shared.md` when the bug is cross-cutting). Do not read the retired layer docs; if the `Docs` cell is `—`/missing, read `folder-structure.md` + `_shared.md` and suggest `/ck-code:doc-optimizer sync`. This batch is sequential to Batch 1 but every file inside it is parallel.

For `AUTO`, defer both batches until Phase 2.5 narrows the candidate set.

## PHASE 2: BUG DESCRIPTION

**Goal:** Get a clear bug description from the user.

### 2.1 Ask About the Bug

Present the questionnaire from `references/qa-dialogue.md` (Phase 2.1).

### 2.2 Targeted Follow-ups

Ask at most 1-2 follow-ups (intermittent vs. consistent, trigger input, recent regression). See `references/qa-dialogue.md`.

## PHASE 2.5: SCOPE ANALYSIS (mandatory)

**Goal:** Determine whether the bug is single-story, multi-story, a missing feature, or mixed — and confirm with the user before any story file write.

### 2.5.1 Score Candidate Stories

Read `tasks/<slug>/STORIES_INDEX.md`. Compute relevance scores in **two passes** using the same three signals:

- **File overlap** — does the bug area (paths inferred from the description, error messages, or stack trace) intersect the story's `Files Touched` (DONE / IN PROGRESS / BUG) or technical-notes file list (TODO)?
- **Criterion match** — does any acceptance criterion mention the broken behavior?
- **Component / epic match** — does the bug component match the parent epic's scope?

**Pass 1 — `active_scores`:** every `DONE` / `IN PROGRESS` / `BUG` row.
**Pass 2 — `todo_scores`:** every `TODO` row. Collect rows scoring ≥ 0.7 into `future_coverage_matches` — these mean the fix is already planned in a future story.

Pick the verdict:
| Verdict | Trigger |
|---|---|
| **A) SINGLE-STORY** | One story scores ≥ 0.7 and no other ≥ 0.5 (in `active_scores`) |
| **B) MULTI-STORY** | Two or more existing stories score ≥ 0.5 (in `active_scores`) |
| **C) NEW-FEATURE** | No story scores ≥ 0.5 AND symptom describes behavior never built (no matching code path exists) |
| **D) MIXED** | At least one existing story scores ≥ 0.5 AND the bug also requires functionality in epics where no story covers it |
| **E) PLANNED-IN-FUTURE** | `future_coverage_matches` is non-empty. **Takes precedence** over A / B / D when a TODO story matches — present E first; the user may `PROCEED ANYWAY` to fall through to the underlying A / B / D verdict. |

### 2.5.2 Present Scope Report

Use the report in `references/qa-dialogue.md` (Phase 2.5). Wait for explicit `YES` (or `ADJUST` to override the verdict / story set). On `ADJUST`, re-score with the user's overrides and re-present.

**Verdict A fast-path:** when the verdict is A (single-story, no new stories to create), the Phase 2.5 report uses the verdict-A combined prompt — one gate covers both the verdict and the (trivial) story set. **Skip Phase 2.5.5 entirely and proceed to Phase 3 on `YES`.** Verdicts B / D still flow through Phase 2.5.5 separately because the story set adds real information (new stories, epic syncs).

### 2.5.3 Verdict C (NEW-FEATURE) — Defer to /ck-code:design

A new feature (no epic covers it) must enter the **normal flow** — `design` → `team` → `plan` — not jump straight to story planning. Print the deferral prompt from `references/qa-dialogue.md` (Phase 2.5b), which recommends `/ck-code:design <spec-or-feature-description>` first (it produces the architecture docs that `plan` later consumes). **STOP** unless the user explicitly forces the fix flow (which falls through to verdict D handling). Do NOT create stories under verdict C — `design` then `plan` handle that with full architecture context.

### 2.5.4 Verdict E (PLANNED-IN-FUTURE) — Defer to /ck-code:build

Print the deferral prompt from `references/qa-dialogue.md` (Phase 2.5e). Default action is to **STOP** and recommend `/ck-code:build <future-story-path>` for the highest-scoring TODO story in `future_coverage_matches`. The user may type `PROCEED ANYWAY` to force the fix flow — in that case fall through to the original verdict (A / B / D) computed from `active_scores` and continue. Do NOT create stories under verdict E — the planned story already exists.

### 2.5.5 Verdicts B / D only — Confirm Story Set

_(Skipped for Verdict A — the combined prompt in Phase 2.5.2 already covers it.)_

Present the story-set confirmation from `references/qa-dialogue.md` (Phase 2.5c) listing every story to UPDATE (flip to `BUG`) and, for verdict D, every missing-functionality story to CREATE **via `/ck-code:quick-story`**. Wait for `YES`.

## PHASE 2.6: CREATE MISSING STORIES (verdict D only)

**Goal:** Scaffold the missing-functionality stories through the purpose-built skill, not inline.

For each missing-functionality slot identified in 2.5.1, invoke `/ck-code:quick-story "<one-line brief distilled from the bug>" --epic NN` (target epic from the scope analysis). `quick-story` writes the story file and keeps `STORIES_INDEX.md`, `EPIC.md`, and `FEATURE_INDEX.md` in sync — `fix` never writes stub story files or index rows itself. The created story stays `TODO` (real feature work planned later); it is NOT part of this bug's `BUG`-status set. If `quick-story` reports a sync failure, tell the user `Story scaffold failed — run /ck-code:sync to reconcile` and continue triaging the real bug on the existing story only.

## PHASE 3: SKILL DETECTION & CONTEXT LOADING

**Goal:** Load the right expert and guide skills for the affected code.

### 3.1 Detect & Load Skills

Follow the shared procedure in [`../../references/skill-detection.md`](../../references/skill-detection.md). Experts/guides are matched by each present skill's `paths`/`keywords` frontmatter (anchor tables as fallback) — the slug set is project-derived, not fixed. For bug-fix flows, **both `expert-qa` AND `expert-analyst` are always loaded** (analyst drives root-cause analysis), and `guide-conventions` always loads when present. Architecture-doc reads (Step 1) and skill loads (Step 4b) must each be issued as a single parallel tool-call message — see the batching notes in `skill-detection.md`.

### 3.2 Prepare Systematic Debugging Approach

Before any diagnosis, form a structured investigation plan:

1. Read the failing code path from entry point to point of failure.
2. List all assumptions the code makes at each step.
3. For each assumption, identify how it could be violated.
4. Form a hypothesis for the root cause **before** reading more code.
5. Only then read deeper to confirm or disprove the hypothesis.

This prevents "grep-driven debugging" — reasoning about a fix without understanding why it broke.

## PHASE 4: QA REPRODUCTION & DIAGNOSIS

**Goal:** QA expert reproduces the bug and confirms diagnosis. This is the heart of `fix`.

**Always delegate reproduction to `ck-code:qa-validator`** (Haiku) — it writes the minimal
failing test and returns a root-cause hypothesis. Do the steps below inline **only** when
that subagent_type is unregistered.

### 4.1 Locate the Buggy Code

Identify likely source files (Grep + the story's file list), read source + existing tests, trace the execution path that triggers the bug.

### 4.1.5 Parallel hypothesis investigation (fan-out — verdict B/D or ≥2 competing causes only)

When diagnosis spans multiple subsystems (Phase 2.5 verdict **B**/MULTI-STORY or **D**/MIXED) or
Phase 3.2 produced **≥2 plausible competing root causes**, dispatch one **read-only** investigator
per hypothesis (cap 2–4) following the investigation variant in
[../../references/subagent-fanout.md](../../references/subagent-fanout.md) — `model: haiku`,
since tracing a suspect path is mechanical. Each agent traces ONE
suspect path and returns `{hypothesis, confidence, file:line evidence, confirm/refute}` — no edits.
The orchestrator converges the reports to the **single** highest-confidence root cause
before 4.2 (never carry two forward). Skip entirely for verdict A or any obvious single-cause bug —
go straight to 4.2. **A leftover competing root cause is a complexity signal** — it forces the manual hand-off at Phase 6.2.

### 4.2 Reproduce the Bug — write a FAILING test (the fix→build contract)

1. **Check existing tests** for this scenario: passes → test is wrong/insufficient; fails → confirms the bug; no coverage → gap identified.
2. **Write a reproduction test that FAILS because of the bug.** Format: `Test: "should [expected behavior] when [trigger condition]" → Currently FAILS with: [actual behavior]`.
3. **Run the reproduction test** — confirm it fails.

This failing test is the concrete **RED target `build` takes to GREEN** — it stays in the working tree and its name is recorded in the Bug Report. **The diagnosis is not complete without it.** `fix` writes this test but never writes the source fix — that is `build`'s job.

### 4.3 Root Cause Analysis

Produce a diagnosis block with: Symptom, Reproduction (test), Root cause, Location (file:line), Why it happened (logic error / missing check / wrong assumption / etc.), Impact scope.

### 4.4 Check for Related Issues

Grep for similar patterns that might share the bug; check whether the root cause affects other acceptance criteria; list related issues by `file:line` flagged as "same pattern" or "similar but not identical". **Do NOT open those as separate work here** — document them and tell the user to run `/ck-code:fix` on those separately.

### 4.5 Update Story Files with Bug Details

Immediately after diagnosis, append the Bug Report section to **every story file in scope** (single story for verdict A; all stories in the confirmed set for B / D). Use the same `Bug ID` (`BUG-YYYYMMDD-NN`) across all of them. Record the story's **Prior status** (the `Status:` before this bug — `DONE` / `IN PROGRESS`) so `build` can restore it. Bug Report status: `DIAGNOSED`. Templates: `references/bug-section-template.md` (Phase 4.5 single-story / Phase 4.5b multi-story). This creates a permanent record of the bug and its diagnosis before any fix begins.

### 4.6 Present Diagnosis to User

Use the diagnosis report script in `references/qa-dialogue.md` (Phase 4.6). Wait for `YES` or `INVESTIGATE MORE`. If `INVESTIGATE MORE`: ask which aspect to investigate, run more analysis, re-present.

## PHASE 5: FIX PLAN (the build contract)

**Goal:** Write a concrete, build-consumable Fix Plan into the story. `fix` plans; `build` implements.

### 5.1 Design the Minimal Fix

The plan must describe the **smallest possible change** that resolves the root cause — no refactoring, no features, no "improvements" to unrelated code. Produce a Fix Plan stating: **Strategy** (what to change and why it fixes the root cause), **Files to modify** (exact paths, minimal), **Test target** (the Phase 4.2 reproduction test that must go GREEN), **Risk** (`LOW` / `MEDIUM` / `HIGH`), and any **SOLID note** (if the minimal fix must bend a principle, name the smallest abstraction that avoids it — `build` verifies SOLID against the diff).

This plan is the contract `build` (Bug-Fix Mode) executes verbatim. Vague plans force `build` to re-diagnose — be specific enough that another skill can implement it without guessing.

### 5.2 Record the Fix Plan in Story Files

Append the Fix Plan subsection to the Bug Report section created in Phase 4.5 — in **every** story file in scope. Bug Report status stays `DIAGNOSED` (fix does not apply the fix). Template: `references/bug-section-template.md` (Phase 5.2).

### 5.3 Confirm Fix Plan

Use the proposed-fix prompt in `references/qa-dialogue.md` (Phase 5.3). Wait for `YES`, `ADJUST`, or `ABORT`.

## PHASE 6: SET BUG STATUS & ROUTE

**Goal:** Flip the story to `BUG`, sync the indexes, then route the fix — auto-build when easy, hand off when complex.

### 6.1 Set BUG Status (story file + index + feature index, same phase)

For **every existing story in scope** (verdict A: one; B / D: all matched existing stories — never the `TODO` stories created in Phase 2.6):

1. Edit the story file: `Status: <prior> → Status: BUG`.
2. Edit `tasks/<slug>/STORIES_INDEX.md`: change that story's `Status` cell to `BUG` (cell-only Edit — see [`../../references/stories-index.md`](../../references/stories-index.md) Mutation Protocol).
3. Edit `tasks/FEATURE_INDEX.md`: recompute the affected feature's `Status` rollup — any `BUG` story rolls the feature to `IN PROGRESS`, and `BUG` counts as not-done in `done/total` (per [`../../references/feature-index.md`](../../references/feature-index.md)).

The story file and both indexes must never disagree — all three edits happen in this phase. After the writes, re-read the index rows to confirm each `Status` cell reads `BUG`; on a mismatch tell the user `Index drift detected — run /ck-code:sync to reconcile` and continue.

### 6.2 Auto-Build Eligibility Gate

Decide AUTO-BUILD vs MANUAL hand-off. **AUTO-BUILD only when ALL hold:**

- [ ] Verdict **A** (exactly one existing story in scope).
- [ ] **Single confirmed root cause** — no leftover competing hypothesis from 4.1.5.
- [ ] Fix Plan **Files to modify ≤ 3** (small blast radius).
- [ ] Fix Plan **Risk = LOW**.
- [ ] No new story (Phase 2.6) and no `design` were needed.

If **any** box is unchecked, it is a **MANUAL hand-off** (complex). Multi-story (B / D), high-risk, large-diff, or uncertain-cause fixes always stop for a manual build.

### 6.3 Route

- **AUTO-BUILD** → announce with the Phase 6 auto-build prompt in `references/qa-dialogue.md`, then invoke `/ck-code:build <story-path>` via the Skill tool. `build` detects the `BUG` status, enters **Bug-Fix Mode**, takes the reproduction test RED → GREEN per the Fix Plan, runs SOLID + QA + manual-test, ships, and restores the story's prior status. `fix` ends here.
- **MANUAL hand-off** → print the manual-build prompt in `references/qa-dialogue.md` (Phase 6 manual). Recommend `/ck-code:build <primary-story>` (highest-scored story), or `/ck-code:parallel-build <ids>` for a multi-story bug. **STOP** — everything is recorded; the user runs `build` when ready. Do NOT implement the fix inside `fix`.

## HARD GATES (cross-phase contract)

Each gate is enforced inside its phase; this is the checklist.

- **Version gate** — before any architecture-doc read/write: `tasks/VERSION.md` reads `layout: v3` → proceed; else run the [shared procedure](../../references/version-gate.md).
- **Phase 2.5** — scope analysis mandatory, even with an explicit story path.
- **Phase 2.5.1** — score `TODO` rows too; a TODO match triggers verdict E.
- **Phase 2.5.2 / 2.5.5 / 5.3** — confirmation gates; never write without an explicit `YES`.
- **Phase 2.6** — missing stories are created by `/ck-code:quick-story`, never inline.
- **Phase 4.2** — a failing reproduction test is mandatory before Phase 5; it is the RED target `build` inherits.
- **Phase 6.1** — story file, `STORIES_INDEX.md`, and `FEATURE_INDEX.md` flipped to/rolled-up for `BUG` in the same phase.
- **Phase 6.2 / 6.3** — the Auto-Build Eligibility Gate is deterministic; a single unchecked box forces MANUAL hand-off.

### Scope discipline (cross-cutting)

- **`fix` never writes the source fix** — it diagnoses, writes the failing test + Fix Plan, and hands implementation to `build` (Bug-Fix Mode). It writes test files, story files, and index cells only.
- **Never diagnose a bug from another story inline** — document it in the Phase 4.4 related-issues note for a separate `/ck-code:fix` run.
- **Never create stories inline** — verdict D missing functionality goes through `/ck-code:quick-story` (existing epic) or `/ck-code:design` (verdict C, no epic).
- **Verdict E (PLANNED-IN-FUTURE)** → defer to `/ck-code:build <future-story>`; `PROCEED ANYWAY` bypasses no other gate.

### Universal

- **Always use the same `Bug ID`** (`BUG-YYYYMMDD-NN`) across every in-scope story.
- **Always record Prior status** in the Bug Report so `build` can restore it.
- **Always output in English.**

---

## NEXT

- **Easy fix** → `fix` already invoked `/ck-code:build <story>`; follow `build` through to `/ck-code:ship`.
- **Complex fix** → run `/ck-code:build <primary-story>` (or `/ck-code:parallel-build <ids>`) when ready; `build` enters Bug-Fix Mode, implements the recorded Fix Plan, and flips the story back to its prior status.

To drive an auto-build regression loop autonomously, the user can set `/goal "the new regression test passes and the full suite stays green"` (cheap verifier model). See [native-commands.md](../../references/native-commands.md).
