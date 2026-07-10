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
  2. Follow the /ck-code:build skill completely — it handles TDD, SOLID principles, QA, and commit.
     **Commit after every TDD cycle / phase** — if you run out of budget mid-story, the
     committed state is the only thing the orchestrator can resume from. Never leave the
     whole story uncommitted.

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
Agent results (provisional — verified objectively in Phase 3.5):
  02-05  →  ✓ STATUS: SUCCESS   (COMMITS: 6,  REMAINING: none)
  02-06  →  ✗ STATUS: BLOCKED   [brief error]
  03-01  →  ◐ STATUS: PARTIAL   (COMMITS: 3,  REMAINING: "rate limiting", "audit log")
  03-04  →  ◐ no status block returned (bare stop) → treat as PARTIAL / incomplete
```

The trailing `STATUS:` block is a **hint**, not the outcome of record — Phase 3.5's
✓ COMPLETE gate (criteria + clean tree + QA) decides. A missing block, or `SUCCESS` that
fails the gate, is treated as ◐ incomplete.

`◐ incomplete` = agent returned with no error but did not finish (typically an XL story
that exhausted its dispatch budget). It is recovered via Phase 6 **Continue in place**
auto-continue loop (prompt below), never by reattaching to the agent (no `SendMessage`) and
never by fresh re-dispatch into a new worktree (that discards the partial work).

## Phase 5 — QA-Validation Sub-Agent Prompt

Dispatch ONE per merge-candidate story, **all in a single parallel message** (Phase 5.2).
Pinned to the `fast` (Haiku) tier — the agent absorbs the verbose build/test/lint output in
its own cheap context and returns only a compact verdict, keeping the orchestrator lean.

```
subagent_type: ck-code:qa-validator   # falls back to inline 5.1 commands if not registered
model: fast (Haiku)                    # qa-validator pins model: haiku; this is the explicit default
isolation: none                        # run inside the story's existing worktree
cwd: <existing worktree path for this story>
description: "QA story XX-YY: [story title]"
prompt: |
  You are running QA for story XX-YY inside its EXISTING worktree. Read-only against the
  project — run the stack commands below, never edit code or any file.

  STEP 0 — confirm `git rev-parse --show-toplevel` equals the worktree path below; if not,
  STOP and report "WRONG WORKTREE". Read the story file from the in-worktree path.

  Worktree:   <existing worktree path>
  Story file (INSIDE the worktree): <worktree path>/<relative story path>
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

## Phase 6.5.3 — Bug-Fix Sub-Agent Prompt

Used when a Phase 6.5 **post-merge** manual test reports `ISSUES`. The story is already
merged, so its worktree branch is no longer the source of truth: dispatch ONE Agent into
the **main checkout on the target branch**, where the fix lands as a new commit.

```
subagent_type: general-purpose
model: [tier resolved by reasoning complexity — see SKILL.md 3.1; a bug-fix typically matches the story's original tier]
isolation: none   # main checkout — the story is already merged
cwd: <repo root>
description: "Fix post-merge manual-test bug for story XX-YY: [bug summary]"
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
isolation: none   # reuse the existing worktree path — its partial progress is the carry-over
cwd: <existing worktree path for this story>
description: "Continue incomplete story XX-YY: [story title]"
prompt: |
  You are resuming story XX-YY inside its EXISTING worktree. A previous agent ran out of
  budget and stopped before finishing — its partial work is already here (committed and/or
  in the working tree). You are NOT starting over.

  Worktree: <existing worktree path>
  Story file (INSIDE the worktree): <worktree path>/<relative story path>
  Branch:   story/XX-YY

  STEP 0 — PROVE YOU ARE IN THE RIGHT PLACE (mandatory, before anything else):
  - Run `git rev-parse --show-toplevel` and confirm it equals the Worktree path above.
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
