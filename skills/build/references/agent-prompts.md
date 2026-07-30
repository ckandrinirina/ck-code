# Sub-Agent Dispatch, Resume & Return Schema

Prompt templates and the structured return contract for every sub-agent PARALLEL MODE
dispatches: the per-story implementer (P4), its resume (P5), and QA (P7). Read only when two
or more stories are in scope.

## The structured return schema (all implementer agents)

Each story agent returns a structured object — the orchestrator reads fields, never
greps prose:

```json
{
  "status": "success | partial | blocked",
  "branch": "<the git branch the work is committed on>",
  "commits": <number of commits made>,
  "remaining": "<unfinished acceptance criteria, or 'none'>",
  "criteria_met": true | false
}
```

`status`/`criteria_met` are **hints**. The orchestrator's P5 gate decides "done" objectively
from git (non-empty diff on `branch`, zero unchecked criteria in the story file, clean tree)
plus the P7 QA verdict. `branch` is the field the orchestrator merges — the harness names the
worktree branch, so the agent must report it.

## Per-story implementer (P4)

Dispatched with `isolation: "worktree"` (the harness creates and places the worktree —
the agent never runs `git worktree add`, `checkout -b`, `rebase`, or `reset`).

```
subagent_type: ck-code:story-implementer   # falls back to general-purpose
name: story-EE-SS                            # stable — P5 resumes it via SendMessage
model: sonnet                                # literal alias only — see the tier map below
isolation: worktree
description: "Implement story EE-SS: <title>"
prompt: |
  MODE: delegated

  You are implementing story EE-SS in an isolated worktree the harness created for you.

  Story file: <repo-relative story path from the index File column>

  Your task:
  1. Invoke /ck-code:build via the Skill tool:
     Skill({ skill: "ck-code:build", args: "<story path>" })
  2. Follow it completely — it owns TDD, SOLID, QA, and committing. Because this prompt
     begins `MODE: delegated`, build applies its DELEGATED MODE deltas: no branch question,
     no `ck-index`, no manual-test gate, no ship. **Commit after every TDD cycle /
     phase** so an early stop still leaves resumable, committed work.

  Constraints:
  - Edit only files relevant to this story, and only this story's own frontmatter. Do NOT
    edit the generated indexes (STORIES_INDEX.md, FEATURE_INDEX.md) and do NOT run
    ck-index — the orchestrator regenerates them once after merge.

  Return the structured object {status, branch, commits, remaining, criteria_met}. Read
  `branch` from `git branch --show-current`. Report success only if build finished with
  every criterion checked and QA green.
```

### Tier map — write the alias, never the tier name

The `Agent` tool's `model` parameter accepts **only** `haiku`, `fable`, `sonnet`, `opus`.
ck-code's tier names are prose for choosing among them; emitting one as the value is an
invalid call. Translate before dispatch:

| ck-code tier | `model:` value | Use for |
|---|---|---|
| fast | `${user_config.model_fast}` (default `haiku`) | trivial mechanical change, QA command runs |
| fast+ | `fable` | mechanical work needing more instruction-following than `haiku` holds |
| balanced | `${user_config.model_balanced}` (default `sonnet`) | **the default** for a story implementer |
| advanced | `${user_config.model_advanced}` (default `opus`) | novel algorithm, concurrency correctness, security/perf-critical path |

Those three placeholders are substituted into this file at load time from the plugin's
`userConfig`, so the table already shows the operator's real choice. They are configured in
`/plugin` → ck-code, not by exporting environment variables. A value that is not one of the
four aliases is invalid — report it rather than dispatching it.

## Resume an incomplete story (P5)

A ◐ incomplete story is **not** re-dispatched — resume the same agent, whose worktree and
context are intact:

```
SendMessage({
  to: "story-EE-SS",
  message: "Your last run stopped before every acceptance criterion was met (remaining:
    <list>). Continue in the same worktree — inspect git log / git status and the story's
    unchecked criteria, finish only the remaining work via /ck-code:build, commit each
    cycle, and return the updated {status, branch, commits, remaining, criteria_met}. Do
    not redo completed work.",
  summary: "resume story EE-SS"
})
```

Re-run the P5 gate after each resume; cap 2 rounds. A resume that adds zero commits is
stuck — flag it and stop, never merge it.

## QA validator (P7, per branch — and post-merge)

Dispatched one per merge-candidate branch in a single parallel message; Haiku tier. It runs
the given commands in its own context and returns only a verdict line.

```
subagent_type: ck-code:qa-validator   # falls back to inline commands if unregistered
model: haiku
description: "QA story EE-SS: <title>"
isolation: worktree                    # per-branch QA runs against that branch's worktree
prompt: |
  Run QA for story EE-SS, read-only — never edit any file. Check out / operate on branch
  <branch>. Run these stack commands exactly, in order, capturing only the first failure's
  short excerpt (failing test names / lint / type errors):
    <concrete commands from parallel-mode.md § P7>
  End with exactly one line:
    QA: PASS
  or  QA: FAIL — <which command failed> — <one-line excerpt>
  PASS only if every command succeeded.
```

**Post-merge QA (P8)** dispatches ONE qa-validator on `$TARGET` in the main checkout (no
worktree — the merged branches must sit together to surface integration failures). It guards
on `git rev-parse --abbrev-ref HEAD == $TARGET`, runs the de-duplicated union of the merged
stories' commands, and returns the same verdict line. A `QA: FAIL` there is a cross-branch
integration failure by construction — each branch already passed in isolation.
