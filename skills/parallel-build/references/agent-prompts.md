# Sub-Agent Dispatch Prompt Templates

Use these templates when dispatching parallel sub-agents in Phase 3.3.

## Per-Story Agent Call

For each selected story, dispatch one Agent call with the following structure:

```
subagent_type: ck-code:story-implementer  # falls back to general-purpose if not registered
model: [determined in 3.1 by reasoning complexity — balanced/Sonnet default, advanced/Opus only when the story needs deep reasoning]
isolation: worktree
description: "Implement story XX-YY: [story title]"
prompt: |
  You are implementing story XX-YY.

  Story file: [full path to story markdown file]
  Branch: story/XX-YY

  Your task:
  1. Invoke the /ck-code:build skill using the Skill tool:
     Skill({ skill: "ck-code:build", args: "[full path to story markdown file]" })
  2. Follow the /ck-code:build skill completely — it handles TDD, SOLID principles, QA, and commit

  Important:
  - Work only on files relevant to this story
  - /ck-code:build updates this story's own file `Status:` — let it. But it MUST NOT
    edit the shared indexes (`STORIES_INDEX.md`, `FEATURE_INDEX.md`) or the parent
    `EPIC.md` inside this worktree: concurrent edits to those collide at merge. Build
    auto-detects the worktree and defers them; the orchestrator reconciles all three on
    the target branch after merge. If you see build about to edit them, skip that edit.
  - Do NOT run build's Phase 1.4 Parallel-Build Opportunity Check — you are already
    inside a parallel run and cannot prompt the user. Proceed straight to Phase 1.5.
  - **Stop after Phase 8.4 (Mark All Tasks Completed) — DO NOT run Phase 8.5
    (User Manual Testing).** The parallel-build orchestrator runs the
    per-story manual-testing gate in its own Phase 5.5 — sub-agents cannot
    interact with the user. Leave the story `Status: IN PROGRESS` and report
    back; the orchestrator will flip it to `DONE` after manual-test PASS.
  - If /ck-code:build completes through Phase 8.4 successfully, your job is done
  - If /ck-code:build fails or encounters a blocker, report the error clearly in your final response
```

## Launch Announcement Template

Print as agents are dispatched — **informational, not a blocking gate**. The decision to
go parallel already happened (build's Phase 1.2 selection, parallel-build's own Phase 2
selection, or an explicit `$ARGUMENTS` ID list); do NOT add a second "press enter to
start" confirmation. Show **Complexity → Tier (resolved model)** so the operator can
catch a mis-resolution mid-run, and dispatch immediately in the same turn. Replace `<…>`
placeholders with the concrete model ID the tier resolved to at runtime. Note how two
same-Size stories can resolve differently — the driver is complexity, not Size.

```
⚡ Dispatching N agents in parallel — each runs /ck-code:build in its own worktree:

  🤖 Story 02-05  (M · routine)         →  balanced (<resolved-model>)                  →  branch story/02-05
  🤖 Story 02-06  (L · routine)         →  balanced (<resolved-model>)                  →  branch story/02-06
  🤖 Story 03-01  (L · high-reasoning)  →  advanced (<resolved-model>)                  →  branch story/03-01
  🤖 Story 03-02  (XL · high-reasoning) →  advanced-extended-context (<resolved-model>) →  branch story/03-02

Live progress on the task board below. (To pin a model, set the tier env var and re-run — see pipeline.md.)
```

## Result Collection Template

```
Agent results:
  02-05  →  ✓ completed
  02-06  →  ✗ failed: [brief error]
  03-01  →  ◐ incomplete: stopped at ~41 tool-calls, story still IN PROGRESS (partial work in worktree)
  03-04  →  ◐ incomplete: stopped at ~99 tool-calls, story still IN PROGRESS (partial work in worktree)
```

`◐ incomplete` = agent returned with no error but did not finish (typically an XL story
that exhausted its dispatch budget). It is recovered via Phase 6 **Continue in place**
(prompt below), never by reattaching to the agent (no `SendMessage`) and never by fresh
re-dispatch into a new worktree (that discards the partial work).

