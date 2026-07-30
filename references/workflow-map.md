# ck-code Workflow Map — Single Source of Truth

The full lifecycle, from spec to ship. Skills cross-reference this file instead of
duplicating the workflow graph.

## Workflow order

```
0. /ck-code:guide        Active entry-point — no arg: state → next step; free-text: intent → skill; --command: syntax

1. /ck-code:spec         (Optional) Stakeholder-friendly feature spec
2. /ck-code:design       Spec → architecture docs (docs/architecture/); also sync/optimize maintenance
3. /ck-code:team         Architecture → expert + guide skills (.claude/skills/); also captures house conventions
4. /ck-code:plan         Architecture → epics, stories, roadmap (tasks/); --quick adds one story
5. /ck-code:ship --to-issues   (Optional) Push tasks/ → GitHub Issues
6. /ck-code:track        Show progress / find next ready story

7. /ck-code:build        TDD-implement stories (story → done): one inline, several at once in
                        worktrees (story IDs), or a whole epic in waves (--epic NN); also a
                        bug story's recorded fix (Bug-Fix Mode)
   /ck-code:fix          Diagnose a bug, record it to its story (→ bug), route the fix

8. /ck-code:ship         Commit, open PR, update GitHub Issues

   /ck-code:migrate      (One-shot) Upgrade a pre-v5 or ck-code-lite project to the v5 layout
   /ck-code:explain      (Anytime) Explain what was just built + verify steps
doctor       (Anytime) Report what is broken in the project + how to fix it
```

## Hand-offs

| After running … | Recommended next step |
|---|---|
| `spec` | `/ck-code:design` |
| `design` | `/ck-code:team` |
| `team` | `/ck-code:plan` |
| `plan` | `/ck-code:ship --to-issues` *(optional)* or `/ck-code:track next` |
| `track next` | `/ck-code:build [path]` |
| `build` | `/ck-code:ship` (once per story, or per merged branch after PARALLEL MODE) |
| `fix` (easy) | auto-runs `/ck-code:build` → `/ck-code:ship` |
| `fix` (complex) | `/ck-code:build <story>` or `/ck-code:build <ids>` (Bug-Fix Mode) |
| `ship` | `/ck-code:track next` (more stories) or `/ck-code:explain` |

## When to use which

| Choice | Use this | Not this |
|---|---|---|
| Single story, sequential, deepest-quality TDD | `build <story-path>` | `build <ids>` |
| Multiple unrelated stories, independent files | `build <ids>` (PARALLEL MODE) | one `build` per story |
| Every story of an epic, dependencies and all | `build --epic NN` (waves) | `build <ids>` |
| Bug in already-implemented code | `fix` | `build` |
| Push the plan to GitHub for tracking | `ship --to-issues` | `ship` (default) |
| Deliver code (commit + PR + close issues) | `ship` | `ship --to-issues` |

`ship --to-issues` (mirror the *plan* to GitHub Issues) and `ship` (mirror the
*implementation*: commit, PR, issue close) are **sequential, not alternatives**. Most
projects run both.

## Misuse redirects — "am I the right skill?"

Single source of truth for the `## ROUTING CHECK` block every action skill runs first.
If an invoked skill matches a row's *actual task*, it STOPs and recommends the skill in
the last column instead.

| Invoked | …but the task is actually | Use instead |
|---|---|---|
| `spec` | a spec already exists / ready for technical design | `design` |
| `spec` | one tiny tweak to an existing plan | `plan --quick` |
| `design` | no stakeholder spec yet and you want one | `spec` (first) |
| `design` | breaking work into epics/stories | `plan` (design runs *before* plan) |
| `team` | no `docs/architecture/` exists yet | `design` (first) |
| `plan` | one small addition to an existing plan | `plan --quick` |
| `plan` | no architecture docs yet | `design` (first) |
| `plan` | stakeholder-facing spec, not a task breakdown | `spec` |
| `build` | an **un-triaged** bug in already-implemented code | `fix` (first — a `bug`-status story is already triaged and stays in `build` Bug-Fix Mode) |
| `build` | no story exists for the work | `plan --quick` or `plan` |
| `fix` | new functionality / new acceptance criteria (not a bug) | `plan --quick` then `build` |
| `fix` | just committing a finished change | `ship` |
| `fix` | implementing a fix already diagnosed (story at `bug`) | `build` (Bug-Fix Mode) |
| `ship` | the story isn't implemented yet | `build` / `fix` (first) |
| `migrate` | generating *new* architecture docs from a spec | `design` |
| `design` / `plan` / `build` | the project is a ck-code-lite one (`tasks/PLAN.md`) | `migrate` (first — it converts the flat plan into epics/stories) |

When the user is simply unsure which skill to run (no work invoked yet), route them:
`/ck-code:guide "<task>"` maps a plain-language task to a skill, `/ck-code:guide` (no arg)
recommends from project state, and `/ck-code:guide --command <name>` is the static
command reference.

## Output locations

| Skill | Writes to |
|---|---|
| `spec` | `docs/specs/YYYY-MM-DD_<slug>/pre-spec.md` (+ `.metadata.json`), optional GitHub issue |
| `design` | `docs/architecture/*.md` + `features/<slug>/index.md` (frontmatter `design: pending`) |
| `team` | `.claude/skills/expert-*/SKILL.md`, `.claude/skills/guide-*/SKILL.md` (incl. `guide-conventions/`) |
| `plan` | `tasks/YYYY-MM-DD_<slug>/` (PROJECT_OVERVIEW, epics/ with EPIC.md, stories/ with frontmatter, ROADMAP.md); flips feature doc to `design: planned`; regenerates the index views |
| `build` | Source + tests in repo; the story file only (frontmatter `status`, plan, summary; Bug Report Resolution in Bug-Fix Mode); regenerates the index views. In PARALLEL MODE: per-story branches in native worktrees with the same story-file outputs, and the orchestrator regenerates the views once on the target branch after merges |
| `fix` | Failing reproduction test, story file (Bug Report + Fix Plan, frontmatter `status: bug` + `prior_status`); regenerates the views. Auto-invokes `build` for an easy fix; never writes the source fix itself |
| `ship` | Git commit, PR, GitHub Issue updates; writes the created issue number back to story frontmatter `issue:` (`--to-issues` mode); no local writes outside git + frontmatter |
| `migrate` | Converts a pre-v5 project in place (one commit) — including flattening nested `experts/` + `guides/` skill folders; or converts a ck-code-lite project (`tasks/PLAN.md` → epics/stories, `docs/ARCHITECTURE.md` → `docs/architecture/`, lite artifacts marked superseded); stamps `tasks/VERSION.md`; regenerates the views |
| `track`, `explain`, `guide`, `doctor` | Read-only |

## State conventions (v5)

- **Story status** lives ONLY in the story-file frontmatter `status:`
  (`todo → in-progress → done`, lowercase). Every index is a generated view of it —
  see [`data-model.md`](data-model.md).
- **Bug flow:** `done → bug` (set by `fix` when it diagnoses a bug on a shipped story,
  recording the previous status in frontmatter `prior_status:`) `→ done` (restored by
  `build` Bug-Fix Mode when the recorded fix lands). A `bug` story is actionable work —
  `track` and `build` surface it.
- **Bug Report sub-status** (`DIAGNOSED` → `FIXED`) lives in the story body only; it is
  narrative and does not affect the frontmatter `status:`.
- **Indexes are generated, never hand-edited.** To change status, edit the frontmatter
  and run `scripts/ck-index.sh`. There is no reconciler — the views cannot drift.
