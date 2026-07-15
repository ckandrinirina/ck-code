# ck-code — Spec-Driven Workflow Plugin for Claude Code

> Turn a project specification into architecture docs, an implementation plan, and a TDD-driven build/ship loop — all from inside [Claude Code](https://www.anthropic.com/claude-code).

**ck-code** is an open-source [Claude Code plugin](https://www.anthropic.com/claude-code) that brings spec-driven development to AI-assisted software engineering. Feed it a project specification and it will:

1. **Design** — refine your spec into a complete set of architecture documents (global docs like folder structure and tech stack, plus one self-contained doc per feature covering its components, APIs, and data)
2. **Plan** — break the architecture into epics and single-dispatch stories (each sized S/M so one agent finishes it in a pass) with explicit dependencies
3. **Team** — derive a project-tailored team of expert and language-guide skills from your architecture, generating only the roles the project needs, at a depth you choose (`--basic` / `--standard` / `--max`), and capture your own house conventions (`--conventions`)
4. **Build** — implement each story using test-driven development (TDD), SOLID principles, and a built-in dev-QA validation loop
5. **Ship** — commit with conventional commits, open a pull request, and auto-update linked GitHub Issues

Whether you're building a new project from scratch or adding a feature to an existing codebase, ck-code keeps the architecture, plan, and implementation in lock-step — so AI-generated code stays grounded in your real design.

## One source of truth (v4)

In v4, a story's state lives in **one** place: the YAML frontmatter of its story file
(`id, title, epic, status, size, blocked_by, files, issue, prior_status`). The
`STORIES_INDEX.md` and `FEATURE_INDEX.md` you see are **generated read-only views**,
regenerated from that frontmatter by `scripts/ck-index.sh`. Because a view is a pure
function of the frontmatter, it can never drift — so v4 has no reconciler skill and no
hand-edited index tables. To change a story's status, a skill edits the frontmatter and
regenerates; that's it.

## Features

- **Spec-driven development workflow** — single source of truth from specification to merged PR
- **Frontmatter-driven story state** — one writable location per story; indexes are generated, never hand-maintained
- **Automatic architecture documentation** — split markdown docs in `docs/architecture/` (overview, folder structure, tech stack, configuration, dev guide, `_shared.md`, plus a self-contained `features/<slug>/index.md` per feature)
- **Epic and story planning** — S/M-sized stories with dependency graphs in `tasks/`
- **GitHub Issues integration** — `ship --to-issues` pushes epics/stories to GitHub Issues; the created issue number is stored in each story's `issue:` frontmatter, so `ship` links by number (never by fragile title matching)
- **Test-Driven Development (TDD) enforcement** — red/green/refactor cycle, no production code without a failing test first
- **SOLID principle checks** — every implementation is reviewed against the five principles
- **Project-tailored expert skills** — auto-generated per-project experts and language guides, refreshed via [context7](https://context7.com); regeneration is non-destructive (your hand-authored and convention skills are preserved)
- **Parallel multi-story builds** — implement multiple unblocked stories at once in isolated git worktrees (native isolation, structured returns, resumable agents) with conflict analysis before merge
- **Bug triage that hands off to the backlog** — `fix` diagnoses a bug, writes a failing test + Fix Plan into its story, flips it to `bug`; an easy single-story fix auto-runs `build` (Bug-Fix Mode), while a complex one is recorded for a manual `build`/`parallel-build`
- **Native Claude Code integration** — `SessionStart`/`PostToolUse` hooks (auto-reload generated experts, inject project status + migration notice, config-gated auto-format), a subagent status line for parallel builds, and built-in `/goal`, `/code-review`, `/fast` pairings documented in `references/native-commands.md`

## Install

```bash
# 1) Add this marketplace inside Claude Code
/plugin marketplace add ckandrinirina/ck-code

# 2) Install the ck-code plugin
/plugin install ck-code@ck-marketplace
```

Restart your Claude Code session and the `/ck-code:*` commands are available.

## Update

```bash
/plugin update ck-code@ck-marketplace
```

Then restart your Claude Code session for the updated commands to take effect.

## Upgrading a v3 project to v4

v4 changes how story state is stored (frontmatter, not hand-maintained index tables), so
it is a **breaking** layout change. Existing projects upgrade in one step:

```bash
/ck-code:migrate
```

`migrate` is one-shot, idempotent, and safe: it refuses a dirty tree and lands every
conversion in a single revertable commit. Every change-producing skill blocks a pre-v4
project until you run it, and the session-start hook reminds you. Pre-v3 projects are
handled too — the converter chains the older layout migrations first.

## Per-project opt-in

Enable the plugin explicitly per project in that project's `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "ck-code@ck-marketplace": true
  }
}
```

Without this entry the plugin stays dormant in that project.

## Quick start — first-time setup in a new project

```bash
/ck-code:spec     docs/notes.md            # 1. (Optional) stakeholder-ready feature spec
/ck-code:design   docs/specifications.md   # 2. Generate architecture docs
/ck-code:team                              # 3. Create project-tailored experts + guides
/ck-code:plan     docs/specifications.md   # 4. Generate epics and stories
/ck-code:ship --to-issues                  # 5. (Optional) push the plan to GitHub Issues
/ck-code:track    next                     # 6. Find the first story to implement
/ck-code:build                             # 7. Start building (TDD + QA)
/ck-code:ship                              # 8. Commit, PR, close Issue
```

Not sure what to run? `/ck-code:guide` recommends the next step from project state,
`/ck-code:guide "add a login screen"` routes a plain-language task to the right skill, and
`/ck-code:guide --command build` prints a command's syntax.

## The full workflow

```
/ck-code:spec  →  /ck-code:design  →  /ck-code:team  →  /ck-code:plan  →  /ck-code:ship --to-issues  →  /ck-code:track
  (optional)                                                                                  ↓
                                                                              /ck-code:build  →  /ck-code:ship
                                                                                         ↑
                              /ck-code:fix  (diagnose bug → bug status)  ─────────────────┘
                              (easy fix auto-runs build; complex hands off to build/parallel-build)
```

| Skill | Purpose | Input | Output |
| --- | --- | --- | --- |
| `/ck-code:spec` | Generate a stakeholder-ready feature spec for review (descriptive, no code/jargon); CREATE + ADJUST modes | feature description or notes file | `docs/specs/` and/or GitHub issue |
| `/ck-code:design` | Refine a spec into feature-scoped architecture docs (one self-contained doc per feature + `_shared.md`); also `sync`/`optimize` maintenance modes | spec file | `docs/architecture/` |
| `/ck-code:team` | Derive per-project expert + guide skills from the architecture (depth `--basic`/`--standard`/`--max`); `--conventions` captures house rules; regeneration is non-destructive | `docs/architecture/` | `.claude/skills/experts/`, `.claude/skills/guides/` |
| `/ck-code:plan` | Create epics, single-dispatch S/M stories, a mandatory final Integration & E2E epic, and a roadmap; `--quick [brief] [--epic NN]` adds one small story to an existing epic | spec file | `tasks/YYYY-MM-DD_<slug>/` (stories carry frontmatter) |
| `/ck-code:build` | Implement a story (TDD + QA); a `bug`-status story runs in **Bug-Fix Mode** (implements the recorded Fix Plan, restores the story to `done`) | story file | source code + tests; regenerated index views |
| `/ck-code:parallel-build` | Implement multiple ready stories in parallel worktrees, or a whole epic in dependency-ordered waves (`--epic NN`) | — / story IDs / `--epic NN` | parallel results + conflict report |
| `/ck-code:fix` | Diagnose a bug tied to a story, write a failing test + Fix Plan, flip it to `bug` — then auto-run `build` for an easy fix or hand off when complex. Never writes the source fix itself | story file (optional) | failing test + Bug Report + `bug` status → `build` |
| `/ck-code:ship` | Commit, PR, update GitHub Issues. `--to-issues [--mode feature\|epics\|stories]` publishes the plan to Issues and stores each issue number in story frontmatter | story file (optional) | commit + PR + issue updates |
| `/ck-code:track` | Progress dashboard + `next` ready-story finder (reads the generated indexes) | — | status, next story, completion % |
| `/ck-code:guide` | Router: no arg → next step from state; free text → best-fit skill; `--command <name>` → syntax (read-only, recommends only) | plain-language task / `--command` | recommended command + prerequisite + next step |
| `/ck-code:migrate` | One-shot, idempotent upgrade of a pre-v4 project to the v4 layout (frontmatter + generated indexes); stamps `tasks/VERSION.md` | — | converted project (one commit) |
| `/ck-code:explain` | Explain what was just implemented + manual verification steps | — | walkthrough + verification steps |

## Why ck-code?

If you've used Claude Code on a real project, you've felt the friction: the AI works at file-level but humans plan at architecture-level, and the two drift apart. Specs go stale. Stories get re-implemented. Tests are skipped under deadline pressure.

ck-code closes that gap. The architecture docs, the story plan, the expert skills, and the implementation are all generated from the same spec — and the build loop refuses to ship code without a failing test, a SOLID check, and an explicit story status update. In v4, that status lives in exactly one place, so the plan you read is always the plan that's true.

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
├── scripts/
│   ├── ck-index.sh                # regenerate the index views from story frontmatter
│   ├── session-start.sh           # SessionStart hook (reload skills, status, migrate notice)
│   ├── format.sh                  # PostToolUse auto-format (config-gated)
│   └── subagent-statusline.sh
├── skills/
│   ├── spec/                      # stakeholder-ready feature spec (create + adjust)
│   ├── design/                    # spec → feature-scoped architecture docs (+ optimize/sync)
│   ├── team/                      # derive per-project experts + guides (+ conventions)
│   ├── plan/                      # architecture → epics/stories (+ --quick single story)
│   ├── build/                     # TDD story implementation
│   ├── parallel-build/            # parallel worktree builds
│   ├── fix/                       # bug triage → hands off to build
│   ├── ship/                      # commit + PR + Issue updates (+ --to-issues)
│   ├── track/                     # progress dashboard
│   ├── guide/                     # state/intent/command router
│   ├── migrate/                   # pre-v4 → v4 layout converter
│   └── explain/                   # post-implementation walkthrough
└── README.md
```

Each skill folder is self-contained: the main `SKILL.md` is the entry point, and any bulky templates or examples live in a `references/` subfolder that loads on demand.

## Per-feature spec folder

```
docs/specs/YYYY-MM-DD_<slug>/
├── pre-spec.md            # Stakeholder-friendly version (from /ck-code:spec)
├── .metadata.json         # Slug, GitHub issue link, status, language
└── feature-spec.md        # (later, optional) Design-pass output
```

`/ck-code:spec` creates these on first run and re-uses them on subsequent invocations to
apply adjustments — keeping the local file and the linked GitHub issue in sync.

## Compatibility

> **v4 — breaking.** ck-code v4 stores story state in story-file frontmatter and generates
> its `STORIES_INDEX.md` / `FEATURE_INDEX.md` views. It no longer reads the v3 layout
> (prose `Status:` headers, hand-maintained `Schema: v1/v2` index tables, `EPIC.md` story
> tables, `DESIGN_LEDGER.md`, `L`/`XL` sizes). Every change-producing skill runs a **version
> gate** first: on a pre-v4 project it blocks and offers `/ck-code:migrate`, a one-shot,
> idempotent converter that rewrites the layout and stamps `tasks/VERSION.md`. Run it once
> and your project is v4.

- **Claude Code** — required (CLI, IDE extension, or desktop app)
- **gh CLI** — required for `ship --to-issues` and `ship` GitHub Issue features
- **git** — required for `parallel-build` (uses worktrees)
- **[context7](https://context7.com)** — recommended for `team`, `design`, `plan`, and `build` to fetch up-to-date framework documentation. Either the MCP server or the `ctx7` CLI (`npx -y @upstash/context7 setup`) works.

## Contributing

Issues and pull requests welcome at [github.com/ckandrinirina/ck-code](https://github.com/ckandrinirina/ck-code). If you use the plugin and find a rough edge, please open an issue describing your project type and the command that misfired — concrete examples make the workflow better for everyone.

## License

MIT — see [LICENSE](LICENSE) if present, otherwise this notice constitutes the grant.

## Keywords

Claude Code plugin · spec-driven development · AI coding workflow · TDD with AI · automated architecture documentation · GitHub Issues integration for AI · parallel AI agent builds · Claude agent skills · context7 best practices · AI-assisted software engineering
