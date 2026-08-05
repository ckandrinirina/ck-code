---
name: fix
description: Use when the user reports a bug in already-built behavior tied to one or more existing stories, or asks to diagnose, reproduce, or triage a defect and record it for fixing. Not for new functionality (use plan) or for shipping a finished change (use ship). Argument is an optional story-file path.
argument-hint: "[path-to-story.md]"
disable-model-invocation: true
effort: high
allowed-tools: Bash(ck-index*) Bash(ck-project*) Bash(git status*) Bash(git diff*) Bash(git log*) Bash(git show*) Bash(git blame*) Bash(git branch*) Bash(git bisect*) Bash(git add*) Bash(git commit*)
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/no-ai-guard.sh"
---

# Fix — Bug Triage & Routing Orchestrator

Diagnoses a story-linked bug, records the diagnosis + a FAILING reproduction test + a Fix Plan into the story, flips the story's frontmatter to `status: bug` (recording `prior_status`), and routes the fix. `fix` does NOT implement the fix — `build` does (Bug-Fix Mode). An easy single-story fix auto-invokes `build`; a complex one stops for a manual `build` run. Always confirms scope before writing.

References: [examples.md](references/examples.md) (worked triage walkthroughs) · [qa-dialogue.md](references/qa-dialogue.md) (user-facing prompt scripts) · [bug-section-template.md](references/bug-section-template.md) (story-file bug sections — the fix→build contract) · [`data-model.md`](../../references/data-model.md) (frontmatter source of truth) · [`stories-index.md`](../../references/stories-index.md), [`feature-index.md`](../../references/feature-index.md) (generated read-only views).

## ROUTING CHECK (do first)

This skill **diagnoses a bug** tied to an existing story and hands the fix to `build`.
If the request is actually something else, STOP and recommend the better skill:

- New functionality / new acceptance criteria (not a bug) → `/ck-code:plan --quick "<brief>"` then `/ck-code:build`
- Just committing a finished change → `/ck-code:ship`

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:build <story-path>` (auto-invoked when the fix is easy).

## INPUT

`$ARGUMENTS` is an optional path to the story file. If provided, read it as a starting candidate (Phase 2.5 may still expand scope). If empty, enter interactive story selection (Phase 1.2) with `AUTO` as a supported answer.

## PROGRESS TRACKING

Open a `TodoWrite` list as the **first action of Phase 0** — one todo per phase this run will
actually execute — then flip each to `in_progress` when it starts and `completed` when its
gate passes. Drop a phase that mode routing skips; never leave it pending. A long run's only
view into where it is comes from this list, so update it as you go and never batch the
updates to the end.

## PHASE 0: VERSION GATE (hard gate)

The stamp is injected at skill-load time — **do not spend a `Read` on it**:

Layout stamp: !`cat "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tasks/VERSION.md" 2>/dev/null || echo "ABSENT — no tasks/VERSION.md"`

Reads `layout: v6` → **PASS**, proceed. Anything else (including `ABSENT`) → run the
shared [version gate](../../references/version-gate.md) (HARD GATE) — it detects a pre-v6
layout, offers `/ck-code:migrate`, and stamps. Never read or write project state before
this PASSes.

## PHASE 1: CANDIDATE STORY SELECTION

**Goal:** Pick the initial candidate story (the scope analyzer in Phase 2.5 may add more).

### 1.1 If Story Path Provided

Read `$ARGUMENTS`, validate it exists and has the expected frontmatter (`id`, `status`, …), then confirm via `AskUserQuestion`: "Starting candidate is story [EE-SS]: [Title]. Scope analysis after the bug description may expand this — proceed?" Options: `Proceed` / `Pick another`.

### 1.2 If No Story Path (Interactive)

Read `tasks/<slug>/STORIES_INDEX.md` (regenerate if missing/stale — see [`stories-index.md`](../../references/stories-index.md) Read Protocol). Filter to `done`, `in-progress`, or `bug` rows, then present the selection table from `references/qa-dialogue.md` (Phase 1.2). Supported answers:

- A row number / story path → use as candidate.
- `AUTO` → skip manual pick; Phase 2.5 will score every candidate after the bug description.
- `NONE` → ask for a free-form bug description and component; map to a story by file path. If no match, create a standalone bug report (no story linkage) and proceed.

### 1.3 Load Story Context

Once a candidate is selected (or `AUTO`):

**Batch 1 (parallel tool-call message):** read the candidate story file. From its frontmatter extract `status`, `epic`, `files`; from its body extract acceptance criteria, technical notes, and the Implementation Summary (from `/ck-code:build`).

**Batch 2 (parallel tool-call message, after parsing Batch 1):** read this bug's **feature doc** — `docs/architecture/features/<slug>/index.md`, the path in the affected feature's `Docs` column of `tasks/FEATURE_INDEX.md`. If the `Docs` cell is `—`/missing, note it and suggest `/ck-code:design` to author the feature doc, then continue on the story context alone.

For `AUTO`, defer both batches until Phase 2.5 narrows the candidate set.

## PHASE 2: BUG DESCRIPTION

**Goal:** Get a clear bug description from the user.

### 2.1 Ask About the Bug

Present the questionnaire from `references/qa-dialogue.md` (Phase 2.1).

### 2.2 Targeted Follow-ups

Ask at most 1-2 follow-ups (intermittent vs. consistent, trigger input, recent regression). See `references/qa-dialogue.md`.

## PHASE 2.5: SCOPE ANALYSIS (mandatory)

**Goal:** Determine whether the bug is single-story, multi-story, a missing feature, or mixed — and confirm with the user before any story write.

### 2.5.1 Score Candidate Stories

Read `tasks/<slug>/STORIES_INDEX.md`. Compute relevance scores in **two passes** using the
same three signals. A story's score is the **sum of the weights of the signals it matches**
(0 to 1.0):

- **File overlap (weight 0.5)** — the bug area (paths inferred from the description, error messages, or stack trace) intersects the story's `files` frontmatter (any status) or technical-notes file list (`todo`).
- **Criterion match (weight 0.3)** — an acceptance criterion mentions the broken behavior.
- **Component / epic match (weight 0.2)** — the bug component matches the parent epic's scope.

**Pass 1 — `active_scores`:** every `done` / `in-progress` / `bug` row.
**Pass 2 — `todo_scores`:** every `todo` row. Collect rows scoring ≥ 0.7 into `future_coverage_matches` — these mean the fix is already planned in a future story.

Pick the verdict:
| Verdict | Trigger |
|---|---|
| **A) SINGLE-STORY** | One story scores ≥ 0.7 and no other ≥ 0.5 (in `active_scores`) |
| **B) MULTI-STORY** | Two or more existing stories score ≥ 0.5 (in `active_scores`) |
| **C) NEW-FEATURE** | No story scores ≥ 0.5 AND the symptom describes behavior never built (no matching code path exists) |
| **D) MIXED** | At least one existing story scores ≥ 0.5 AND the bug also requires functionality in an epic where no story covers it |
| **E) PLANNED-IN-FUTURE** | `future_coverage_matches` is non-empty. **Takes precedence** over A / B / D when a `todo` story matches — present E first; the user may `PROCEED ANYWAY` to fall through to the underlying A / B / D verdict. |

### 2.5.2 Present Scope Report

Present the report body in `references/qa-dialogue.md` (Phase 2.5) and confirm via `AskUserQuestion` (options: `Confirm verdict` / `Adjust` / `Abort`). On `Adjust`, re-score with the user's overrides and re-present.

**Verdict A fast-path:** when the verdict is A (single-story, no new stories to create), use the verdict-A combined prompt — one `AskUserQuestion` gate covers both the verdict and the (trivial) story set. **Skip Phase 2.5.5 entirely and proceed to Phase 3 on `Proceed`.** Verdicts B / D still flow through Phase 2.5.5 separately because the story set adds real information (new stories).

### 2.5.3 Verdict C (NEW-FEATURE) — Defer to /ck-code:design

A new feature (no epic covers it) must enter the **normal flow** — `design` → `team` → `plan` — not jump straight to story planning. Print the deferral prompt from `references/qa-dialogue.md` (Phase 2.5b), which recommends `/ck-code:design <spec-or-feature-description>` first (it produces the architecture docs that `plan` later consumes). **STOP** unless the user explicitly forces the fix flow (which falls through to verdict D handling). Do NOT create stories under verdict C — `design` then `plan` handle that with full architecture context.

### 2.5.4 Verdict E (PLANNED-IN-FUTURE) — Defer to /ck-code:build

Print the deferral prompt from `references/qa-dialogue.md` (Phase 2.5e). Default action is to **STOP** and recommend `/ck-code:build <future-story-path>` for the highest-scoring `todo` story in `future_coverage_matches`. The user may choose `PROCEED ANYWAY` to force the fix flow — in that case fall through to the original verdict (A / B / D) computed from `active_scores` and continue. Do NOT create stories under verdict E — the planned story already exists.

### 2.5.5 Verdicts B / D only — Confirm Story Set

_(Skipped for Verdict A — the combined prompt in Phase 2.5.2 already covers it.)_

Present the story-set confirmation from `references/qa-dialogue.md` (Phase 2.5c) listing every story to UPDATE (flip to `bug`) and, for verdict D, every missing-functionality story to CREATE **via `/ck-code:plan --quick`**. Confirm via `AskUserQuestion` (`Proceed` / `Adjust` / `Abort`).

## PHASE 2.6: CREATE MISSING STORIES (verdict D only)

**Goal:** Scaffold the missing-functionality stories through the purpose-built skill, not inline.

For each missing-functionality slot identified in 2.5.1, invoke `/ck-code:plan --quick "<one-line brief distilled from the bug>" --epic NN` (target epic from the scope analysis). `plan --quick` (its single-story mode) writes the story file's frontmatter and regenerates the indexes — `fix` never writes stub story files or index rows itself. The created story stays `todo` (real feature work planned later); it is NOT part of this bug's `bug`-status set. If `plan --quick` fails, tell the user the scaffold failed and continue triaging the real bug on the existing story only.

## PHASE 3: SKILL DETECTION & CONTEXT LOADING

**Goal:** Load the right expert and guide skills for the affected code.

### 3.1 Detect & Load Skills

Follow the shared procedure in [`skill-detection.md`](../../references/skill-detection.md). Experts/guides are matched by each present skill's `paths`/`keywords` frontmatter (anchor tables as fallback) — the slug set is project-derived, not fixed. For bug-fix flows, **`expert-qa`, `expert-qa-project`, AND `expert-analyst` are always loaded** (analyst drives root-cause analysis), and `guide-conventions` always loads when present. Architecture-doc reads (Step 1) and skill loads (Step 4b) must each be issued as a single parallel tool-call message — see the batching notes in `skill-detection.md`.

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
failing test and returns a root-cause hypothesis, keeping verbose test output off the
orchestrator. Do the steps below inline **only** when that subagent_type is unregistered.

### 4.1 Locate the Buggy Code

Identify likely source files (Grep + the story's `files` list), read source + existing tests, trace the execution path that triggers the bug.

### 4.1.5 Parallel hypothesis investigation (fan-out decision — take it before tracing)

Decide and announce this branch in one line before tracing any suspect path. When diagnosis spans multiple subsystems (Phase 2.5 verdict **B**/MULTI-STORY or **D**/MIXED) or Phase 3.2 produced **≥2 plausible competing root causes**, dispatch one **read-only** investigator per hypothesis (cap 2–4) following the investigation variant in [subagent-fanout.md](../../references/subagent-fanout.md) — `model: haiku`, since tracing a suspect path is mechanical. Each agent traces ONE suspect path and returns `{hypothesis, confidence, file:line evidence, confirm/refute}` — no edits. The orchestrator converges the reports to the **single** highest-confidence root cause before 4.2 (never carry two forward). Skip entirely for verdict A or any obvious single-cause bug — go straight to 4.2. **A leftover competing root cause is a complexity signal** — it forces the manual hand-off at Phase 6.2.

### 4.2 Reproduce the Bug — write a FAILING test (the fix→build contract)

1. **Check existing tests** for this scenario: passes → test is wrong/insufficient; fails → confirms the bug; no coverage → gap identified.
2. **Write a reproduction test that FAILS because of the bug.** Format: `Test: "should [expected behavior] when [trigger condition]" → Currently FAILS with: [actual behavior]`.
3. **Run the reproduction test** — confirm it fails.

This failing test is the concrete **RED target `build` takes to GREEN** — it stays in the working tree and its name is recorded in the Bug Report. **The diagnosis is not complete without it.** `fix` writes this test but never writes the source fix — that is `build`'s job.

### 4.3 Root Cause Analysis

Produce a diagnosis block with: Symptom, Reproduction (test), Root cause, Location (file:line), Why it happened (logic error / missing check / wrong assumption / etc.), Impact scope.

### 4.4 Check for Related Issues

Grep for similar patterns that might share the bug; check whether the root cause affects other acceptance criteria; list related issues by `file:line` flagged as "same pattern" or "similar but not identical". **Do NOT open those as separate work here** — document them and tell the user to run `/ck-code:fix` on those separately.

### 4.5 Record Bug Details into Story Files

Immediately after diagnosis, append the Bug Report section to **every story file in scope** (single story for verdict A; all stories in the confirmed set for B / D). Use the same `Bug ID` (`BUG-YYYYMMDD-NN`) across all of them. The story's pre-bug status becomes `prior_status` at the Phase 6.1 flip; the Bug Report may note it in prose for human readability, but the frontmatter `prior_status` is authoritative. Bug Report status: `DIAGNOSED`. Templates: `references/bug-section-template.md` (Phase 4.5 single-story / Phase 4.5b multi-story). This creates a permanent record of the bug and its diagnosis before any fix begins.

### 4.6 Present Diagnosis to User

Present the diagnosis report from `references/qa-dialogue.md` (Phase 4.6) and confirm via `AskUserQuestion` (`Confirm & continue` / `Investigate more`). On `Investigate more`: ask which aspect to investigate, run more analysis, re-present.

## PHASE 5: FIX PLAN (the build contract)

**Goal:** Write a concrete, build-consumable Fix Plan into the story. `fix` plans; `build` implements.

### 5.1 Design the Minimal Fix

The plan must describe the **smallest possible change** that resolves the root cause — no refactoring, no features, no "improvements" to unrelated code. Produce a Fix Plan stating: **Strategy** (what to change and why it fixes the root cause), **Files to modify** (exact paths, minimal), **Test target** (the Phase 4.2 reproduction test that must go GREEN), **Risk** (`LOW` / `MEDIUM` / `HIGH`), and any **SOLID note** (if the minimal fix must bend a principle, name the smallest abstraction that avoids it — `build` verifies SOLID against the diff).

This plan is the contract `build` (Bug-Fix Mode) executes verbatim. Vague plans force `build` to re-diagnose — be specific enough that another skill can implement it without guessing.

### 5.2 Record the Fix Plan in Story Files

Append the Fix Plan subsection to the Bug Report section created in Phase 4.5 — in **every** story file in scope. Bug Report status stays `DIAGNOSED` (fix does not apply the fix). Template: `references/bug-section-template.md` (Phase 5.2).

### 5.3 Confirm Fix Plan

Present the proposed-fix prompt in `references/qa-dialogue.md` (Phase 5.3) and confirm via `AskUserQuestion` (`Record & route` / `Adjust` / `Abort`).

## PHASE 6: FLIP TO BUG & ROUTE

**Goal:** Flip the story frontmatter to `bug`, regenerate the views, then route the fix — auto-build when easy, hand off when complex.

### 6.1 Flip status to bug (frontmatter + regenerate)

For **every existing story in scope** (verdict A: one; B / D: all matched existing stories — never the `todo` stories created in Phase 2.6):

1. Edit the story-file **frontmatter**: set `status: bug` and `prior_status: <the status before this bug>` (`done` or `in-progress`). This is the single source of truth for the flip — do NOT hand-edit `STORIES_INDEX.md`, `FEATURE_INDEX.md`, or any epic file.
2. Regenerate the views once, in this phase:

   ```bash
   ck-index tasks/<slug>
   ck-project sync tasks/<slug>
   ```

   The generator rolls both indexes forward from the frontmatter — a `bug` story counts as not-done, so its feature rolls to `IN PROGRESS` automatically (see [`data-model.md`](../../references/data-model.md)). The views cannot disagree with the frontmatter because they are a pure function of it. The board is one more such view: the sync moves the card to Blocked unless it is sticky in the In Review column, and a board failure is reported without blocking the triage ([`github-projects.md`](../../references/github-projects.md)).

### 6.2 Auto-Build Eligibility Gate

Decide AUTO-BUILD vs MANUAL hand-off. **AUTO-BUILD only when ALL hold:**

- [ ] Verdict **A** (exactly one existing story in scope).
- [ ] **Single confirmed root cause** — no leftover competing hypothesis from 4.1.5.
- [ ] Fix Plan **Files to modify ≤ 3** (small blast radius).
- [ ] Fix Plan **Risk = LOW**.
- [ ] No new story (Phase 2.6) and no `design` were needed.

If **any** box is unchecked, it is a **MANUAL hand-off** (complex). Multi-story (B / D), high-risk, large-diff, or uncertain-cause fixes always stop for a manual build.

### 6.3 Route

- **AUTO-BUILD** → announce with the Phase 6 auto-build prompt in `references/qa-dialogue.md`, then invoke `/ck-code:build <story-path>` via the Skill tool. `build` detects the `bug` status, enters **Bug-Fix Mode**, takes the reproduction test RED → GREEN per the Fix Plan, runs SOLID + QA + manual-test, ships, and restores the story's `prior_status`. `fix` ends here.
- **MANUAL hand-off** → print the manual-build prompt in `references/qa-dialogue.md` (Phase 6 manual). Recommend `/ck-code:build <primary-story>` (highest-scored story), or `/ck-code:build <ids>` (PARALLEL MODE) for a multi-story bug. **STOP** — everything is recorded; the user runs `build` when ready. Do NOT implement the fix inside `fix`.

## HARD GATES (cross-phase contract)

Each gate is enforced inside its phase; this is the checklist.

- [Version gate](../../references/version-gate.md) — inlined in Phase 0. BLOCK halts the skill.
- **Phase 2.5** — scope analysis mandatory, even with an explicit story path.
- **Phase 4.1.5** — the hypothesis fan-out decision is announced before tracing any suspect path ([subagent-fanout.md](../../references/subagent-fanout.md)); investigators are read-only, `model: haiku`.
- **Phase 2.5.1** — score `todo` rows too; a `todo` match triggers verdict E.
- **Phase 2.5.2 / 2.5.5 / 4.6 / 5.3** — `AskUserQuestion` confirmation gates; never write without an explicit confirm.
- **Phase 2.6** — missing stories are created by `/ck-code:plan --quick`, never inline.
- **Phase 4.2** — a failing reproduction test is mandatory before Phase 5; it is the RED target `build` inherits.
- **Phase 6.1** — flip is a frontmatter edit (`status: bug` + `prior_status`) followed by `ck-index` in the same phase; never hand-edit a generated view.
- **Phase 6.2 / 6.3** — the Auto-Build Eligibility Gate is deterministic; a single unchecked box forces MANUAL hand-off.

### Scope discipline (cross-cutting)

- **`fix` never writes the source fix** — it diagnoses, writes the failing test + Fix Plan, and hands implementation to `build` (Bug-Fix Mode). It writes test files, story bodies, and story frontmatter only — never a generated index cell.
- **Never diagnose a bug from another story inline** — document it in the Phase 4.4 related-issues note for a separate `/ck-code:fix` run.
- **Never create stories inline** — verdict D missing functionality goes through `/ck-code:plan --quick` (existing epic); verdict C (no epic) goes through `/ck-code:design`.
- **Verdict E (PLANNED-IN-FUTURE)** → defer to `/ck-code:build <future-story>`; `PROCEED ANYWAY` bypasses no other gate.

### Universal

- **Never reference AI, Claude, or generated-by notes** in any git or GitHub artefact — [full rule](../../references/no-ai-references.md).
- **Always use the same `Bug ID`** (`BUG-YYYYMMDD-NN`) across every in-scope story.
- **Always record `prior_status`** in the story frontmatter so `build` can restore it.
- **Always relay `ck-index: WARN` lines** printed by `ck-index` — a skipped story is invisible in every generated view while its file still exists ([stories-index.md](../../references/stories-index.md)).
- **Always regenerate the views** with `ck-index` and sync the board with `ck-project sync`, in the same phase you change any frontmatter ([`github-projects.md`](../../references/github-projects.md)).
- **Always output in English.**

---

## NEXT

- **Easy fix** → `fix` already invoked `/ck-code:build <story>`; follow `build` through to `/ck-code:ship`.
- **Complex fix** → run `/ck-code:build <primary-story>` (or `/ck-code:build <ids>` for several at once) when ready; `build` enters Bug-Fix Mode, implements the recorded Fix Plan, and restores the story's `prior_status`.

To drive an auto-build regression loop autonomously, the user can set `/goal "the new regression test passes and the full suite stays green"` (cheap verifier model). See [native-commands.md](../../references/native-commands.md).
