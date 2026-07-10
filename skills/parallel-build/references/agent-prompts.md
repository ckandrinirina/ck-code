# Sub-Agent Dispatch Prompt Templates

Prompt templates for every dispatched sub-agent: Phase 3.3 build, Phase 5 QA,
Phase 6 post-merge QA, Phase 6.5.3 bug-fix, and Phase 6 Option 3 continue.

## How the Working Directory Is Conveyed (read once, applies to every template)

**No template below passes an `isolation` or `cwd` parameter** — the Agent tool offers
neither a usable worktree target nor a working directory (`pipeline.md` → *The Agent-Tool
Contract*). Omitting `isolation` lands the agent **in the main checkout**.

So a worktree agent is placed by **prompt text alone**, using the same three-part pattern:

1. An **absolute** worktree path, stated in the prompt.
2. A mandatory first Bash call `cd "<abs path>"` — the Bash tool keeps that directory for
   every later call in the agent.
3. A **STEP 0 guard**: `git rev-parse --show-toplevel` must equal that path, else STOP and
   report `WRONG WORKTREE`. Without the guard, a mis-placed agent finds nothing to do,
   exits clean, and reports success — the one failure mode that silently corrupts a run.

Agents that are *meant* to run in the main checkout (Phase 6 post-merge QA, Phase 6.5.3
bug-fix) omit `isolation` deliberately and guard on the **branch** instead of the path.

## Per-Story Agent Call

Dispatched in Phase 3.3, into the worktree the orchestrator already created in Phase 3.0c.

```
subagent_type: ck-code:story-implementer  # falls back to general-purpose if not registered
model: [determined in 3.1 by reasoning complexity — balanced/Sonnet default, advanced/Opus only when the story needs deep reasoning]
description: "Implement story XX-YY: [story title]"
# NO isolation parameter — the worktree already exists; the prompt places the agent in it.
prompt: |
  You are implementing story XX-YY inside a worktree that ALREADY EXISTS.

  Worktree: <absolute worktree path, e.g. /repo/.claude/worktrees/agent-04-01>
  Story file (INSIDE the worktree): <worktree path>/<relative story path>
  Branch:   <already checked out in that worktree — never create or switch branches>

  STEP 0 — PROVE YOU ARE IN THE RIGHT PLACE (mandatory, before anything else):
  - Your FIRST Bash call must be exactly:  cd "<absolute worktree path>"
  - Then run `git rev-parse --show-toplevel` and confirm it equals the Worktree path.
    If it does NOT match, STOP and report "WRONG WORKTREE" — do not proceed.
  - Read the story file from the IN-WORKTREE path above — NEVER the main checkout copy.
    If it is missing there, STOP and report "STORY FILE NOT IN WORKTREE" — never invent it.
  - The branch is already checked out at the correct base. Never run `git checkout -b`,
    `git rebase`, or `git reset` — the orchestrator asserts your base on return.

  Your task:
  1. Invoke the /ck-code:build skill using the Skill tool:
     Skill({ skill: "ck-code:build", args: "<in-worktree story path>" })
  2. Follow the /ck-code:build skill completely — it handles TDD, SOLID principles, QA, and commit.
     **Commit after every TDD cycle / phase** — if you run out of budget mid-story, the
     committed state is the only thing the orchestrator can resume from. Never leave the
     whole story uncommitted.

  Important:
  - Work only on files relevant to this story, inside this worktree
  - /ck-code:build updates this story's own file `Status:` — let it. But it MUST NOT
    edit the shared indexes (`STORIES_INDEX.md`, `FEATURE_INDEX.md`) or the parent
    `EPIC.md` inside this worktree: concurrent edits to those collide at merge. Build
    auto-detects the worktree and defers them; the orchestrator reconciles all three on
    the target branch after merge. If you see build about to edit them, skip that edit.
  - Do NOT run build's Phase 1.4 Parallel-Build Opportunity Check — you are already
    inside a parallel run and cannot prompt the user. Proceed straight to Phase 1.5.
  - **Stop after Phase 8.4 (Mark All Tasks Completed) — DO NOT run Phase 8.5
    (User Manual Testing).** Sub-agents cannot interact with the user, and the
    software is not runnable from a worktree: the orchestrator manual-tests on
    the target branch *after* your work is merged (its Phase 6.5). Leave the
    story file exactly as Phase 8.4 leaves it and report back.
  - If /ck-code:build fails or encounters a blocker, report the error clearly in your final response

  END YOUR REPLY WITH THIS EXACT BLOCK (the orchestrator parses it; a missing block is
  treated as PARTIAL / incomplete):
    STATUS: SUCCESS | PARTIAL | BLOCKED
    COMMITS: <number of commits you made>
    REMAINING: <unfinished acceptance criteria, or "none">
  Report SUCCESS only if build reached Phase 8.4 with every criterion checked and QA green.
```

