# Changelog

All notable changes to ck-code are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- **parallel-build**: Phase 1.1 *Parse Story Files* now carries a zsh shell-pitfalls note listing reserved names (`status`, `path`, `cdpath`, `manpath`, `prompt`) to avoid on assignment, preventing a first-run failure in zsh.

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
