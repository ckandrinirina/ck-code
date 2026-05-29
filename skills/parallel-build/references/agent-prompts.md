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
  - Do not modify story files in tasks/ (the /ck-code:build skill updates those)
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
  03-01  →  ✓ completed
```

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
