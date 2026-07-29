# Changelog

All notable changes to ck-code are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [5.0.0] — 2026-07-29

### Removed
- **parallel-build**: the `/ck-code:parallel-build` command no longer exists. Every one of its
  capabilities — multi-story worktree dispatch, dependency-ordered epic waves, conflict
  analysis, per-branch QA, merge orchestration — now lives inside `/ck-code:build`. **Migration:**
  `parallel-build 02-05 03-01` → `build 02-05 03-01`; `parallel-build --epic 02` → `build --epic 02`.

### Changed
- **build**: accepts a story path (inline, unchanged), two or more story IDs, or `--epic NN`.
  One story in scope still runs Phases 1–8 inline; two or more enter the new `PARALLEL MODE`
  (P1–P9), so the two skills no longer hand off to each other mid-run. The duplicated version
  gate, feature gate, index read, `files:` conflict map, whole-epic detection, and team gate
  collapse to one implementation.
- **build**: new `DELEGATED MODE`, active when a dispatch prompt begins `MODE: delegated`. A
  worktree agent now has an explicit per-phase contract — no branch question, no `ck-index.sh`,
  no manual-test gate, no ship — instead of that contract living only in the dispatching agent's
  prompt. This closes a real hazard: a dispatched `build` could previously run the generator
  inside its worktree.
- **build references**: `agent-prompts.md`, `wave-mode.md`, and `conflict-format.md` moved from
  `skills/parallel-build/references/` to `skills/build/references/`; new `parallel-mode.md`
  carries the full P1–P9 orchestration detail, read only when two or more stories are in scope;
  `parallel-switch.md` removed (its epic-wave offer is now build Phase 1.4 inline).
- **agents**: `story-implementer`, `conflict-analyzer`, and `qa-validator` now describe
  themselves as `/ck-code:build` PARALLEL MODE workers.

## [4.2.0] — 2026-07-27

### Added
- **migrate**: converts a **ck-code-lite** project to the v4 layout. A new PHASE L turns the
  flat `tasks/PLAN.md` into epics and stories — proposing a grouping (inferred from task
  titles and `files:` paths) that you confirm before anything is written — and splits
  `docs/ARCHITECTURE.md` into `docs/architecture/`. Statuses, acceptance criteria and ticked
  checkboxes carry over, so finished work stays finished; `blocked` becomes `todo` (v4 has no
  such status) and every re-triaged task is listed in the report along with the full
  `T-NN → EE-SS` ID map. Feature docs are written as stubs — `/ck-code:design` fills them.
  The lite artifacts are marked superseded, never deleted, and the whole conversion lands in
  one revertable commit. New mapping reference: `skills/migrate/references/lite-migration.md`.

### Fixed
- **version-gate**: a ck-code-lite project tripped none of the pre-v4 markers, so the gate
  stamped it `layout: v4` and every skill then planned straight past a `tasks/PLAN.md` it had
  never read. A `LITE` marker now blocks and routes it to `/ck-code:migrate`, which renames
  `PLAN.md` on its way out so the marker cannot re-fire.

## [4.1.2] — 2026-07-27

### Fixed
- **subagent-fanout / plan / team / design / migrate / fix**: the declared fan-outs almost
  never ran. Each was written as a suffixed sub-step (`plan` 5.4b, `team` 3.1a, `design`
  3.8a) placed *after* the inline "write each one" instruction — read top to bottom,
  everything was already written by the time the fan-out was reached, so it applied to zero
  remaining units. Three further causes compounded it: hedged framing (`plan` 2.5 was
  literally titled "(Optional)"), thresholds of 4–8 units that sat just above the common
  case, and no HARD GATE naming the fan-out, unlike `build`'s `qa-validator` delegation
  which is gated and does fire reliably. Every site is now **decision-first** — count the
  units, announce the branch, then produce — with the threshold lowered to **3** and the
  fan-out named in each skill's HARD GATES / RULES. `subagent-fanout.md` carries the rule
  as a shared contract, plus a mandatory announcement in both directions so a
  below-threshold run is visibly sequential rather than indistinguishable from a forgotten
  one.

### Changed
- **team**: experts and guides now share a single dispatch decision at Phase 3.1. Phase 3b
  (guide generation) previously had no fan-out at all, and on a `--standard` run guides
  usually outnumber experts — so the largest write batch in the skill was always sequential.
  Phase 3 is now 3.0 merge-rule resolution → 3.1 dispatch decision → 3.2/3.3 per-file
  content contracts, which also removes the duplicated write instructions.

## [4.1.1] — 2026-07-27

### Changed
- **team**: house conventions are now settled inside a normal run instead of requiring a
  second command. The Phase 2.4 plan prompt asks a second question — **Capture now / Skip**
  when `guides/conventions/SKILL.md` is absent, **Keep as-is / Refresh & merge** when it
  already exists — and a new Phase 2.5 runs PHASE C before any skill file is written, so
  every prompt is front-loaded and generation runs unattended. The inline path reuses the
  Phase 1.3 codebase scan rather than re-scanning, which is the duplicated work this
  removes. `--conventions` still works as a standalone re-capture; `--check` reports the
  conventions row without prompting.

### Added
- **team**: an opt-in `--workflow` flag that runs the two largest fan-outs — Phase 1.6a
  per-technology research and Phase 3.1a per-skill generation — as scripted `Workflow` runs
  instead of a one-message `Agent` dispatch. This buys three things the `Agent` path cannot
  give: schemas enforced at the tool layer instead of hoped for in prose, a scripted
  retry-until-dry loop over units that came back empty, and `resumeFromRunId` so a run that
  dies at skill 7 of 12 replays the cached prefix instead of re-paying it. Scripts live as
  reviewable markdown at `skills/team/references/{research,generate}.workflow.md`.
