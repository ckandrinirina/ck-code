# ck-code

Spec-driven workflow plugin for [Claude Code](https://www.anthropic.com/claude-code). Turns a project specification into architecture docs, an implementation plan, and a guided TDD build/ship loop — with per-project expert and tech-guide skills generated on demand.

## Workflow

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

## Install

```bash
# 1) Add this repo as a marketplace
/plugin marketplace add ckandrinirina/ck-code

# 2) Install the plugin
/plugin install ck-code@ck-marketplace
```

## Per-project opt-in

Installation alone does not activate the plugin in every project. Enable it explicitly per project by adding to that project's `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "ck-code@ck-marketplace": true
  }
}
```

Without this entry the plugin stays dormant — no slash commands, no auto-loaded behavior. This keeps unrelated repos free of the workflow.

## First-time setup in a new project

```bash
/ck-code:design  docs/specifications.md      # 1. Generate architecture docs
/ck-code:team                                # 2. Create project-tailored experts + guides
/ck-code:plan    docs/specifications.md      # 3. Generate epics and stories
/ck-code:publish                             # 4. (Optional) push to GitHub Issues
/ck-code:track   next                        # 5. Find first story to implement
/ck-code:build                               # 6. Start building (TDD + QA)
```

After `/ck-code:team` runs, your project's `.claude/skills/` will contain:

- `experts/{frontend,backend,qa,analyst,devops,qa-project}/SKILL.md` — invoked as `/expert-frontend`, `/expert-backend`, etc.
- `guides/{rust,axum,react-native,...}/SKILL.md` — auto-loaded by Claude when relevant files are touched.

These generated skills are project-level (not plugin-namespaced) and are intentionally tailored to the architecture you fed into `/ck-code:design`.

## Layout

```
ck-code/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   ├── design/SKILL.md
│   ├── plan/SKILL.md
│   ├── team/SKILL.md
│   ├── publish/SKILL.md
│   ├── track/SKILL.md
│   ├── build/SKILL.md
│   ├── ship/SKILL.md
│   ├── fix/SKILL.md
│   ├── explain/SKILL.md
│   ├── parallel-build/SKILL.md
│   └── help/SKILL.md
├── agents/      # for future custom subagents
└── commands/    # for future custom slash commands
```

## License

MIT
