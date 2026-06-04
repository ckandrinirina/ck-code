# Subagent Fan-Out — shared dispatch contract

How a ck-code skill dispatches a **team of parallel subagents**, each digging into one
independent unit, then converges the results. Skills reference this file instead of
redefining the pattern. The per-story execution variant lives in
[`../skills/parallel-build/references/agent-prompts.md`](../skills/parallel-build/references/agent-prompts.md);
this doc covers the generic case (read-only investigation **and** independent-artifact writes).

## When fan-out helps (and when it hurts)

Fan out only when **all** of these hold:

- **Independent** — units do not read each other's in-progress output; order doesn't matter.
- **Numerous** — enough units that parallel wall-clock beats dispatch overhead (each skill
  sets its own threshold; below it, stay sequential).
- **Non-interactive** — the unit's work needs no user prompt (subagents cannot ask the user).

Do **not** fan out sequential chains (TDD red→green→refactor), stateful/ordered writes
(git, GitHub issue links, numbered epics), cheap reads, or any step that prompts the user.

## The two variants

| Variant                       | Subagent does                                             | `isolation`                                              | Writes?              |
| ----------------------------- | --------------------------------------------------------- | -------------------------------------------------------- | -------------------- |
| **Investigation** (read-only) | Greps/reads/traces one slice, returns a structured report | `none`                                                   | Never — reports only |
| **Artifact** (write)          | Produces ONE file in its own dedicated path               | `none` (or `worktree` only if units touch shared source) | Its own path only    |

## The orchestrator-owns-shared-writes rule (non-negotiable)

The orchestrator (the skill thread) — never a subagent — does all of:

- **User interaction** — every prompt, confirmation, and refinement runs to completion
  _before_ dispatch and _after_ collection. Subagents get already-resolved context.
- **Shared writes** — index files (`README.md`, `STORIES_INDEX.md`, `FEATURE_INDEX.md`,
  `DESIGN_LEDGER.md`), `_shared.md`, `tasks/VERSION.md`, and any append-target singleton are
  authored/merged by the orchestrator. A subagent writes only files unique to its own unit.
- **The version gate** — runs once, in the orchestrator. Subagents never re-run or re-stamp it.
- **Convergence** — merging reports, resolving contradictions to a single decision, and the
  final summary stay with the orchestrator.

So before dispatch: finish all prompts, author every shared/global file (freeze `_shared.md`),
then pass each subagent its slice as **read-only** context.

## Dispatch shape

1. **Gate** — check the skill's threshold (unit count, input size, mode). Below it → inline, no fan-out.
2. **Freeze shared state** — author globals/`_shared.md`/indexes; finish user prompts.
3. **Dispatch** — one `Agent` call per unit, in a single message so they run concurrently.
   Use `subagent_type: general-purpose` unless a registered ck-code agent fits the unit.
   Give each: its unit id, its slice of frozen context, its template reference, and an
   explicit "write only `<your path>`; do not prompt; do not touch shared files" constraint.
4. **Collect** — gather every subagent's result; a failed/empty agent is recovered or
   redone inline by the orchestrator, never left silently missing.
5. **Converge** — merge into shared files, resolve conflicts, verify each unit landed, summarize.

## Announce + report

Print a one-line-per-unit launch announcement (informational, not a second gate — the
decision already happened at the skill's own confirmation step) and a result roster on
collection, mirroring
[`parallel-build/references/agent-prompts.md`](../skills/parallel-build/references/agent-prompts.md).
If fan-out was skipped because the input was below threshold, say so — never silently
imply the whole set was parallelized.