## Phase 5.5.3 — Bug-Fix Sub-Agent Prompt

Used when a Phase 5.5 manual-test reports `ISSUES`. Dispatch ONE Agent into
the story's existing worktree (do NOT create a new worktree — reuse the one
the original story agent left behind).

```
subagent_type: general-purpose
model: [tier resolved by reasoning complexity — see SKILL.md 3.1; a bug-fix typically matches the story's original tier]
isolation: none   # reuse the existing worktree path
cwd: <existing worktree path for this story>
description: "Fix manual-test bug for story XX-YY: [bug summary]"
prompt: |
  You are running inside the existing worktree for story XX-YY.

  Story file: [full path inside this worktree]
  Reported bug: <verbatim bug description from user>
  Repro:    <steps>
  Expected: <expected>
  Actual:   <actual>

  Your task:
  1. Invoke the /ck-code:build skill via the Skill tool:
     Skill({ skill: "ck-code:build", args: "<story path>" })
  2. The build skill re-enters at Phase 8.5.3 (Bug-Fix Sub-Loop) because the
     story is IN PROGRESS with the manual-test bug above to address. It will:
       - write a failing regression test (TDD red)
       - apply the minimum fix (TDD green)
       - re-run Phase 6 (Refactor) and Phase 7 (QA) — both MANDATORY
       - update the `## Manual-Test Bugs` section: status OPEN → FIXED
       - commit inside this worktree
  3. Stop after the bug entry is FIXED and Phase 7 QA reports PASS.
     DO NOT run Phase 8.5.1 (manual-test prompt) — the parallel-build
     orchestrator will re-prompt the user once you return.

  Constraints:
  - Story status stays IN PROGRESS — do NOT flip to DONE.
  - Modify only files relevant to this fix and to the story.
  - Report back the bug entry's fix summary and Files Touched list.
```

## Phase 6 Option 3 — Continue-Incomplete Sub-Agent Prompt

Used when a story came back ◐ **incomplete** (agent stopped early, partial work left in its
worktree). Dispatch ONE fresh agent INTO that existing worktree — do NOT create a new
worktree, and do NOT try to resume the original agent (impossible: no `SendMessage`).

```
subagent_type: ck-code:story-implementer  # falls back to general-purpose
model: [tier resolved by reasoning complexity — see SKILL.md 3.1; usually the story's original tier]
isolation: none   # reuse the existing worktree path — its partial progress is the carry-over
cwd: <existing worktree path for this story>
description: "Continue incomplete story XX-YY: [story title]"
prompt: |
  You are resuming story XX-YY inside its EXISTING worktree. A previous agent ran out of
  budget and stopped before finishing — its partial work is already here (committed and/or
  in the working tree). You are NOT starting over.

  Story file: [full path inside this worktree]
  Branch:     story/XX-YY

  Your task:
  1. First, inspect current progress — `git log --oneline`, `git status`, and the story
     file's acceptance-criteria checkboxes — to see what is already done.
  2. Invoke /ck-code:build via the Skill tool to finish the REMAINING work only:
     Skill({ skill: "ck-code:build", args: "[story path]" })
     Build re-enters on the IN PROGRESS story and continues from where it left off — do
     NOT redo completed criteria or rewrite passing code.
  3. Follow build through Phase 8.4 (TDD, SOLID, QA, commit). Commit incrementally so any
     further early stop still preserves progress.

  Important:
  - Do NOT run build's Phase 1.4 Parallel-Build Opportunity Check — proceed to Phase 1.5.
  - Stop after Phase 8.4 — DO NOT run Phase 8.5 (manual testing); the orchestrator owns it.
  - Leave Status: IN PROGRESS and report back what you finished and what (if anything)
    still remains. If you again stop before finishing, say so explicitly.
  - Modify only files relevant to this story. Build updates this story's own file
    `Status:`, but must NOT edit the shared `STORIES_INDEX.md` / `FEATURE_INDEX.md` /
    `EPIC.md` in this worktree — the orchestrator reconciles those post-merge.
```