## Launch Announcement Template

Print as agents are dispatched — **informational, not a blocking gate**. The decision to
go parallel already happened (build's Phase 1.2 selection, parallel-build's own Phase 2
selection, or an explicit `$ARGUMENTS` ID list); do NOT add a second "press enter to
start" confirmation. Show **Complexity → Tier (resolved model)** so the operator can
catch a mis-resolution mid-run, and dispatch immediately in the same turn. Replace `<…>`
placeholders with the concrete model ID the tier resolved to at runtime.

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
Agent results (provisional — verified objectively in Phase 3.5):
  02-05  →  ✓ STATUS: SUCCESS   (COMMITS: 6,  REMAINING: none)
  02-06  →  ✗ STATUS: BLOCKED   [brief error]
  03-01  →  ◐ STATUS: PARTIAL   (COMMITS: 3,  REMAINING: "rate limiting", "audit log")
  03-04  →  ◐ no status block returned (bare stop) → treat as PARTIAL / incomplete
```

The trailing `STATUS:` block is a **hint**, not the outcome of record — Phase 3.5's
✓ COMPLETE gate (criteria + clean tree + QA) decides. A missing block, or `SUCCESS` that
fails the gate, is treated as ◐ incomplete: recovered via the Phase 6 **Continue in place**
auto-continue loop (prompt below), never by reattaching to the agent (no `SendMessage`) and
never by fresh re-dispatch into a new worktree (that discards the partial work).

## Phase 5 — QA-Validation Sub-Agent Prompt

Dispatch ONE per merge-candidate story, **all in a single parallel message** (Phase 5.2).
Pinned to the `fast` (Haiku) tier — the agent absorbs the verbose build/test/lint output in
its own cheap context and returns only a compact verdict, keeping the orchestrator lean.

```
subagent_type: ck-code:qa-validator   # falls back to inline 5.1 commands if not registered
model: fast (Haiku)                    # qa-validator pins model: haiku; this is the explicit default
description: "QA story XX-YY: [story title]"
# NO isolation parameter — the prompt places the agent in the story's existing worktree.
prompt: |
  You are running QA for story XX-YY inside its EXISTING worktree. Read-only against the
  project — run the stack commands below, never edit code or any file.

  Worktree:   <absolute worktree path for this story>
  Story file (INSIDE the worktree): <worktree path>/<relative story path>

  STEP 0 — PROVE YOU ARE IN THE RIGHT PLACE (mandatory):
  - Your FIRST Bash call must be exactly:  cd "<absolute worktree path>"
  - Then confirm `git rev-parse --show-toplevel` equals that path; if not, STOP and report
    "WRONG WORKTREE". Running the suite in the main checkout would green-light code this
    story never wrote — the verdict must come from the story's own tree.
  - Read the story file from the in-worktree path.

  Stack QA commands (run exactly, in order, from the worktree):
    <concrete commands for this story's epic — from SKILL.md Phase 5.1>

  Your task:
  1. Run each stack QA command above. Capture the first failing command and a short excerpt
     of its output (the failing test names / clippy or lint errors / type errors).
  2. Map results to the story's acceptance criteria where the suite covers them.
  3. Do NOT attempt fixes — only report.

  END YOUR REPLY WITH THIS EXACT VERDICT LINE (the orchestrator parses it):
    QA: PASS
  or, on any failure:
    QA: FAIL — <which command failed> — <one-line excerpt>
  Report PASS only if every stack command succeeded.
