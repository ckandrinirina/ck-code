# Sub-Agent Dispatch Prompt Templates

Use these templates when dispatching parallel sub-agents in Phase 3.3.

## Per-Story Agent Call

For each selected story, dispatch one Agent call with the following structure:

```
subagent_type: general-purpose
model: [determined in 3.1 from Size]
isolation: worktree
description: "Implement story XX-YY: [story title]"
prompt: |
  You are implementing story XX-YY.

  Story file: [full path to story markdown file]
  Branch: story/XX-YY

  Your task:
  1. Read the story file at the path above
  2. Invoke the /ck-code:build skill using the Skill tool:
     Skill({ skill: "ck-code:build", args: "[full path to story markdown file]" })
  3. Follow the /ck-code:build skill completely — it handles TDD, SOLID principles, QA, and commit

  Important:
  - Work only on files relevant to this story
  - Do not modify story files in tasks/ (the /ck-code:build skill updates those)
  - If /ck-code:build completes successfully, your job is done
  - If /ck-code:build fails or encounters a blocker, report the error clearly in your final response
```

## Launch Announcement Template

Print before dispatching. Show **Tier (resolved model)** so the operator can
catch a mis-resolution. Replace `<…>` placeholders with the concrete model ID
the tier resolved to at runtime.

```
Launching N agents in parallel:

  Story 02-05  (M)   →  balanced (<resolved-model>)                 →  branch story/02-05
  Story 02-06  (L)   →  advanced (<resolved-model>)                 →  branch story/02-06
  Story 03-01  (XL)  →  advanced-extended-context (<resolved-model>) →  branch story/03-01

Override any line? Reply with "override 02-06=<model-id>", or press enter to start.
```

## Result Collection Template

```
Agent results:
  02-05  →  ✓ completed
  02-06  →  ✗ failed: [brief error]
  03-01  →  ✓ completed
```
