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

## Install

```bash
# 1) Add this marketplace inside Claude Code
/plugin marketplace add ckandrinirina/ck-code

# 2) Install the ck-code plugin
/plugin install ck-code@ck-marketplace
```

That's it — restart your Claude Code session and the `/ck-code:*` commands are available.

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
/ck-code:publish                           # 4. (Optional) push to GitHub Issues
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
/ck-code:design  →  /ck-code:team  →  /ck-code:plan  →  /ck-code:publish  →  /ck-code:track
                                                                                 ↓
                                                                         /ck-code:build  →  /ck-code:ship
                                                                                 ↑
                                                                         /ck-code:fix  ──┘
```

| Skill | Purpose | Input | Output |
|-------|---------|-------|--------|
| `/ck-code:design` | Refine a spec into architecture docs | spec file | `docs/architecture/` |
| `/ck-code:team` | Generate per-project expert + guide skills | `docs/architecture/` | `.claude/skills/experts/`, `.claude/skills/guides/` |
| `/ck-code:plan` | Create epics, stories, roadmap | spec file | `tasks/YYYY-MM-DD_<project>/` |
| `/ck-code:publish` | Push epics/stories to GitHub Issues | tasks folder | GitHub Issues |
| `/ck-code:track` | Progress dashboard | — | status, next story, completion % |
| `/ck-code:build` | Implement a story (TDD + QA) | story file | source code + tests |
| `/ck-code:parallel-build` | Implement multiple ready stories in parallel worktrees | — / story IDs | parallel results + conflict report |
| `/ck-code:fix` | Diagnose and fix a bug in a story | story file | minimal fix + regression test |
| `/ck-code:ship` | Commit, PR, update GitHub Issues | story file (optional) | commit + PR + issue updates |
| `/ck-code:explain` | Explain what was just implemented | — | walkthrough + verification steps |
| `/ck-code:help` | Quick reference for all commands | — | this table |

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
│   ├── design/                    # spec → architecture docs
│   ├── plan/                      # architecture → epics/stories
│   ├── team/                      # generate per-project experts + guides
│   ├── publish/                   # push tasks/ → GitHub Issues
│   ├── track/                     # progress dashboard
│   ├── build/                     # TDD story implementation
│   ├── parallel-build/            # parallel worktree builds
│   ├── ship/                      # commit + PR + Issue updates
│   ├── fix/                       # story-linked bug fixes
│   ├── explain/                   # post-implementation walkthrough
│   └── help/                      # command reference
└── README.md
```

Each skill folder is self-contained: the main `SKILL.md` is the entry point, and any bulky templates or examples live alongside it in a `references/` subfolder that loads on demand.

## Compatibility

- **Claude Code** — required (CLI, IDE extension, or desktop app)
- **gh CLI** — required for `/ck-code:publish` and `/ck-code:ship` GitHub Issue features
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