```

## Phase 6 — Post-Merge QA Sub-Agent Prompt

Dispatch ONE after the Option-1 merge and index reconciliation, before the Phase 6.5 gate.
It runs on the **merged target in the main checkout**, not in a worktree — the point is to
catch integration failures that only appear once the branches sit together. Same Haiku tier
and same reason as Phase 5: a merge does not make test output cheap.

```
subagent_type: ck-code:qa-validator   # falls back to inline 5.1 commands if not registered
model: fast (Haiku)
description: "Post-merge QA on <$TARGET> (N merged stories)"
# NO isolation parameter — omitting it runs the agent in the main checkout, which is
# exactly where this one belongs: the merged target is the thing under test.
prompt: |
  You are running post-merge QA on branch <$TARGET> in the main checkout, which now
  contains the merged code for stories: <XX-YY, XX-ZZ, …>. Read-only — never edit any file.

  STEP 0 — confirm `git rev-parse --abbrev-ref HEAD` equals <$TARGET>; if not, STOP and
  report "WRONG BRANCH". Do not cd into any worktree — a worktree holds one story in
  isolation, and integration failures only appear once the branches sit together.

  Stack QA commands (the de-duplicated union of the merged stories' Phase 5.1 commands —
  run exactly, in order, from the repo root):
    <concrete commands>

  Your task:
  1. Run each command. Capture the first failing command and a short excerpt of its output.
  2. Do NOT attempt fixes — only report.

  END YOUR REPLY WITH THIS EXACT VERDICT LINE (the orchestrator parses it):
    QA: PASS
  or, on any failure:
    QA: FAIL — <which command failed> — <one-line excerpt>
  Report PASS only if every command succeeded.
