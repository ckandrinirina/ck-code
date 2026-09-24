# ck-code Workflow Map — Single Source of Truth

The full lifecycle, from spec to ship. Skills cross-reference this file instead of
duplicating the workflow graph.

## Workflow order

```
0. /ck-code:guide        Active entry-point — no arg: state → next step; free-text: intent → skill; --command: syntax

1. /ck-code:spec         (Optional) Stakeholder-friendly feature spec
2. /ck-code:design       Spec → architecture docs (docs/architecture/); also sync/optimize maintenance
3. /ck-code:team         Architecture → expert + guide skills (.claude/skills/); also captures house conventions
4. /ck-code:plan         Architecture → epics, stories, roadmap (tasks/); asks the plan's
                        integration level once; --quick adds one story
5. /ck-code:plan --publish   (Optional) Publish the plan → GitHub Issues
6. /ck-code:track        Show progress / find next ready story

7. /ck-code:build        TDD-implement stories (story → done): one inline, several at once in
                        worktrees (story IDs), or a whole epic in waves (--epic NN); also a
                        bug story's recorded fix (Bug-Fix Mode)
   /ck-code:fix          Diagnose a bug, record it to its story (→ bug), route the fix

8. /ck-code:ship         Commit, open PR, update GitHub Issues; --promote opens the epic
                        or plan PR

   /ck-code:migrate      (One-shot) Upgrade a v6, pre-v6 or ck-code-lite project to the v7 layout
   /ck-code:explain      (Anytime) Explain what was just built + verify steps
   /ck-code:config       (Anytime) Project settings — issue tracking, trunk, GitHub Project
                        board, a plan's integration level (config integration)
   /ck-code:doctor       (Anytime) Report what is broken in the project + how to fix it
   /ck-code:doctor --fix (Anytime) Reconcile delivery, board and Issues with GitHub, commit
                        the changed story/epic/plan records
```

## Hand-offs

| After running … | Recommended next step |
|---|---|
| `spec` | `/ck-code:design` |
| `design` | `/ck-code:team` (`/ck-code:team --refresh` when it changed `tech-stack.md` or `folder-structure.md` and team skills exist) |
| `team` | `/ck-code:plan` |
| `plan` | `/ck-code:plan --publish` *(optional)* or `/ck-code:track next` |
| `plan --quick` | `/ck-code:build <new story>` |
| `track next` | `/ck-code:build [path]` |
| `build` | `/ck-code:ship` (inline, once per story); after PARALLEL MODE merged into an epic or plan branch, `/ck-code:ship --promote --epic NN` (or the plan) — never one ship per story |
| `fix` (easy) | auto-runs `/ck-code:build` → `/ck-code:ship` |
| `fix` (complex) | `/ck-code:build <story>` or `/ck-code:build <ids>` (Bug-Fix Mode) |
| `ship` | `/ck-code:track next` (more stories) or `/ck-code:explain` |
| `doctor` | the finding's repair command; `/ck-code:doctor --fix` for delivery/board/issue drift |
| `doctor --fix` | `/ck-code:track` (refreshed picture) |

## Invocation matrix

Which hand-offs may actually *run*, and which side makes the call. The mechanics — the
prompt, the chain guard, argument discipline — live in
[`skill-invocation.md`](skill-invocation.md); this table is only the graph.

**Both tiers ask the user exactly once.** The tier says *who runs the `Skill` call* — the
skill itself (DIRECT) or the main session on its behalf (DIRECTIVE) — never *whether* the
user is asked. An **INTERNAL** row is one skill switching to another of its own modes: it
asks the same single question but makes no `Skill` call and adds no link to the chain.

| Caller | Callee | Tier | Trigger |
|---|---|---|---|
| `spec` | `design` | DIRECT | spec approved by the user |
| `design` | `team` | DIRECT | feature docs written, no team skills yet |
| `design` | `team --refresh` | DIRECT | `tech-stack.md` or `folder-structure.md` changed and team skills exist |
| `team` | `plan` | DIRECT | expert + guide skills generated |
| `plan` | `design` | DIRECT | no `docs/architecture/` exists |
| `plan` | `plan --publish` | INTERNAL | issue tracking enabled in `tasks/SETTINGS.md` — the same skill switching mode, one ask, no `Skill` call and no chain link |
| `plan --quick` | `build <new story>` | DIRECT | story written (not when `plan --quick` was itself called from `build` — the chain guard returns to `build`) |
| `build` | `team` | DIRECT | project has no expert skills and no `experts: none` ([`skill-detection.md`](skill-detection.md) Step 4a.1) |
| `build` | `plan --quick` | DIRECT | no story exists for the work in hand |
| `build` | `fix` | DIRECT | a pre-existing bug blocks the story |
| `build` | `ship` | DIRECT | story done and the user chose SHIP at 8.5.1 Q2 |
| `build` (PARALLEL MODE) | `ship --promote --epic NN` (or the plan) | DIRECT | the run merged into an epic or plan branch |
| `fix` | `plan --quick` | DIRECT | a missing-functionality slot needs a story (Phase 2.6) |
| `fix` | `build` | DIRECT | AUTO-BUILD eligible (Phase 6.3) |
| `config` | `doctor` | DIRECT | board mapping changed |
| any gated skill | `migrate` | DIRECT | version gate BLOCKed ([`version-gate.md`](version-gate.md)) |
| `ship` | `explain` / `track next` | DIRECTIVE | after delivery |
| `track next` | `build <path>` | DIRECTIVE | next ready story selected |
| `doctor` | `migrate` / `config` | DIRECTIVE | a finding carries a repair command |
| `doctor` | `doctor --fix` | DIRECTIVE | the findings are delivery, board or issue drift |
| `doctor --fix` | `track` | DIRECTIVE | after reconciliation, for the refreshed picture |
| `doctor --fix` | `plan --publish` | DIRECTIVE | the report named entries with no `issue:` |
| `guide` | any | DIRECTIVE | free-text task routed |

