# ck-code — Spec-Driven Workflow Plugin for Claude Code

> Turn a project specification into architecture docs, an implementation plan, and a TDD-driven build/ship loop — all from inside [Claude Code](https://www.anthropic.com/claude-code).

**ck-code** is an open-source [Claude Code plugin](https://www.anthropic.com/claude-code) that brings spec-driven development to AI-assisted software engineering. Feed it a project specification and it will:

1. **Design** — refine your spec into a complete set of architecture documents (folder structure, components, APIs, database schema, tech stack)
2. **Plan** — break the architecture into epics and stories with sizes (S/M/L/XL) and explicit dependencies
3. **Team** — generate a project-tailored team of expert and language-guide skills (frontend, backend, QA, DevOps, plus per-language guides for Rust, TypeScript, Python, React Native, etc.)
4. **Build** — implement each story using test-driven development (TDD), SOLID principles, and a built-in dev-QA validation loop
5. **Ship** — commit with conventional commits, open a pull request, and auto-update linked GitHub Issues

Whether you're building a new project from scratch or adding a feature to an existing codebase, ck-code keeps the architecture, plan, and implementation in lock-step — so AI-generated code stays grounded in your real design.

## Features

- **Spec-driven development workflow** — single source of truth from specification to merged PR
- **Automatic architecture documentation** — split markdown docs in `docs/architecture/` (overview, folder structure, tech stack, components, data flow, API contracts, database schema, configuration, dev guide)
- **Epic and story planning** — sized stories with dependency graphs in `tasks/`
- **GitHub Issues integration** — push your epics and stories to GitHub Issues with size labels and parent/child links
- **Test-Driven Development (TDD) enforcement** — red/green/refactor cycle, no production code without a failing test first
- **SOLID principle checks** — every implementation is reviewed against single-responsibility, open/closed, Liskov, interface segregation, and dependency inversion
- **Project-tailored expert skills** — auto-generated per-project experts and language guides, refreshed via [context7](https://context7.com) for up-to-date best practices
- **Parallel multi-story builds** — implement multiple unblocked stories at once in isolated git worktrees with conflict analysis before merge
- **Automatic story-to-PR linking** — branches, commits, PRs, and Issues stay connected end-to-end
- **Capability-tier model selection** — agents pick the right Claude tier (fast / balanced / advanced) per story size, no hardcoded model IDs
- **Native Claude Code integration** — `SessionStart`/`PostToolUse` hooks (auto-reload generated experts, inject project status, auto-format edits), a subagent status line for parallel builds, and built-in `/goal`, `/code-review`, and `/fast` pairings documented in `references/native-commands.md`
- **Token-lean by default** — per-skill `effort` tuning, read-only tool hardening, and dynamic context injection cut tokens and round-trips. `/fast` (`/fast` or `"fastMode": true`) is recommended for small stories and kept off for `L`/`XL` work — toggled by you, since a plugin cannot set it

## Install

```bash
# 1) Add this marketplace inside Claude Code
/plugin marketplace add ckandrinirina/ck-code

# 2) Install the ck-code plugin
/plugin install ck-code@ck-marketplace
```

That's it — restart your Claude Code session and the `/ck-code:*` commands are available.

## Update

To update the plugin to the latest version:

```bash
/plugin update ck-code@ck-marketplace
```

Then restart your Claude Code session for the updated commands to take effect.

> **Note:** If the update command is not available in your Claude Code version, you can reinstall manually:
>
> ```bash
> /plugin uninstall ck-code@ck-marketplace
> /plugin install ck-code@ck-marketplace
> ```

## Per-project opt-in

Installation alone does not activate the plugin in every project. Enable it explicitly per project by adding to that project's `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "ck-code@ck-marketplace": true
  }
}
```

Without this entry the plugin stays dormant in that project — no slash commands, no auto-loaded behaviour. This keeps unrelated repositories free of the workflow.

## Quick start — first-time setup in a new project

```bash
/ck-code:design   docs/specifications.md   # 1. Generate architecture docs
/ck-code:team                              # 2. Create project-tailored experts + guides
/ck-code:plan     docs/specifications.md   # 3. Generate epics and stories
/ck-code:to-issues                           # 4. (Optional) push to GitHub Issues
/ck-code:track    next                     # 5. Find the first story to implement
/ck-code:build                             # 6. Start building (TDD + QA)
/ck-code:ship                              # 7. Commit, PR, close Issue
```

After `/ck-code:team` runs, your project's `.claude/skills/` will contain:

- `experts/{frontend,backend,qa,analyst,devops,qa-project}/SKILL.md` — invoked as `/expert-frontend`, `/expert-backend`, etc.
- `guides/{rust,axum,react-native,...}/SKILL.md` — auto-loaded by Claude when relevant files are touched.

These generated skills are project-level (not plugin-namespaced) and are intentionally tailored to the architecture you fed into `/ck-code:design`.

## The full workflow

```
/ck-code:pre-spec  →  /ck-code:design  →  /ck-code:team  →  /ck-code:plan  →  /ck-code:to-issues  →  /ck-code:track
   (optional)                                                                                          ↓
                                                                                            /ck-code:build  →  /ck-code:ship
                                                                                                       ↑
                                                                                            /ck-code:fix  ──┘
```

| Skill                     | Purpose                                                                                                                                                                                                                                                                          | Input                                       | Output                                                          |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- | --------------------------------------------------------------- |
| `/ck-code:pre-spec`       | Generate a stakeholder-ready feature spec for review (descriptive, no code/jargon)                                                                                                                                                                                               | feature description or notes file           | `docs/pre-specs/` and/or GitHub issue                           |
| `/ck-code:design`         | Refine a spec into feature-scoped architecture docs (one self-contained doc per feature + `_shared.md`)                                                                                                                                                                          | spec file                                   | `docs/architecture/`                                            |
| `/ck-code:doc-optimizer`  | One-shot `upgrade` migrates a pre-v3 project to the v3 layout (layer docs → per-feature docs, flat docs → `features/<slug>/index.md`, index → v2, scaffold `DESIGN_LEDGER.md`, stamp `tasks/VERSION.md`); also `migrate` / `sync` / `optimize` for ongoing upkeep and token diet | `upgrade` / `migrate` / `sync` / `optimize` | v3 `docs/architecture/` + `FEATURE_INDEX` `Docs` + `VERSION.md` |
| `/ck-code:team`           | Generate per-project expert + guide skills                                                                                                                                                                                                                                       | `docs/architecture/`                        | `.claude/skills/experts/`, `.claude/skills/guides/`             |
| `/ck-code:plan`           | Create epics, stories, roadmap at a chosen granularity (Coarse / Balanced / Fine — recommended from the spec, user confirms)                                                                                                                                                     | spec file                                   | `tasks/YYYY-MM-DD_<project>/` + `tasks/FEATURE_INDEX.md` rows   |
| `/ck-code:quick-story`    | Add a single small story to an existing epic without the full `plan` cycle (e.g. add a DB column, tweak a config)                                                                                                                                                                | one-line brief + epic                       | story file + `STORIES_INDEX.md` row + `EPIC.md` row             |
| `/ck-code:to-issues`      | Push a plan to GitHub Issues at a chosen granularity: one feature issue, one per epic, or the full epic+story hierarchy (`--mode feature\|epics\|stories`)                                                                                                                       | tasks folder                                | GitHub Issues                                                   |
| `/ck-code:track`          | Progress dashboard                                                                                                                                                                                                                                                               | —                                           | status, next story, completion %                                |
| `/ck-code:build`          | Implement a story (TDD + QA); interactive runs read `tasks/FEATURE_INDEX.md` first and ask which feature to build when more than two are unfinished                                                                                                                              | story file                                  | source code + tests                                             |
| `/ck-code:parallel-build` | Implement multiple ready stories in parallel worktrees, or a whole epic in dependency-ordered waves (`--epic NN`); picks a feature from `tasks/FEATURE_INDEX.md` first when more than two are unfinished                                                                         | — / story IDs / `--epic NN`                 | parallel results + conflict report                              |
| `/ck-code:fix`            | Diagnose and fix a bug across one or more stories — auto-matches the best story, defers the fix when a future TODO story already plans it, can create stub stories in the right epic when functionality is missing, keeps index/epic in sync                                     | story file (optional)                       | minimal fix + regression test + (optional) new stub stories     |
| `/ck-code:sync`           | Reconcile `STORIES_INDEX.md`, `EPIC.md` story lists, and story files when they drift apart                                                                                                                                                                                       | tasks plan path or `--all`                  | repaired index + epic lists                                     |
| `/ck-code:ship`           | Commit, PR, update GitHub Issues                                                                                                                                                                                                                                                 | story file (optional)                       | commit + PR + issue updates                                     |
| `/ck-code:explain`        | Explain what was just implemented                                                                                                                                                                                                                                                | —                                           | walkthrough + verification steps                                |
| `/ck-code:help`           | Quick reference for all commands                                                                                                                                                                                                                                                 | —                                           | this table                                                      |

## Why ck-code?

If you've used Claude Code on a real project, you've felt the friction: the AI works at file-level but humans plan at architecture-level, and the two drift apart. Specs go stale. Stories get re-implemented. Tests are skipped under deadline pressure. PRs end up loosely related to the original requirements.

ck-code closes that gap. The architecture docs, the story plan, the expert skills, and the implementation are all generated from the same spec — and the build loop refuses to ship code without a failing test, a SOLID check, and an explicit story status update. The result is AI-assisted software engineering that produces code your team can actually own.

## Use cases

- **Greenfield projects** — go from a one-page spec to a complete tasks/ plan with architecture docs and a per-project expert team in a single session
- **Feature additions** — extend an existing codebase: ck-code reads your current architecture, scopes the feature, and generates only the new epics and stories
- **Disciplined AI coding** — enforce TDD and SOLID even in long autonomous sessions
- **Multi-developer parallel builds** — fan out unblocked stories across worktrees and let agents implement them in parallel, with automatic conflict analysis before merge
- **GitHub-integrated planning** — turn your story plan into a labelled, linked Issue tree with a single command

## Layout

```
ck-code/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/                        # ck-code-specific subagents
│   ├── qa-validator.md
│   ├── conflict-analyzer.md
│   └── story-implementer.md
├── skills/
│   ├── pre-spec/                  # stakeholder-ready feature spec (create + adjust)
│   ├── design/                    # spec → feature-scoped architecture docs
│   ├── doc-optimizer/             # migrate/scaffold/prune feature docs to cut read tokens
│   ├── plan/                      # architecture → epics/stories
│   ├── quick-story/                # add one small story to an existing epic without the full plan cycle
│   ├── team/                      # generate per-project experts + guides
│   ├── to-issues/                 # push tasks/ → GitHub Issues (batch)
│   ├── track/                     # progress dashboard
│   ├── build/                     # TDD story implementation
│   ├── parallel-build/            # parallel worktree builds
│   ├── ship/                      # commit + PR + Issue updates
│   ├── fix/                       # multi-story bug fixes (auto-matches scope, can create stub stories in the right epic)
│   ├── sync/                      # reconcile STORIES_INDEX.md / EPIC.md / story files when they drift
│   ├── explain/                   # post-implementation walkthrough
│   └── help/                      # command reference
└── README.md
```

## Per-feature spec folder

Pre-specs and downstream design output share a single folder per feature so
they stay adjacent throughout the lifecycle:

```
docs/specs/YYYY-MM-DD_<slug>/
├── pre-spec.md            # Stakeholder-friendly version (from /ck-code:pre-spec)
├── .metadata.json         # Slug, GitHub issue link, status, language
└── feature-spec.md        # (later, optional) Design-pass output
```

`/ck-code:pre-spec` creates these on first run and re-uses them on
subsequent invocations to apply adjustments — keeping the local file and
the linked GitHub issue in sync.

Each skill folder is self-contained: the main `SKILL.md` is the entry point, and any bulky templates or examples live alongside it in a `references/` subfolder that loads on demand.

## Compatibility

> **v3 — breaking.** ck-code v3 reads only the v3 architecture-doc layout
> (`docs/architecture/features/<slug>/index.md`, a schema-v2 `FEATURE_INDEX`). It no
> longer reads the pre-v3 layouts (flat `features/<slug>.md`, the retired
> `components.md`/`api-contracts.md`/`database-schema.md`/`data-flow.md` layer docs, or a
> `v1` index). Every change-producing skill runs a **version gate** first: on a pre-v3
> project it blocks and offers `/ck-code:doc-optimizer upgrade`, a one-shot migration that
> converts the layout, scaffolds `DESIGN_LEDGER.md`, and stamps `tasks/VERSION.md` (a fast-
> path marker so later sessions skip the scan). Run `upgrade` once and your project is v3.

- **Claude Code** — required (CLI, IDE extension, or desktop app)
- **gh CLI** — required for `/ck-code:to-issues` and `/ck-code:ship` GitHub Issue features
- **git** — required for `/ck-code:parallel-build` (uses worktrees)
- **[context7](https://context7.com)** — recommended for `/ck-code:team`, `/ck-code:design`, `/ck-code:plan`, and `/ck-code:build` to fetch up-to-date framework documentation. Either form works:
  - **MCP server** — install once into Claude Code; tools auto-discovered
  - **`ctx7` CLI** — `npx -y @upstash/context7 setup` (one-time auth), then commands run inline via Bash. Recommended when MCP isn't configured or for parallel sub-agents that don't inherit the MCP host

## Contributing

Issues and pull requests welcome at [github.com/ckandrinirina/ck-code](https://github.com/ckandrinirina/ck-code). If you use the plugin and find a rough edge, please open an issue describing your project type and the command that misfired — concrete examples make the workflow better for everyone.

## License

MIT — see [LICENSE](LICENSE) if present, otherwise this notice constitutes the grant.

## Keywords

Claude Code plugin · spec-driven development · AI coding workflow · TDD with AI · automated architecture documentation · GitHub Issues integration for AI · parallel AI agent builds · Claude agent skills · context7 best practices · AI-assisted software engineering