```

A `QA: FAIL` here is an **integration** failure by construction: each branch passed its own
Phase 5 in isolation. Keep every worktree, do not run Phase 7.

## Phase 6.5.3 — Bug-Fix Sub-Agent Prompt

Used when a Phase 6.5 **post-merge** manual test reports `ISSUES`. The story is already
merged, so its worktree branch is no longer the source of truth: dispatch ONE Agent into
the **main checkout on the target branch**, where the fix lands as a new commit.

```
subagent_type: general-purpose
model: [tier resolved by reasoning complexity — see SKILL.md 3.1; a bug-fix typically matches the story's original tier]
description: "Fix post-merge manual-test bug for story XX-YY: [bug summary]"
# NO isolation parameter — omitting it runs the agent in the main checkout on $TARGET,
# which is where the fix must land: the story is already merged.
prompt: |
  You are running in the main checkout on branch <$TARGET>, which already contains the
  merged code for story XX-YY.

  STEP 0 — confirm `git rev-parse --abbrev-ref HEAD` equals <$TARGET>; if not, STOP and
  report "WRONG BRANCH". Never check out or commit onto a `story/…` branch.

  Story file: <repo-root-relative story path>
  Reported bug: <verbatim bug description from user>
  Repro:    <steps>
  Expected: <expected>
  Actual:   <actual>

  Your task:
  1. Invoke the /ck-code:build skill via the Skill tool:
     Skill({ skill: "ck-code:build", args: "<story path>" })
  2. The build skill re-enters at Phase 8.5.3 (Bug-Fix Sub-Loop) because the
     story carries the manual-test bug above to address. It will:
       - write a failing regression test (TDD red)
       - apply the minimum fix (TDD green)
       - re-run Phase 6 (Refactor) and Phase 7 (QA) — both MANDATORY
       - update the `## Manual-Test Bugs` section: status OPEN → FIXED
       - commit on <$TARGET>
  3. Stop after the bug entry is FIXED and Phase 7 QA reports PASS.
     DO NOT run Phase 8.5.1 (manual-test prompt) — the parallel-build
     orchestrator will re-prompt the user once you return.

  Constraints:
  - The story stays DONE in the indexes — this is a post-merge fix, not a re-open.
  - Modify only files relevant to this fix and to the story.
  - Commit the fix on <$TARGET> before returning.

  END YOUR REPLY WITH THIS EXACT BLOCK:
    STATUS: SUCCESS | PARTIAL | BLOCKED
    COMMITS: <number of commits you made>
    REMAINING: <anything still open, or "none">
  SUCCESS only if the bug entry is FIXED and Phase 7 QA passed.
```

## Phase 6 Option 3 — Continue-Incomplete Sub-Agent Prompt

Used when a story came back ◐ **incomplete** (agent stopped early, partial work left in its
worktree). Dispatch ONE fresh agent INTO that existing worktree — do NOT create a new
worktree, and do NOT try to resume the original agent (impossible: no `SendMessage`).

```
subagent_type: ck-code:story-implementer  # falls back to general-purpose
model: [tier resolved by reasoning complexity — see SKILL.md 3.1; usually the story's original tier]
description: "Continue incomplete story XX-YY: [story title]"
# NO isolation parameter — reuse the EXISTING worktree (its partial progress is the
# carry-over). A fresh `isolation: worktree` would silently discard that work.
prompt: |
  You are resuming story XX-YY inside its EXISTING worktree. A previous agent ran out of
  budget and stopped before finishing — its partial work is already here (committed and/or
  in the working tree). You are NOT starting over.

  Worktree: <absolute worktree path for this story>
  Story file (INSIDE the worktree): <worktree path>/<relative story path>
  Branch:   <already checked out in that worktree — never create or switch branches>

  STEP 0 — PROVE YOU ARE IN THE RIGHT PLACE (mandatory, before anything else):
  - Your FIRST Bash call must be exactly:  cd "<absolute worktree path>"
  - Then run `git rev-parse --show-toplevel` and confirm it equals the Worktree path above.
    If it does NOT match, STOP and report "WRONG WORKTREE" — do not proceed. (This is the
    guard against the silent no-op: an agent in the wrong dir sees nothing to do and exits.)
  - Read the story file from the IN-WORKTREE path above — NEVER the main checkout copy.
    If that file is missing here, STOP and report "STORY FILE NOT IN WORKTREE" — do not
    invent or proceed.

  Your task:
  1. Inspect current progress — `git log --oneline`, `git status`, and the story file's
     acceptance-criteria checkboxes — to see what is already done.
  2. Invoke /ck-code:build via the Skill tool to finish the REMAINING work only:
     Skill({ skill: "ck-code:build", args: "<in-worktree story path>" })
     Build re-enters on the IN PROGRESS story and continues from where it left off — do
     NOT redo completed criteria or rewrite passing code.
  3. Follow build through Phase 8.4 (TDD, SOLID, QA). **Commit after every TDD cycle / phase**
     so any further early stop still preserves progress — never leave work uncommitted.

  Important:
  - Do NOT run build's Phase 1.4 Parallel-Build Opportunity Check — proceed to Phase 1.5.
  - Stop after Phase 8.4 — DO NOT run Phase 8.5 (manual testing); the orchestrator owns it.
  - Modify only files relevant to this story. Build updates this story's own file
    `Status:`, but must NOT edit the shared `STORIES_INDEX.md` / `FEATURE_INDEX.md` /
    `EPIC.md` in this worktree — the orchestrator reconciles those post-merge.

  END YOUR REPLY WITH THIS EXACT BLOCK (the orchestrator parses it; a missing block is
  treated as PARTIAL):
    STATUS: SUCCESS | PARTIAL | BLOCKED
    COMMITS: <number of NEW commits you made this round>
    REMAINING: <unfinished acceptance criteria, or "none">
  Report SUCCESS only if every acceptance criterion is checked and QA passed. If you did no
  work (nothing left, or you could not proceed), say so explicitly — do NOT report SUCCESS.
```