No other pair may hand off. A skill that believes it needs an edge not listed here adds it
to this table first.

## When to use which

| Choice | Use this | Not this |
|---|---|---|
| Single story, sequential, deepest-quality TDD | `build <story-path>` | `build <ids>` |
| Multiple unrelated stories, independent files | `build <ids>` (PARALLEL MODE) | one `build` per story |
| Every story of an epic, dependencies and all | `build --epic NN` (waves) | `build <ids>` |
| Bug in already-implemented code | `fix` | `build` |
| Push the plan to GitHub for tracking | `plan --publish` | `ship` |
| Deliver code (commit + PR + close issues) | `ship` | `plan --publish` |
| Open the PR for a finished epic or plan | `ship --promote` | one `ship` per story |
| Change how a plan's work merges (story / epic / plan) | `config integration <tasks/plan> <level>` | editing `OVERVIEW.md` by hand |
| See what is broken, change nothing | `doctor` | `doctor --fix` |
| Repair delivery/board/issue drift (PR merged but not showing) | `doctor --fix` | `doctor` |

`plan --publish` (mirror the *plan* to GitHub Issues) and `ship` (mirror the
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
| `team` | breaking the architecture into epics/stories | `plan` |
| `plan` | one small addition to an existing plan | `plan --quick` |
| `plan` | no architecture docs yet | `design` (first) |
| `plan` | stakeholder-facing spec, not a task breakdown | `spec` |
| `plan` | a bug in already-implemented code | `fix` |
| `build` | an **un-triaged** bug in already-implemented code | `fix` (first — a `bug`-status story is already triaged and stays in `build` Bug-Fix Mode) |
| `build` | no story exists for the work | `plan --quick` or `plan` |
| `fix` | new functionality / new acceptance criteria (not a bug) | `plan --quick` then `build` |
| `doctor --fix` | you only want to know what is broken, changing nothing | `doctor` (read-only) |
| `doctor --fix` | finished code to commit and put in a PR | `ship` |
| `doctor` | the findings are stale bookkeeping and you want them fixed | `doctor --fix` |
| `fix` | just committing a finished change | `ship` |
| `fix` | implementing a fix already diagnosed (story at `bug`) | `build` (Bug-Fix Mode) |
| `ship` | the story isn't implemented yet | `build` / `fix` (first) |
| `ship` | publishing the plan (not code) to GitHub Issues | `plan --publish` |
| `ship` | changing a plan's integration level | `config integration` |
| `migrate` | generating *new* architecture docs from a spec | `design` |
| `design` / `plan` / `build` | the project is a ck-code-lite one (`tasks/PLAN.md`) | `migrate` (first — it converts the flat plan into epics/stories) |

When the user is simply unsure which skill to run (no work invoked yet), route them:
`/ck-code:guide "<task>"` maps a plain-language task to a skill, `/ck-code:guide` (no arg)
recommends from project state, and `/ck-code:guide --command <name>` is the static
command reference.

## Output locations

| Skill | Writes to |
|---|---|
| `spec` | `docs/specs/YYYY-MM-DD_<slug>/spec.md` (+ canonical `.metadata.json`), optional GitHub issue, optional `design-brief.md` when the Claude Design offer is accepted |
| `design` | `docs/architecture/*.md` + `features/<slug>/index.md` (frontmatter `design: pending`); in `ds` mode, `docs/architecture/design-system/` (`index.md` body + `manifest.json`, the one metadata home) and the `designSystem` block of every pending spec metadata |
| `team` | `.claude/skills/expert-*/SKILL.md`, `.claude/skills/guide-*/SKILL.md` (incl. `guide-conventions/`); `--refresh` rewrites only the owned skills `ck-team stale` names |
| `plan` | `tasks/YYYY-MM-DD_<slug>/` (`OVERVIEW.md` plan record with the integration level, epics/ with EPIC.md, stories/ with frontmatter, ROADMAP.md); flips feature doc to `design: planned`. `--publish` creates the GitHub Issues and writes each number back to `issue:` (story, `EPIC.md`, or `OVERVIEW.md` for `--mode plan`) |
| `build` | Source + tests in repo; the story file only (frontmatter `status`, `files:` via `ck-story files`, plan, summary; Bug Report Resolution in Bug-Fix Mode); on GitHub, assigns the story's linked `issue:` to the account running the build (plus the epic issue on an `--epic NN` run) — additive, never removing an existing assignee. In PARALLEL MODE: every story implemented by a dispatched agent — per-story branches in native worktrees when a wave holds ≥ 2 stories, one solo agent on the target branch in the main checkout when it holds one — with the same story-file outputs; the wave-start commit holds the `status: in-progress` story files only |
| `fix` | Failing reproduction test, story file (Bug Report + Fix Plan, frontmatter `status: bug` + `prior_status`). Auto-invokes `build` for an easy fix; never writes the source fix itself |
| `ship` | Git commit, PR, GitHub Issue updates; writes the PR number + `delivery: pr` back to story frontmatter (`pr:`), or to `EPIC.md` / `OVERVIEW.md` for a `--promote` PR; no local writes outside git + frontmatter |
| `migrate` | Converts a v6 project with `ck-migrate v7` (one commit); a legacy (v3–v5) project through the legacy steps to v6, then `ck-migrate v7`, in the same commit — including flattening nested `experts/` + `guides/` skill folders; or a ck-code-lite project straight to v7 (`tasks/PLAN.md` → epics/stories, `docs/ARCHITECTURE.md` → `docs/architecture/`, lite artifacts marked superseded); stamps `tasks/VERSION.md` `layout: v7` |
| `track`, `explain`, `guide`, `doctor` | Read-only |
| `doctor --fix` | Reconciles derived state only (`ck-project reconcile`, then confirmed `ck-project landed` entries) — `delivery:`/`pr:` frontmatter, board columns, GitHub Issue/PR state; commits the changed story/`EPIC.md`/`OVERVIEW.md` files as `chore(tasks): reconcile delivery with GitHub`. Never writes `status:`, a story body, or source |
| `config` | Writes `tasks/SETTINGS.md`, the GitHub Project board, and a plan's integration level (`ck-plan set`) — never story state |

No skill ever stages or commits `STORIES_INDEX.md` or `EPICS_INDEX.md`: they are
gitignored views, regenerated locally by `ck-index`, `ck-story set`, `ck-view` and the
session-start hook.

## State conventions (v7)

- **Story status** lives ONLY in the story-file frontmatter `status:`
  (`todo → in-progress → done`, plus `bug` and `skip`, lowercase). Every index is a
  generated view of it — see [`data-model.md`](data-model.md). Change it with
  `ck-story set <story> status=<value>`.
- **Ready rule:** a story is **ready** when `status: todo` and every `blocked_by` story is
  `done` or `skip`, or when `status: bug`. An `in-progress` story is not ready; `build` may
  resume it when named explicitly.
- **Story delivery** is the second, orthogonal axis: frontmatter `delivery:`
  (empty `→ pr → merged`, or `direct` for work that reached the trunk with no PR) with `pr:`
  naming the PR. `status` says the work is finished; `delivery` says how far it has
  travelled toward the trunk branch. `ship` writes `pr`, `ck-project reconcile` (run by
  `ship` and `doctor --fix`) promotes it to `merged` from GitHub. `blocked_by` never
  resolves against `delivery`.
- **Plan record:** `tasks/<plan>/OVERVIEW.md` frontmatter carries the plan's integration
  level (`story` | `epic` | `plan`), its `branch:`, `issue:`, `pr:` and `delivery:`. `plan`
  sets the level once; `config integration` changes it; both write through `ck-plan set`.
- **Bug flow:** `done → bug` (set by `fix` when it diagnoses a bug on a shipped story,
  recording the previous status in frontmatter `prior_status:`) `→ done` (restored by
  `build` Bug-Fix Mode when the recorded fix lands). A `bug` story is actionable work —
  `track` and `build` surface it.
- **Bug Report sub-status** (`DIAGNOSED` → `FIXED`) lives in the story body only; it is
  narrative and does not affect the frontmatter `status:`.
- **Indexes are generated, gitignored and disposable.** `STORIES_INDEX.md` and
  `EPICS_INDEX.md` are never hand-edited and never committed; a stale one is regenerated on
  the next read (`ck-view`, the session-start hook) or by `ck-index`. Doctor reports a
  committed view as an ERROR (a v6 leftover — `/ck-code:migrate`). The separate GitHub axis
  is reconciled by `/ck-code:doctor --fix` — see [`data-model.md`](data-model.md).
