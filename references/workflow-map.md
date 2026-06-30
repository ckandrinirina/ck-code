# ck-code Workflow Map — Single Source of Truth

The full lifecycle, from spec to ship. Skills cross-reference this file
instead of duplicating the workflow graph.

## Workflow order

```
0. /ck-code:start        Active entry-point — inspects state, recommends next step

1. /ck-code:pre-spec     (Optional) Stakeholder-friendly feature spec
2. /ck-code:design       Spec → architecture docs (docs/architecture/)
3. /ck-code:team         Architecture → expert + guide skills (.claude/skills/)
4. /ck-code:plan         Architecture → epics, stories, roadmap (tasks/)
5. /ck-code:to-issues      (Optional) Push tasks/ → GitHub Issues
6. /ck-code:track        Show progress / find next ready story

7. /ck-code:build        TDD-implement one story (story → DONE)
   /ck-code:parallel-build  TDD-implement multiple stories in worktrees
   /ck-code:fix          Diagnose + minimally fix a bug tied to a story

8. /ck-code:ship         Commit, open PR, update GitHub Issues

   /ck-code:explain      (Anytime) Explain what was just built + verify steps
   /ck-code:help         (Anytime) Static reference for commands and flow
```

## Hand-offs

| After running … | Recommended next step |
|---|---|
| `pre-spec` | `/ck-code:design` |
| `design` | `/ck-code:team` |
| `team` | `/ck-code:plan` |
| `plan` | `/ck-code:to-issues` *(optional)* or `/ck-code:track next` |
| `to-issues` | `/ck-code:track next` |
| `track next` | `/ck-code:build [path]` |
| `build` | `/ck-code:ship` |
| `parallel-build` | `/ck-code:ship` (per branch) |
| `fix` | `/ck-code:ship` |
| `ship` | `/ck-code:track next` (more stories) or `/ck-code:explain` |

## When to use which

| Choice | Use this | Not this |
|---|---|---|
| Single story, sequential, deepest-quality TDD | `build` | `parallel-build` |
| Multiple unrelated stories, independent files | `parallel-build` | `build` |
| Bug in already-implemented code | `fix` | `build` |
| Push tasks to GitHub for tracking | `to-issues` (creates issues) | `ship` |
| Deliver code (commit + PR + close issues) | `ship` (artefact: code) | `to-issues` |

`to-issues` and `ship` are **sequential, not alternatives**: `to-issues`
mirrors the *plan* to GitHub Issues so anyone can see what's coming;
`ship` mirrors the *implementation* (commit, PR, issue close) once a
story is done. Most projects run both.

## Misuse redirects — "am I the right skill?"

Single source of truth for the `## ROUTING CHECK` block every action skill
runs first. If an invoked skill matches a row's *actual task*, it STOPs and
recommends the skill in the last column instead.

| Invoked | …but the task is actually | Use instead |
|---|---|---|
| `pre-spec` | a spec already exists / ready for technical design | `design` |
| `pre-spec` | one tiny tweak to an existing plan | `quick-story` |
| `design` | no stakeholder spec yet and you want one | `pre-spec` (first) |
| `design` | breaking work into epics/stories | `plan` (design runs *before* plan) |
| `design` | existing architecture docs are bloated / stale layout | `doc-optimizer` |
| `team` | no `docs/architecture/` exists yet | `design` (first) |
| `team` | capturing *house* conventions team can't research | `convention` |
| `plan` | one small addition to an existing plan | `quick-story` |
| `plan` | no architecture docs yet | `design` (first) |
| `plan` | stakeholder-facing spec, not a task breakdown | `pre-spec` |
| `to-issues` | committing/PR-ing implemented code | `ship` (sequential, not either/or) |
| `to-issues` | no `tasks/` plan exists yet | `plan` (first) |
| `build` | a bug in already-implemented code | `fix` |
| `build` | 3+ independent ready stories, no `Blocked by` | `parallel-build` |
| `build` | no story exists for the work | `quick-story` or `plan` |
| `parallel-build` | one story, or stories with `Blocked by` deps | `build` |
| `parallel-build` | a bug in implemented code | `fix` |
| `fix` | new functionality / new acceptance criteria (not a bug) | `build` (add story via `quick-story`) |
| `fix` | just committing a finished change | `ship` |
| `quick-story` | a bug in implemented code | `fix` |
| `quick-story` | a full feature spanning multiple epics/components | `plan` |
| `quick-story` | the story already exists and you want to code it | `build` |
| `ship` | the story isn't implemented yet | `build` / `fix` (first) |
| `ship` | mirroring the *plan* (not code) to GitHub | `to-issues` |
| `sync` | adding a new story | `quick-story` |
| `sync` | just viewing progress | `track` |
| `convention` | no expert/guide skills generated yet | `team` (first) |
| `doc-optimizer` | generating *new* architecture docs from a spec | `design` |

When the user is simply unsure which skill to run (no work invoked yet),
point them to `/ck-code:start` (state-aware) or `/ck-code:help` (static),
never a redirect.

## Output locations

| Skill | Writes to |
|---|---|
| `pre-spec` | `docs/specs/YYYY-MM-DD_<slug>/pre-spec.md` (+ `.metadata.json`), optional GitHub issue |
| `design` | `docs/architecture/*.md` |
| `team` | `.claude/skills/experts/*/SKILL.md`, `.claude/skills/guides/*/SKILL.md` |
| `plan` | `tasks/YYYY-MM-DD_<slug>/` (PROJECT_OVERVIEW, epics/, stories/, STORIES_INDEX.md, ROADMAP.md) |
| `to-issues` | GitHub Issues only (no local writes) |
| `build` | Source + tests in repo, story file (status, plan, summary), `STORIES_INDEX.md` (status cell) |
| `parallel-build` | Per-story branches in `.claude/worktrees/agent-*`, each with the same outputs as `build` |
| `fix` | Source + tests, story file (Bug Report section), regression test |
| `ship` | Git commit, PR, GitHub Issue updates (no local-file writes outside git) |
| `track`, `explain`, `help`, `start` | Read-only |

## State conventions

- **Story status flow:** `TODO → IN PROGRESS → DONE` (set by `build`).
- **Bug sub-states** live inside the story file's Bug Report section
  (`DIAGNOSING → FIXING → FIXED`); they do NOT change the story's main
  `Status:` and do NOT mutate `STORIES_INDEX.md`.
- **`STORIES_INDEX.md`** is the single source of truth for selection /
  dependency resolution. Full protocol: `references/stories-index.md`.