- **references/dynamic-workflows.md**: the shared contract for this, sibling to
  `subagent-fanout.md`. `Workflow` is positioned strictly as an execution *backend* for a
  fan-out `subagent-fanout.md` already sanctions — never a new fan-out, since a single message
  of `Agent` calls is already concurrent. Covers the three-part opt-in gate (tool present +
  explicit user signal + a threshold above the skill's inline one), the hint-line-not-a-prompt
  rule that makes a silent 15-agent fan-out impossible, the mandatory inline fallback, the
  script sandbox rules, and two verified environment facts: `$CLAUDE_PLUGIN_ROOT` is **empty**
  inside a workflow subagent, and `WebSearch`/`mcp__*` tools are deferred there and must be
  loaded with `ToolSearch` before use.

### Changed
- **team**: Phase 4.1's `ls` is now explicitly the proof of what was written. A resumed
  workflow replays cached results *without* re-writing, so a returned manifest can claim a
  file that no longer exists on disk — measured, not assumed.

## [4.0.3] — 2026-07-27

### Added
- **build**: a size-driven effort route (Phase 1.7). A `size: S` story (and Bug-Fix Mode,
  whose scope is already the recorded Fix Plan) takes the LEAN route — a 2–4 line SOLID note
  instead of the full template, a 3-task chain instead of 6, and a targeted SOLID spot-check
  instead of the full compliance review. `size: M` keeps the full ceremony. The route scales
  ceremony only: the version gate, skill detection, RED-before-GREEN, the `## Unplanned
  Changes` log, QA delegation with its cap, and the manual-test gate are identical on both
  routes, and a LEAN story that outgrows its size escalates to FULL. This is the dynamic
  half of effort control — `build` intentionally declares no `effort:` frontmatter so your
  `/effort` and `/fast` toggles still apply on top.

### Changed
- **ship / parallel-build / fix**: added the missing `effort:` frontmatter — `ship` and
  `parallel-build` run at `medium` (mechanical git/`gh` work and pure orchestration) and
  `fix` at `high` (root-cause diagnosis). Previously all three inherited the session
  effort, so a commit-message write could run at `xhigh`. `build` deliberately keeps no
  `effort:` so the user's `/effort` and `/fast` toggles still scale it per story size.
- **ship**: the file-set and commit-message confirmations are now one batched
  `AskUserQuestion` call instead of two sequential prompts, and the PR base branch is read
  from `gh repo view --json defaultBranchRef` instead of being asked for. A happy-path
  ship costs 2 user round-trips instead of 4.
- **build**: the manual-test gate (8.5) and the ship choice (8.7) are asked in one batched
  call — the ship answer is already known at 8.5, so asking it separately cost a needless
  round-trip on every story.
- **build**: the RED/GREEN/REFACTOR phase reports are one line each instead of three
  heading blocks; a full block is now reserved for off-nominal results (a test passing
  during RED, a refactor breaking green).
- **build**: Phase 2 no longer restates the `skill-detection.md` team gate it already
  reads — it delegates to that procedure and keeps only the two build-specific bindings.
- **story-implementer**: sets `model: opus` explicitly with a stated rationale, satisfying
  `subagent-fanout.md`'s "never omit `model:`" rule; the tier is unchanged from the
  previous implicit inheritance, so there is no quality change.

### Fixed
- **scripts/ck-index.sh**: `emit_plan`'s awk pass over every story file ran twice per plan
  (once for `STORIES_INDEX.md`, once for the `FEATURE_INDEX.md` rollup). Both consumers now
  share one memoized pass, halving the per-plan story scan. Output is byte-identical.
- **references/skill-detection.md**: the legacy anchor-mapping tables moved to
  `skill-detection-fallbacks.md`, read only when a project has an expert or guide whose
  frontmatter declares no `paths:`/`keywords:`. Trims ~1.3 KB from every `build` and `fix`
  Phase 2 on current projects.

## [4.0.2] — 2026-07-17

### Fixed
- **story-implementer**: the agent now inherits the full tool set instead of a
  read-only-style `tools:` allowlist, so a story that needs `DesignSync` or any other
  unlisted tool can actually be built rather than forcing `parallel-build` to fall back
  to a generic agent; the worktree and push boundaries stay enforced by its Constraints.

## [4.0.1] — 2026-07-17

### Changed
- **build / parallel-build**: a project with no expert or guide skills now warns that
  `/ck-code:team` has not run and asks `RUN TEAM FIRST / CONTINUE WITHOUT SKILLS` instead
  of silently building generic, un-tailored code; `parallel-build` gates once before
  dispatch because its sub-agents cannot prompt.

## [4.0.0] — 2026-07-15

Major release. **One writable source of truth for story state — the story-file YAML
frontmatter — with every index regenerated from it.** This removes the drift the v3
data model created (status stored in the story file *and* `STORIES_INDEX.md` *and*
`FEATURE_INDEX.md` *and* `EPIC.md`), and the machinery that existed only to repair or
work around that drift. 18 skills consolidate to 12.

### Migrating from v3

Run `/ck-code:migrate` once per project — it is a one-shot, idempotent, safe converter
(refuses a dirty tree; lands all conversions in a single revertable commit). Every
change-producing skill's version gate now keys on `layout: v4` and **blocks** a pre-v4
project until you migrate; the `SessionStart` hook also surfaces a migrate notice.
Pre-v3 projects are handled too (the converter chains the older layout conversions).

### Added
- **data model** (`references/data-model.md`): story frontmatter (`id, title, epic,
  status, size, blocked_by, files, issue, prior_status`) is the single source of truth;
  `STORIES_INDEX.md` / `FEATURE_INDEX.md` are generated read-only views.
- **`scripts/ck-index.sh`**: regenerates both indexes from frontmatter (bash 3.2-safe,
  awk rollup). Skills run it after any frontmatter change — views cannot drift.
- **migrate**: the v3(and older)→v4 converter (replaces `doc-optimizer upgrade`).
- **guide**: one arg-aware router replacing `start` + `advise` + `help` (no arg → next
  step from state; free text → best-fit skill; `--command` → syntax).

### Changed
- **build / fix / parallel-build / plan / ship / design**: mutate story frontmatter and
  regenerate views instead of cell-editing indexes. `parallel-build` rebuilt on native
  worktree isolation + `SendMessage` resume + structured-output returns (1639→542 lines).
- **plan** absorbs `quick-story` as `--quick`; **team** absorbs `convention` (marker-based
  non-destructive regeneration); **design** absorbs `doc-optimizer` optimize/sync;
  **ship** absorbs `to-issues` as `--to-issues` and links issues by frontmatter `issue:`
  number (not title-substring); **pre-spec** → **spec**.
- **team**: `expert-templates.md` refactored 988→227 lines (one base template + per-role
  deltas); tier semantics stated once.
- All YES/NO/ADJUST gates now use `AskUserQuestion`; `DESIGN_LEDGER.md` replaced by a
  `design:` frontmatter flag; dated journal/delta docs no longer written (git is history).
- **hooks**: `session-start.sh` gains a pre-v4 migrate notice, jq-free JSON escaping, and
  multi-plan aggregation; `format.sh` runs prettier only when a project config is present.

### Removed
- **BREAKING**: the v3 layout (prose `Status:` headers, hand-maintained `Schema: v1/v2`
  indexes, `EPIC.md` story tables, `DESIGN_LEDGER.md`, `L`/`XL` sizes). v4 reads only the
  v4 layout; run `/ck-code:migrate` to convert.
- Skills `sync`, `quick-story`, `convention`, `doc-optimizer`, `to-issues`, `pre-spec`,
  `start`, `advise`, `help` (folded into the skills above or deleted). `sync` is gone
  entirely — generated views cannot drift, so there is nothing to reconcile.

## [3.5.0] — 2026-07-15

Reshapes `fix` from an end-to-end fixer into a **bug triage + routing** orchestrator that records the fix into the backlog for `build` to implement.

### Added
- **fix**: diagnoses a bug, writes a failing reproduction test + Fix Plan into the story, and flips it to a new `BUG` status (story file + `STORIES_INDEX.md` + `FEATURE_INDEX.md`). An Auto-Build Eligibility Gate (verdict A + single confirmed cause + ≤3 files + LOW risk) auto-runs `/ck-code:build`; anything complex (multi-story, high-risk, uncertain) is recorded and handed off to a manual `build`/`parallel-build`.
- **build**: **Bug-Fix Mode** (`references/bug-fix-mode.md`) — a `BUG`-status story implements only its recorded Fix Plan, takes the `fix`-written reproduction test RED→GREEN, fills the Bug Report Resolution, and restores the story's `Prior status`.
- **BUG status**: added to `stories-index.md`, `feature-index.md` (counts as not-done; rolls the feature to `IN PROGRESS`), and surfaced as actionable work by `track`, `sync`, and `parallel-build`.

### Changed
- **fix**: missing functionality (verdict D) now scaffolds real `TODO` stories through `/ck-code:quick-story` instead of writing inline stubs; verdict C still defers to `/ck-code:design`.
- **fix**: no longer writes the source fix, runs QA, or ships — those move to `build` (Bug-Fix Mode). Bug Report sub-status simplified to `DIAGNOSED` → `FIXED`.
- **workflow-map / README / help**: updated hand-offs, state conventions (`DONE → BUG → DONE`), and skill descriptions for the new flow.

## [3.4.0] — 2026-07-10

LTS release of the v3 line — stabilization and optimization only, preparing the ground for v4. No logic, workflow, command, or template-field changes.

### Changed
- **all skills**: token-efficiency pass across every skill, agent, and shared reference — deduplicated instructions between SKILL.md files and their references (each rule now has one authoritative copy plus pointers), compressed verbose prose, and removed decorative separators (net −154 lines).

### Fixed
- **build**: stale phase numbers in `story-template.md` and the NEXT section (renumbered to match the current Phase 1/8 layout: manual-test gate is 8.5, parent-epic update is 8.7, status transitions are 1.6).
- **fix**: `qa-dialogue.md` verdict C recommended `/ck-code:plan` for missing functionality, contradicting the governing flow (2.5.3) which routes to `/ck-code:design`.
- **plan**: mangled example paths in the Stories Index template (`01*<slug>` → `01_<slug>`).
- **pre-spec**: stale Q&A phase references in `templates.md` (Phase 3 → Phase 2).
- **parallel-build**: `examples.md` showed `git worktree remove -f -f`, contradicting SKILL.md and pipeline.md which use a single `-f`.
- **convention**: broken code-fence placement in `conventions-guide-template.md` left half the template sections outside the fenced block.
- **team**: two sentences in SKILL.md severed mid-way by stray bullets (INPUT `--basic` scope; Phase 1.2 read rule) rejoined.

## [3.3.7] — 2026-07-10

### Fixed
- **parallel-build**: dispatched agents with `isolation: none` and `cwd:`, neither of which exists in the Agent tool schema — QA agents silently ran in the main checkout and could return `PASS` for code the story never wrote, greenlighting an unbuilt branch for merge.
- **parallel-build**: the orchestrator now creates each worktree itself, pinned to `$TARGET_SHA` behind a branch-name collision guard, instead of delegating to `isolation: worktree` (which cut from a harness-chosen base where agents could not find their story file).
- **parallel-build**: Phase 3.5b is now an assertion on the pinned base rather than a rebase, so a drifted branch is surfaced as `🚫 BLOCKED` instead of being silently rewritten.
- **story-implementer**: step 0 now `cd`s into the assigned worktree before proving its location, and forbids `checkout -b` / `rebase` / `reset`.

## [3.3.6] — 2026-07-10

### Changed
- **parallel-build**: a single story no longer builds inline in the orchestrator — it dispatches one worktree agent (N=1), skipping only cross-branch conflict analysis, so the long-lived main context never absorbs a build transcript. Terminal waves lose their inline exception too.
- **parallel-build**: post-merge QA is delegated to a `qa-validator` agent instead of running its test suite inline on the merged target.
- **parallel-build**: bounded-output discipline throughout — Phase 1.4 extracts file paths instead of whole tables, Phase 3.5 uses `--numstat` instead of diff bodies, Phase 4's dry-run keeps only `CONFLICT` lines, and Phase 6.5.1 reads only the acceptance-criteria section.

### Added
- **parallel-build**: `references/context-budget.md` — the orchestrator's inline-vs-delegate contract, with the safe-inline and forbidden-inline command lists.
- **qa-validator**: documented its `parallel-build` per-story and post-merge QA modes, including the compact `QA: PASS` / `QA: FAIL` verdict contract.

## [3.3.5] — 2026-07-10

### Changed

- **parallel-build**: manual testing moved from the pre-merge per-worktree gate (old Phase 5.5) to a post-merge Phase 6.5 on the target branch, because an agent worktree has no runnable environment; bug fixes now commit to `$TARGET`, wave mode gates once per wave right after each wave merge, and merge-eligibility depends on automated QA alone.

## [3.3.4] — 2026-07-09

### Added

- **plan**: Phase 4.4b parallel story-file generation — when a confirmed plan has ≥8 stories, story files are written by one Sonnet artifact agent each (per `subagent-fanout.md`), while overview, epics, indexes, ledger, and roadmap stay orchestrator-owned. Smaller plans keep writing inline.
- **team**: Phase 1.6a parallel research — when ≥4 technologies need research, each gets its own read-only Haiku investigator (context7 + WebSearch) returning a structured brief; the orchestrator merges briefs into the Best Practices Knowledge block, keeping verbose doc output out of its context. Fewer technologies research inline.

## [3.3.3] — 2026-07-09

### Changed

- **version gate**: made lazy. Each skill now inlines the Tier-1 stamp check (`tasks/VERSION.md` reads `layout: v3` → proceed), and `references/version-gate.md` is loaded **only** when the stamp is missing or stale. A migrated project pays ~55 tokens instead of ~1,500 on every `design`/`plan`/`build`/`fix`/`ship`/`parallel-build` run; pre-v3 projects are still detected and routed to `/ck-code:doc-optimizer upgrade`. No user-visible behavior change.

## [3.3.2] — 2026-07-09

### Added

- **subagent-fanout**: model tiers on the fan-out contract — investigation (read-only) units run on `haiku`, artifact (templated write) units on `sonnet`, with escalation stated explicitly; every fan-out skill inherits this instead of letting subagents run on the orchestrator's model.

### Changed

- **all skills**: each rule is now stated once in its phase; `RULES` blocks are bare absolutes rather than a second copy of the phase bodies — about 7.2k tokens off always-loaded skill bodies.
- **track**, **to-issues**: inline dashboards and issue-body heredocs moved to `references/`, so only the invoked command's template loads.
- **help**: rewritten as a command table plus a pointer to the workflow map.
- **conflict-analyzer**: pinned to `sonnet`; dry-run merges and hunk classification are mechanical.
- **fix**, **doc-optimizer**, **team**: model pins at each dispatch site; **to-issues** set to `effort: low`.

### Fixed

- **design**: handed off to `plan`, skipping `team`, contradicting the workflow map and `start`'s own gate; **plan** now names `team` as a prerequisite.
- **parallel-build**: `examples.md` demonstrated globbing story files — the anti-pattern Phase 1.1 forbids — and carried stale option numbers; QA commands are now detected per component manifest instead of a hardcoded epic-to-stack map.
- **help**: documented retired pre-v3 layer docs and a fixed expert list, both contradicting the derived-skills design.
- **build**: malformed code fences broke the Files Touched block in `story-template.md`.
- **quick-story**: repo-root-relative reference links that did not resolve from the skill directory.

## [3.3.1] — 2026-07-02

### Changed
- **plan**: every plan run now ends with a mandatory final Integration & E2E epic (Phase 2.4) that proves the whole feature/project works end-to-end through real entry points, `Blocked by` all prior epics — its stories exercise real user journeys and stay sized to one dispatch (split by journey when needed).

## [3.3.0] — 2026-07-02

### Added
- **reuse-first**: new shared constraint `references/reuse-first.md` (read context first, reuse before rebuilding, simplest viable approach, don't re-analyze what's already clear) — mirrors the `no-ai-references.md` pattern and extends the anti-overthinking discipline that already lived in `build`/`fix` up into the authoring skills.

### Changed
- **design / plan / team / pre-spec**: each now cites `reuse-first.md` and carries one surgical guard at its overthinking hotspot — `design` treats spec/doc-answered dimensions as CLEAR (no manufactured gaps); `plan` restricts ultrathink to genuine ambiguities and reuses settled architecture; `team` scopes the mandatory research to current/version-specific/project-relevant practices (no padded fundamentals); `pre-spec` lists only genuinely relevant forgotten items instead of padding to a 5-12 count.

## [3.2.0] — 2026-06-30

### Added
- **advise**: new plain-language entry-point skill. The user describes a task in their own words (`/ck-code:advise "fix the login crash"`) and the skill recommends the best-fit ck-code skill, names any missing prerequisite, and prints the exact command — read-only, never launches. Routes by *intent*, complementing `start` (routes by project *state*) and `help` (static reference). Wired into `references/workflow-map.md`, `help`, and `start`.

## [3.1.15] — 2026-06-30

### Added
- **all skills**: a `## ROUTING CHECK` block at the top of every action skill (pre-spec, design, team, plan, to-issues, build, parallel-build, fix, quick-story, ship, sync, convention, doc-optimizer) that detects a wrong-tool invocation and redirects to the correct skill (e.g. `quick-story` → `fix` for a bug, `build` → `parallel-build` for many independent stories). A single "Misuse redirects — am I the right skill?" matrix in `references/workflow-map.md` is the source of truth; `start` and `help` now surface it too.

## [3.1.14] — 2026-06-11

### Changed
- **parallel-build**: cut launch-time context use in the same way as `build`. Phase 1.4 no longer full-`Read`s every ready story body to recommend the parallel-safe set — it extracts only each ready story's `Files to Create/Modify` table via a batched `awk` call, keeping every story's acceptance criteria and technical notes out of the long-lived orchestrator context.

## [3.1.13] — 2026-06-11

### Changed
- **build**: cut launch-time context use during interactive story selection. Phase 1.2 no longer full-`Read`s every ready story body to detect the parallel-safe set — it extracts only each ready story's `Files to Create/Modify` table via a batched `awk` call, leaving the single selected story (Phase 1.3) as the only full story read. Phase 2 now matches experts/guides against that known touched-files set, preferring narrow `paths` matches over broad `keywords` matches so unused skill bodies stay out of the resident session.

## [3.1.12] — 2026-06-11

### Changed
- **design**: trimmed the generated architecture-doc templates so emitted `docs/architecture/*` files are leaner — slimmed `dev-guide.md` and `configuration.md` scaffolds, dropped the inline folder-structure example tree, and condensed README/feature-doc prose. Section headings, routing tables, `_shared` anchors, and the DESIGN_LEDGER schema are unchanged.
- **plan**: condensed the story Implementation Tasks template, replacing verbose inline examples with a compact placeholder.
- **team**: removed the Build & Tooling and Dependencies sections from the generated language-guide template (covered by `tech-stack.md`/`dev-guide.md` — one rule, one doc) and condensed the QA Test Strategy and analyst Report Format scaffolds in the expert templates.

## [3.1.11] — 2026-06-09

### Changed
- **fix**: Phase 7 QA now always delegates the suite/build/lint to the Haiku `qa-validator` agent (inline only as a fallback), and Phase 4 reproduction delegation was upgraded to the same token-efficiency mandate — heavy output stays off the main fix session, matching the `build` Phase 7 pattern.

## [3.1.10] — 2026-06-09

### Changed
- **qa-validator**: pinned the agent to the `fast` (Haiku) tier so every QA pass runs on the cheapest model in its own context, keeping verbose build/test/lint output off the expensive orchestrator session.
- **build**: Phase 7 now always delegates QA to the Haiku `qa-validator` agent (inline only as a fallback) for token efficiency.
- **parallel-build**: Phase 5 now dispatches one Haiku `qa-validator` agent per story in a single parallel batch instead of running `cargo test`/`pnpm`/`cmake` inline in the orchestrator — heavy output stays out of the long-lived session and QA runs in parallel.

## [3.1.9] — 2026-06-09

### Fixed

- **parallel-build**: Guarantee each worktree converges to a verified-complete state, fixing four failure modes seen in production parallel runs. (1) Base divergence — freeze the merge target once (`$TARGET`/`$TARGET_SHA`, never hardcoded `main`) and normalize every story branch onto it on return (`rebase --onto`), so a worktree cut from a divergent base is corrected automatically instead of by hand ("stray commit" archaeology). (2) Silent no-op resume (`0 tool uses · Done`) — continue-in-place is now an auto-continue loop gated on an objective COMPLETE check (all criteria `[x]` + clean tree + QA green), with a work-proof guard that flags a zero-progress round as STUCK and never merges it. (3) Unreliable completion signal — agents end with a parseable `STATUS`/`COMMITS`/`REMAINING` block and self-verify they are in the assigned worktree before working. (4) Lost work — dirty worktrees are WIP-committed before resume/cleanup, and per-phase commits keep an early stop recoverable.

## [3.1.8] — 2026-06-09

### Fixed

- **parallel-build / build**: Parallel sub-agents no longer edit the shared `STORIES_INDEX.md`, `FEATURE_INDEX.md`, or parent `EPIC.md` inside their worktrees — concurrent edits to those files were the cause of merge conflicts on the target branch. `build` now auto-detects its parallel-build worktree and defers all shared-index writes (updating only the per-story file); `parallel-build` reconciles the three indexes once on the target branch after each merge (and per wave, before re-resolving the next wave) as the sole writer, keeping parallel merges conflict-free.

## [3.1.7] — 2026-06-04

### Added

- **subagent-fanout**: New shared dispatch contract (`references/subagent-fanout.md`) plus gated parallel subagent fan-out in five skills — `team` (parallel skill generation, ≥4 skills), `design` (per-feature architecture docs, New-Project ≥4 features), `plan` (read-only domain analysis, ≥4 components), `doc-optimizer` (read-only per-doc measure, ≥8 docs), and `fix` (read-only hypothesis probes, verdict B/D). Subagents never write shared files, prompt the user, or re-run the version gate; the orchestrator owns all interaction, merging, and shared writes, and fan-out is gated so small inputs stay sequential.

## [3.1.6] — 2026-06-04

### Fixed

- **parallel-build**: Single-story _waves_ now dispatch a one-agent worktree run (Phase 3, N=1) instead of short-circuiting to inline `/ck-code:build`. Inline build inside a wave bloated the long-lived orchestrator context across later waves and could land work on a `story/…` branch off the wave target; dispatch keeps the orchestrator lean and on-target. The single-story _batch_ short-circuit (Phase 2.5) is unchanged, and a terminal single-story wave may still inline.

## [3.1.5] — 2026-06-04

### Changed

- **skills**: Deduplicated the version-gate paragraph and its intra-file RULES restatement into a single terse, fast-path-preserving line across the 9 change-producing skills, leaving `references/version-gate.md` as the lone source for the gate logic.
- **design, plan**: Standardized the context7 MCP-vs-CLI phrasing to one terse form.
- **build**: Trimmed the Phase 7 QA checklist that duplicated `qa-validation.md`, and added a skip-fast guard that bypasses the 238-line `skill-detection.md` when a project has no generated skills — both cut per-invocation tokens with no behavior change.

## [3.1.4] — 2026-06-04

### Changed

- **build**: the implementation plan stays in the session (presented at Phase 3.6, tracked on Claude Tasks) and is no longer written into the story file.

## [3.1.3] — 2026-06-04

### Fixed

- **plan**: size every story to a single agent dispatch — removed the Coarse/Balanced/Fine granularity size-adjustment and the L/XL stories it produced, so `parallel-build` sub-agents no longer overflow their tool-call/token budget and stall mid-build (the `◐ incomplete` outcome). Larger work is split at a natural seam and connected with `Blocked by`; the ~8-task rule is now the single-dispatch guardrail.

## [3.1.2] — 2026-06-03

### Fixed

- **fix**: verdict C (NEW-FEATURE) now defers to `/ck-code:design` instead of jumping straight to `/ck-code:plan`, so a fix that turns out to be a new feature enters the normal flow (design → team → plan) and gets architecture docs before story planning.

## [3.1.1] — 2026-06-03

### Changed

- **team**: rebalanced expert vs. guide derivation. Guides now cover **idiomatic libraries** (Tailwind, i18next, PostHog, Firebase/FCM, auth/blockchain SDKs, forms/validation), not just languages, frameworks, and protocols — closing the gap where high-idiom libraries were dropped as "small utilities". Added a **guide-over-expert** rule so single-library or cross-cutting concerns become guides under an existing expert instead of standalone experts (no more `expert-analytics`/`expert-i18n`/`expert-styling`/`expert-api`), curbing expert proliferation at `--max`.

## [3.1.0] — 2026-06-03

### Added

- **convention**: new skill that captures a project's own conventions (code structure, naming, coding style, architectural rules) into a `guide-conventions` skill every expert reads, and can create custom experts/guides or adjust generated ones — covering the house rules `team`'s research-driven generation cannot.
- **team**: depth flags `--basic` / `--standard` / `--max` (default `--standard`) controlling how many skills are generated; new detection-gated specialist experts (`security`, `database`, `performance`, `api`, `mobile`, `data`, `docs`) plus a generic `derived-expert` template for project-specific roles.

### Changed

- **team**: Phase 2 now _derives_ the expert/guide set intelligently from the project context and generates only what the project genuinely needs, instead of matching a fixed catalog. Generated experts/guides carry self-describing `paths`/`keywords` frontmatter.
- **skill-detection** (build/fix/parallel-build): expert/guide loading is now manifest-driven — matched by each skill's `paths`/`keywords` frontmatter so dynamically-named experts auto-load (anchor tables kept as fallback); `guide-conventions` always loads when present.

## [3.0.5] — 2026-06-02

### Added

- **plan**: granularity is now persisted in `ROADMAP.md` (`<!-- Granularity -->` marker) so Continue Mode reuses the prior level instead of re-asking, and Fine plans are handed off to `/ck-code:parallel-build` (NEXT step + Phase 1.5 note) to realize the parallel-build payoff of the finer split.

## [3.0.4] — 2026-06-02

### Added

- **plan**: user-selectable epic/story granularity. New Phase 1.5 recommends a level (Coarse / Balanced / Fine) from spec signals and lets the user confirm or override, instead of always producing fewer, larger stories. Effort (depth) and granularity (count) are now explicitly orthogonal axes.

## [3.0.3] — 2026-06-02

### Changed

- **build, fix**: removed feature-doc write-back (phases 8.6b / 8.3b) — only `design` writes to architecture docs; `build` and `fix` write to the story file only.

## [3.0.2] — 2026-06-01

### Fixed

- **plan, fix, ship, parallel-build**: corrected shared-reference links that pointed one directory level too high (`../../../references/` → `../../references/`) — the same bug fixed for `build` in 3.0.1, which had silently broken every "follow the full procedure in …" link and forced a runtime filesystem search.

## [3.0.1] — 2026-06-01

### Changed

- **build**: cut per-run token cost — added a read-once rule for multiply-cited references, split `examples.md` into a compact `output-blocks.md` (happy-path templates) plus conditional worked dialogues, moved Phase 8.6b detail into `completion.md`, and de-duplicated phase prose (SKILL.md 413 → 363 lines, examples.md 226 → 98).

### Fixed

- **build**: corrected 8 shared-reference links that pointed one directory level too high (`../../../references/` → `../../references/`), which had silently broken every "follow the full procedure in …" link.

## [3.0.0] — 2026-06-01

### Removed

- **BREAKING — pre-v3 layout support**: every skill now reads only the v3 architecture-doc layout. Dropped all backward-compat for the legacy flat `features/<slug>.md`, the retired layer docs (`components.md`, `api-contracts.md`, `database-schema.md`, `data-flow.md`), and the `v1` `FEATURE_INDEX` — across `build`, `fix`, `plan`, `pre-spec`, `team`, `design` (+ templates), and the `feature-index`, `skill-detection`, `qa-validation` references. Inline `v1 → v2` index upgrades are gone; that conversion now happens only in `doc-optimizer upgrade`.

### Added

- **version gate** (`references/version-gate.md`): a hard, blocking pre-flight check in every change-producing skill (`design`, `plan`, `pre-spec`, `quick-story`, `build`, `parallel-build`, `fix`, `sync`, `ship`, `to-issues`, `team`); read-only skills (`explain`, `help`, `start`, `track`) hint only. It keys on a new `tasks/VERSION.md` stamp (`layout: v3`) for a one-read fast path, falling back to a filesystem scan only when the stamp is missing/stale. On a pre-v3 project it blocks and offers `/ck-code:doc-optimizer upgrade`.
- **doc-optimizer `upgrade` mode**: one-shot, idempotent pre-v3 → v3 converter — chains `migrate` + `sync` + the `FEATURE_INDEX` `v1 → v2` rewrite, scaffolds `DESIGN_LEDGER.md`, and stamps `tasks/VERSION.md` as its final step.
- **`DESIGN_LEDGER.md`** (`docs/architecture/`): a design → plan bridge. `design` appends a `pending` row + a dated design record (`features/<slug>/YYYY-MM-DD_design_<short>.md`) per added/changed feature; `plan` reads the `pending` rows as its work-to-plan list and flips them to `planned` with a plan ref. Build status stays in `FEATURE_INDEX`.

### Changed

- **design**: writes per-feature design records and `DESIGN_LEDGER.md` rows (Phase 3.11); runs the version gate first.
- **plan**: reads `DESIGN_LEDGER.md` to find unplanned design work (Phase 1.1c) and flips planned rows to `planned` (Phase 4.5c); the `FEATURE_INDEX` is always schema v2 (the gate guarantees it).

## [2.3.0] — 2026-06-01

### Changed

- **design, doc-optimizer**: architecture feature docs move to a subfolder-per-feature layout — the canonical doc is now `docs/architecture/features/<slug>/index.md`, and each `build` increment or `fix` is journaled as a dated sibling `features/<slug>/YYYY-MM-DD_<id>_<short>.md`. `index.md` stays the routed source of truth; the dated docs are an append-only history and are not auto-read.
- **build, fix**: on a change that touches the documented surface, update `index.md` and also write the dated delta doc (change narrative); legacy flat docs are updated in place.
- **feature-index, skill-detection, qa-validation, plan, pre-spec, team**: route to `features/<slug>/index.md` while still reading the legacy flat `features/<slug>.md` as-is — no project breaks.

### Added

- **doc-optimizer** (`sync`): migrates legacy flat `features/<slug>.md` into `features/<slug>/index.md`, fixes relative links, and sweeps loose dated delta docs into their parent feature folder.

## [2.2.1] — 2026-06-01

### Added

- **to-issues**: granularity modes via `--mode feature|epics|stories` — publish one issue for the whole feature, one issue per epic, or the full epic+story hierarchy; falls back to an interactive prompt when the flag is omitted.

## [2.2.0] — 2026-06-01

### Added

- **doc-optimizer**: new skill to keep `docs/architecture/` cheap to read — `migrate` decomposes legacy layer docs into per-feature docs + `_shared.md`, `sync` scaffolds docs for features missing one, and `optimize` (default) prunes/dedupes and reports per-feature token counts.

### Changed

- **design**: architecture docs are now **feature-scoped** — one self-contained `docs/architecture/features/<slug>.md` per feature (its components, API, data, flows) plus a single `_shared.md` for cross-cutting infra. The `components.md`, `api-contracts.md`, `database-schema.md`, and `data-flow.md` layer docs are no longer generated.
- **feature-index**: schema v2 adds a `Docs` column routing each feature to its doc; v1 indexes are upgraded in place with a graceful fallback.
- **build, fix**: read only the story's feature doc (+ `folder-structure.md`, + `_shared.md` when cross-cutting) instead of every layer doc, and append a lightweight write-back delta to the feature doc on completion.
- **plan, team, pre-spec**: read the global docs + feature index/summaries rather than the full architecture, opening a single feature doc only when directly relevant.

## [2.1.0] — 2026-06-01

### Added

- **feature-index**: New top-level `tasks/FEATURE_INDEX.md` (one row per epic, with description and rolled-up status) that `build` and `parallel-build` read before any story index — when more than two features are unfinished the user picks which feature to build, scoping the run to that epic. `plan` creates/extends the index, `build`/`parallel-build` roll a feature up to `DONE` when its last story completes, and `fix` bumps the rollup when adding stub stories. Shared spec in `references/feature-index.md`.

## [2.0.6] — 2026-06-01

### Added

- **plan**: each story now carries an ordered `## Implementation Tasks` checklist (Phase 2.2c) so large, consolidated stories stay precise without splitting them into more, smaller stories.

### Changed

- **build**: Phase 3.4 seeds its subtask board from the story's `## Implementation Tasks` when present, and falls back to the default breakdown unchanged when the section is absent.

## [2.0.5] — 2026-05-29

### Fixed

- **plugin**: removed the redundant `"hooks": "./hooks/hooks.json"` key from the manifest — the standard `hooks/hooks.json` is loaded automatically, so declaring it again triggered a "Duplicate hooks file detected" load error at startup. Also bumped the `ck-tools` marketplace ref to `v2.0.1` (same fix).

## [2.0.4] — 2026-05-29

### Fixed

- **parallel-build**: Recover sub-agents that stop early (e.g. XL stories exhausting their dispatch budget) by continuing the work in their existing worktree, since dispatched agents cannot be resumed in this harness (no `SendMessage`). Adds a third ◐ incomplete outcome distinct from failed (Phase 3.4 / 3.5), a Phase 6 "Continue in place" option separate from fresh re-dispatch, and a Continue-Incomplete sub-agent prompt that finishes only the remaining criteria instead of restarting and re-hitting the same budget wall.

## [2.0.3] — 2026-05-29

### Changed

- **parallel-build**: Scope wave mode to a single epic instead of a whole feature, and add a dynamic Wave Depth Guard. A feature with several epics is now built one epic per run (no feature-wide wave chains, no auto-chaining into the next epic), and the recommended wave ceiling scales with the epic's story count — when the natural dependency depth exceeds it, the operator gets a WARN + `PROCEED / SPLIT` confirmation, preventing long, token-heavy wave runs.

## [2.0.2] — 2026-05-29

### Changed

- **parallel-build**: Select each sub-agent's model by reasoning complexity instead of story `Size`. After the plan consolidation made L the default size, the old Size→model mapping sent nearly every story to Opus; now stories default to Sonnet (`balanced`) and escalate to Opus (`advanced`) only on a clear high-reasoning signal, cutting cost without losing quality on hard work.

## [2.0.1] — 2026-05-29

### Changed

- **plan**: Consolidate the planning output — minimize epics, target L-sized stories by default, add a consolidation pass that merges related/sequential/S stories, and make effort scaling add depth per story instead of more stories. Fewer, larger stories mean fewer downstream `build` sessions and lower token cost.

## [2.0.0] — 2026-05-29

### Added

- **hooks**: new `SessionStart` hook reloads skills so experts/guides generated by `/ck-code:team` become invocable without a restart, and injects a one-line `STORIES_INDEX.md` progress summary into context; new `PostToolUse(Write|Edit)` hook best-effort auto-formats touched files (prettier/rustfmt/ruff/black/gofmt/shfmt, no-op when the formatter is absent). Both are `command`-type — zero model-token cost.
- **subagentStatusLine**: ships a default subagent status row for `/ck-code:parallel-build` worktree implementers (status glyph · label · token count) via plugin `settings.json`.
- **native-commands** (new `references/native-commands.md`): maps Claude Code built-ins to ck-code phases — `/goal` for autonomous QA/manual-test loops (cheap verifier model), `/code-review --fix` pre-PR, and an intelligent `/fast` decision table (on for size-`S` stories, off for `L`/`XL`). Linked from `build`, `fix`, and `ship`.

### Changed

- **token efficiency**: added `effort:` to every skill (`low` for `explain`/`help`/`start`/`track`/`sync`, `high` for `design`/`plan`/`pre-spec`/`team`); added `disallowed-tools: Write, Edit, NotebookEdit` to the read-only skills (`explain`/`help`/`start`/`track`); `start` now pre-loads its project-state probes via dynamic context injection, saving ~5 tool round-trips per run. All additive — no interactive gate or existing behavior removed.

## [1.9.14] — 2026-05-29

### Changed

- **plugin.json**: added `$schema`, `displayName`, `homepage`, `repository`, and `keywords` metadata so the plugin presents richer info in the `/plugin` marketplace UI and validates under `claude plugin validate --strict` (additive only, no behavior change).

## [1.9.13] — 2026-05-22

### Fixed

- **build**: Phase 2 (expert/guide skill detection & loading) is now a hard blocking gate — it was a single delegating paragraph absent from the HARD GATES checklist, so it could be skipped, leaving the "follow loaded guide/expert skills" rules in Phases 5/6 as silent no-ops. It is now in HARD GATES, reframed as mandatory before any planning or code, and a Phase 5.1 guard re-runs it if the "Skills loaded" block was never shown. Ensures the necessary experts and guides are always loaded during implementation.

## [1.9.12] — 2026-05-22

### Fixed

- **build**: skill detection no longer skips the mandatory `ls` filesystem check when a project's CLAUDE.md says `/ck-code:team` generation is "deferred" — such prose notes go stale once skills are generated, so the `ls` output is now authoritative and runs first, before any doc note is read. Fixes generated `experts/` and `guides/` skills being reported as absent when they exist on disk.

## [1.9.11] — 2026-05-22

### Changed

- **build**: interactive selection (no story arg) now prefers parallel by default — when ≥ 2 ready stories are conflict-free, the parallel set is the recommended option and choosing it is a single confirm that auto-fans-out one worktree agent per story via `parallel-build` (no second prompt). An explicit story arg is always built as a single story, never auto-expanded. Phase 1.4 is reduced to an explicit-path-only epic-wave offer.
- **parallel-build**: the launch announcement is now informational and dispatches immediately (no "press enter to start" gate) and prints a per-agent → story → worktree mapping, so the main session shows which agent is implementing each story.

## [1.9.10] — 2026-05-22

### Changed

- **build**: the Phase 1.2 interactive story-selection menu now lists whole-epic wave options ("Build all of Epic NN in dependency-ordered waves") alongside the single stories, so the operator is offered the epic build at selection time — not only after a single story is already chosen. Picking an epic hands off to `parallel-build --epic NN`; the Phase 1.4 offer no longer re-asks the same epic.

## [1.9.9] — 2026-05-22

### Changed

- **build**: epic-build detection now runs first and unconditionally in Phase 1.4 — a purely sequential epic (no parallel-safe peer) now gets the `--epic NN` dependency-ordered wave offer, which the previous parallel-safe gate skipped.
- **parallel-build**: whole-epic wave mode is now surfaced as an explicit "implement whole epic NN in waves" option in interactive selection (Phase 1.5 / 2.2) instead of a buried `epic NN` parse string.

## [1.9.8] — 2026-05-22

### Changed

- **build**: token-efficiency refactor — offloaded Phase 8 completion mechanics into `references/completion.md`, the Phase 1.4 parallel-switch procedure into `references/parallel-switch.md`, and the JUCE test-runner rules into `references/tdd-walkthrough.md`; trimmed Phase 2 and Phase 7 to pointers. SKILL.md cut from 414 to 348 lines with all gates kept inline and no behavior change.

## [1.9.7] — 2026-05-22

### Changed

- **parallel-build**: offloaded the bash-level mechanics for Phases 3.1/3.5/4/6/7 (model resolution, integrity checks, conflict analysis, merge, cleanup) into `references/pipeline.md`, keeping the gates and decisions inline — SKILL.md trimmed from 453 to 323 lines with no behavior change.

## [1.9.6] — 2026-05-22

### Added

- **parallel-build**: `--epic NN` wave mode — implements a whole epic in dependency-ordered waves (e.g. `[01-01, 01-02]` → `[01-03]` → `[01-04]`), running the dispatch→QA→manual-test→merge pipeline once per wave and merging each wave before the next so dependents see their blockers `DONE`; confirms each wave, tracks one Claude Task per story grouped by wave, and holds stories whose blocker ends up blocked-from-merge (see `references/wave-mode.md`).

### Changed

- **build**: Phase 1.4 escalation now also offers `parallel-build --epic NN` when the selected story's epic needs more than one dependency wave.

## [1.9.5] — 2026-05-22

### Changed

- **build / parallel-build**: made the two skills switchable around Claude Tasks — `build` Phase 1.4 offers escalating to `parallel-build` when independent, non-overlapping ready stories exist, `parallel-build` recommends the conflict-free parallel-safe set (Phase 1.4) and tracks one Claude Task per dispatched story (Phase 3.2.5); both now state Task usage explicitly with graceful fallbacks.

## [1.9.4] — 2026-05-22

### Added

- **build**: skill detection now reports the loaded expert/guide skills to the user before implementation begins (shared `skill-detection.md` Step 5 — also applies to `fix` and `parallel-build`), so skill loading is never silent.

## [1.9.3] — 2026-05-22

### Added

- **design, plan**: effort-aware behavior via `${CLAUDE_EFFORT}` — `design` scales Q&A rounds and doc depth, `plan` scales story granularity, to the active effort level (low → minimal/coarse, high/xhigh/max → exhaustive/fine-grained).
- **team**: generated language/framework guides now emit a `paths` frontmatter field so they auto-load deterministically whenever Claude touches a matching source file, not only on description match.

### Changed

- **marketplace**: added a top-level `description` to `marketplace.json` (clears the validation warning) and bumped the ck-tools ref to v1.0.5.

## [1.9.2] — 2026-05-17

### Fixed

- **build**: removed `disable-model-invocation: true` from frontmatter — the flag blocked story-implementer agents and the parallel-build Phase 2.5 short-circuit from invoking the skill via the Skill tool; no actual recursion risk exists.
- **story-implementer**: added `Skill` to the agent tools list so it can call `Skill({ skill: "ck-code:build" })`; simplified workflow to make clear the agent's only action is to invoke the build skill; tightened constraints to forbid direct implementation.
- **parallel-build (agent-prompts)**: updated Per-Story Agent Call template to prefer `ck-code:story-implementer` as subagent_type instead of `general-purpose`.

## [1.9.1] — 2026-05-15

### Changed

- **skill-detection (used by build, parallel-build, fix)**: skill loading is now strictly scoped to the two ck-code-generated namespaces — `.claude/skills/experts/<role>/SKILL.md` and `.claude/skills/guides/<tech>/SKILL.md`. The `Skill` tool is no longer used inside the procedure (it resolved against the global plugin registry and could load unrelated plugin-namespaced skills like `superpowers:*` on a name collision). All loads now go through `Read` against absolute project paths, batched in a single parallel tool-call message after the filesystem check. The "always-loaded" rule for `experts/qa` and `experts/analyst` is now gated on filesystem presence — a missing file is reported as missing, never silently assumed.

## [1.9.0] — 2026-05-15

### Changed

- **build, fix**: independent reads now prescribed as parallel batched tool-call messages instead of sequential reads. Removes ~8–14s of avoidable latency per build/fix invocation. Affected sites: `build` Phase 1.3 (story + parent EPIC.md), `build` Phase 1.4 (two `gh issue list` queries), `build` Phase 2 / `fix` Phase 3.1 (architecture-doc reads and skill loads via `skill-detection.md` Step 1 and Step 4b), `fix` Phase 1.3 (two-batch sequence: story+EPIC, then arch docs after parsing). Phase ordering, gates, agent dispatch, and acceptance criteria untouched.
- **fix**: Verdict A (single-story bug, no stubs, no sync work) now uses a single combined confirmation prompt — Phase 2.5.5 is skipped when the story set adds no information beyond the verdict itself. One fewer user gate on single-story fixes. Verdicts B and D continue to use both gates separately because the story set adds real information (stubs to create, EPIC.md files to sync).

### Added

- **parallel-build**: new Phase 2.5 short-circuit — when the selected story set has exactly one story (Phase 1.2 resolution, Phase 2 selection, or `$ARGUMENTS`), the skill now delegates directly to `/ck-code:build` via the Skill tool, skipping worktree creation, sub-agent dispatch, conflict analysis, and per-story cleanup. Parallel orchestration overhead is only paid when there are ≥ 2 stories to run concurrently.

## [1.8.2] — 2026-05-15

### Changed

- **fix, quick-story, sync, start**: tightened skill descriptions to trigger-only phrasing (≤292 chars), removing workflow summaries that bloated every plugin-list context. No behaviour change.
- **build, fix**: replaced trailing `## IMPORTANT GUIDELINES` / `## RULES` blocks with concise `## HARD GATES` pointers that reference the phase numbers where each gate is enforced — drops ~12 lines of duplicate rule text per skill while keeping cross-cutting invariants (scope discipline, minimal-fix rule, index purity, language) explicit.
- **fix/references/qa-dialogue.md**: compressed from 349 → 280 lines (~26% character reduction) by removing prose duplications of `SKILL.md` instructions; every Phase NN template block is preserved verbatim.
- **build/references/examples.md**: compressed from 266 → 200 lines (~27% character reduction) by consolidating the near-identical RED/GREEN/REFACTOR phase-complete blocks into one parameterised template and tightening the bug-fix sub-loop worked example.
- **qa-validator agent**: added explicit `Never commit or push` constraint to match the safety boundary already in `story-implementer` and `conflict-analyzer`.

## [1.8.1] — 2026-05-15

### Changed

- **build**: new Phase 3.7 (Branch Strategy) — after plan confirmation and before any test or implementation file is touched, asks the user to either create a `story/<EE>-<SS>-<slug>` (or `fix/...`) branch or stay on the current branch. Protected branches (`main`, `develop`) force the new-branch path.
- **parallel-build**: Phase 6 Option 1 merge target now resolves to the orchestrator's current branch (`git branch --show-current` in the main checkout) instead of hardcoded `main`. Detached HEAD stops the flow. Lets operators roll all parallel stories into a feature branch they're already iterating on.
- **ship**: Phase 0.2 now detects any open PR on the current branch via `gh pr list --head`. Phase 4 routes accordingly — when a PR exists, 4.A pushes to the current branch and appends a dated entry to the PR body's `## Updates` section via `gh pr edit` (preserving the original body and prior entries); otherwise 4.B runs the original create-PR flow. Phase 5.1 distinguishes between newly-created and updated PRs when commenting on the linked issue.

## [1.8.0] — 2026-05-08

### Added

- **quick-story**: new `/ck-code:quick-story` skill — scaffolds a single small story inside an existing tasks plan when a full `/ck-code:plan` cycle is overkill (e.g., adding a database column or tweaking a config). Generates the story file plus matching `STORIES_INDEX.md` row and `EPIC.md` story-table row in `TODO` state, ready for `/ck-code:build`. Requires an existing epic — redirects to `/ck-code:plan` otherwise. AI-drafts title/description/acceptance criteria; user confirms via `CONFIRM | EDIT | ABORT` before any write. Phase 5 suggests next steps but never auto-launches `build` or `to-issues`.

## [1.7.4] — 2026-05-07

### Added

- `CHANGELOG.md` — full release history in Keep a Changelog format, from v1.0.0 to present.

## [1.7.3] — 2026-05-07

### Changed

- **build**: Phase 8.5 enforces a strict bug-fix sub-loop on `ISSUES` — regression test → fix → mandatory Phase 6 (Refactor) + Phase 7 (QA) → re-prompt. New `## Manual-Test Bugs` story-file section provides an audit trail. Cap = 3 cycles, escalation `FIX MANUALLY / ACCEPT AS-IS / ABORT`.
- **parallel-build**: new Phase 5.5 runs per-story manual testing at the orchestrator level. On `ISSUES`, dispatches a bug-fix sub-agent into the existing worktree. Stories without `MANUAL-TEST PASS` are not merge-eligible.
- **fix**: Phase 6.4 Refactor changes from "optional, deliberate" to **required** (bounded SOLID verification on changed lines — minimal-fix rule still binds). Phase 8.6 becomes a strict three-branch loop (`PASS / STILL BROKEN / NEW ISSUE`) where every `STILL BROKEN` cycle re-runs Phase 4.2 → Phase 6 → Phase 6.4 → Phase 7 before re-prompting. Cap = 3 cycles per Bug ID.

## [1.7.2] — 2026-05-06

### Added

- **fix**: defer the fix when a future TODO story already plans it. Phase 2.5 now scores TODO rows in addition to DONE/IN PROGRESS; if a TODO story matches (≥ 0.7), verdict E (PLANNED-IN-FUTURE) stops the flow and recommends `/ck-code:build <future-story-path>`. User can override with `PROCEED ANYWAY`.

## [1.7.1] — 2026-05-06

### Added

- **build, fix**: `## Unplanned Changes` story-file section — any code change outside the planned files list must be logged at the moment it happens (`- <path> — <what> — <why>`). Implementation Summary and Resolution blocks record an unplanned-changes count.

## [1.7.0] — 2026-05-06

### Added

- **fix**: Phase 2.5 scope analyzer that auto-matches the best story (or stories) for a bug. Verdicts: `SINGLE-STORY`, `MULTI-STORY`, `NEW-FEATURE` (defers to `/ck-code:plan`), `MIXED` (creates stub stories in the right epic). Multi-story bugs share a `Bug ID` across every touched story and the parent epic + `STORIES_INDEX.md` are kept in sync. Three mandatory user-confirmation gates before any write.
- **sync**: new skill — reconciles `STORIES_INDEX.md`, each `EPIC.md` story list, and story files when they drift apart. Read-only diff first; story files are the source of truth.

## [1.6.1] — 2026-05-06

### Changed

- **ship**: rewrites commit & PR templates for stakeholder readability — drops story IDs, epic names, AC checkbox lists, and test-count tallies from commit bodies, PR bodies, and GitHub issue comments. Subject lines stay in conventional-commit format.

## [1.6.0] — 2026-05-05

### Changed

- **publish → to-issues**: renamed `/ck-code:publish` to `/ck-code:to-issues` to make the direction explicit (`tasks/` → GitHub Issues) and to pair symmetrically with `ck-tools:gh-issue`. All cross-references in README and skill files updated.

### Breaking

- Users who scripted `/ck-code:publish` must update to `/ck-code:to-issues`. Phases, frontmatter behaviour, and output are unchanged.

## [1.5.2] — 2026-05-04

### Fixed

- **parallel-build**: enforce index-first discovery in Phase 1 — "FIRST ACTION" imperative opens the section before any glob, "Do NOT glob" prohibition moved above the bootstrap check, new RULES entry explicitly forbids reading individual story files unless bootstrap is triggered.

## [1.5.1] — 2026-05-04

### Fixed

- **parallel-build**: removed double story-file read in dispatch prompt.
- **parallel-build**: Phase 3.5.1 now reads story status from each agent's worktree path instead of the main checkout.
- **build**: reordered Phase 8 so the manual testing gate (8.5) runs before the DONE status update (8.6).

## [1.5.0] — 2026-05-04

### Added

- **start**: new `/ck-code:start` read-only orchestrator — inspects project state (specs, architecture, generated skills, tasks/, story statuses, GitHub issues) and recommends the next workflow step. Recommends only — never auto-launches.
- **workflow-map**: single source-of-truth reference covering the workflow graph, hand-off rules, output locations, and a "when to use which" decision tree.
- **NEXT hand-off blocks**: every workflow skill now ends with an explicit `## NEXT` block naming the recommended follow-up skill.

### Changed

- **skill-detection**: shared reference at `references/skill-detection.md`, used by build + fix. Cuts ~100 lines of duplicated detection logic.
- **qa-validation**: shared reference at `references/qa-validation.md`, used by build (Phase 7) + fix (Phase 7). Cuts ~80 lines of duplicated QA loop boilerplate.
- **no-ai-references**: shared reference at `references/no-ai-references.md`, cited by ship.
- **build/SKILL.md**: 424 → 335 lines (under the 350-line house limit).
- **help/SKILL.md**: workflow grid offloaded to `workflow-map.md`; gains an inline "When to Use Which" decision tree.

## [1.4.0] — 2026-05-04

### Added

- **stories-index**: new `tasks/<slug>/STORIES_INDEX.md` — single project-level summary of every story's status, size, and dependencies. `build`, `parallel-build`, and `track` now read this one file to find ready stories instead of globbing every story file. `plan` generates the index after writing stories.

### Changed

- **build**: architecture-doc reading is now scoped to the paths each story actually touches.
- **all skills + agents**: descriptions trimmed to single trigger sentences ("Use to/when…"), 122–191 chars.

## [1.3.0] — 2026-04-30

Internal version bump. No feature changes.

## [1.2.6] — 2026-05-04

### Fixed

- **team**: add auto-detection of missing skills and `--check` flag — on subsequent runs, compares current tech stack against existing generated skills, reports missing/extra, and generates only what's needed.

## [1.2.5] — 2026-04-30

### Added

- **parallel-build**: Phase 3.5 — Story File & Code Integrity Verification after all parallel agents complete. Checks story file updated to `Status: DONE`, detects empty diffs, flags unexpected file deletions and pure-deletion files. Issues escalated to warnings (proceed, flagged) or BLOCKED (removed from merge-eligible set, worktree kept for fix).

## [1.2.4] — 2026-04-29

### Fixed

- **ship**: set `disable-model-invocation: false` so `/ck-code:ship` can be invoked via the Skill tool from a conversation, not only as a direct slash command.

## [1.2.3] — 2026-04-29

### Changed

- Marketplace: bumps ck-tools plugin entry in `ck-marketplace` from v0.1.0 to v0.1.1.

## [1.2.2] — 2026-04-29

### Added

- Marketplace: `ck-marketplace` now lists `ck-tools` as a second plugin (pinned to v0.1.0). Users with the marketplace already added can run `/plugin marketplace update ck-marketplace` then `/plugin install ck-tools@ck-marketplace`.

## [1.2.1] — 2026-04-29

### Changed

- **pre-spec**: token optimization — `SKILL.md` 494 → 212 lines (−50% always-loaded). Templates and GitHub publishing procedure moved to `references/templates.md`. No behavior change.

## [1.2.0] — 2026-04-29

### Added

- **pre-spec**: new `/ck-code:pre-spec` skill — generates a stakeholder-ready feature specification before any architecture work. Two auto-detected modes: `CREATE` (capture intent, read project context, run Q&A rounds, generate spec) and `ADJUST` (apply targeted edits to an existing spec, re-sync linked GitHub issue). Per-feature folder at `docs/specs/YYYY-MM-DD_<slug>/`. Supports multi-language output and GitHub publishing.

## [1.1.1] — 2026-04-28

### Fixed

- **parallel-build**: Phase 1.1 _Parse Story Files_ now carries a zsh shell-pitfalls note listing reserved names (`status`, `path`, `cdpath`, `manpath`, `prompt`) to avoid on assignment, preventing a first-run failure in zsh.

## [1.1.0] — 2026-04-28

### Added

- **team, design, plan, build**: `ctx7` CLI (`npx -y @upstash/context7`) added as fallback when context7 MCP is unavailable. Resolution order: MCP tools → `ctx7` CLI → WebSearch.

## [1.0.0] — 2026-04-28

### Added

- 11 skills with trigger-based descriptions: `design`, `plan`, `team`, `track`, `publish`, `build`, `parallel-build`, `fix`, `ship`, `explain`, `help`.
- Token-efficient skill bodies — bulky templates and examples live in per-skill `references/` subfolders (53% reduction in always-loaded skill content).
- Capability-tier model selection — `parallel-build` picks `fast` / `balanced` / `advanced` / `advanced-extended-context` tiers per story size.
- Dedicated subagents: `qa-validator`, `conflict-analyzer`, `story-implementer`.
- TDD enforcement — red/green/refactor cycle; no production code without a failing test first.
- SOLID checks — applied at design time and verified at QA time.
- Auto-generated expert team — `/ck-code:team` reads architecture and generates per-project expert and language-guide skills, refreshed via context7.
- GitHub Issues integration — `/ck-code:publish` and `/ck-code:ship` keep stories, branches, commits, PRs, and Issues linked end-to-end.
- Parallel multi-story builds — fan out unblocked stories across git worktrees with conflict analysis before merge.
