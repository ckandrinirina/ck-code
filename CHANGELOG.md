# Changelog

All notable changes to ck-code are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
