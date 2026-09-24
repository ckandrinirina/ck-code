<!-- Emitted verbatim by scripts/prompt-router.sh as UserPromptSubmit context on every free-text prompt in a ck-code project. Every line costs tokens on every prompt: keep it one screen, a routing table, never a workflow. Lines starting with "<!--" are stripped. This is THE single intent → skill table: skills/guide Mode B reads this file and keeps no copy of its own; order matters (first match wins). -->
ck-code router — this project uses ck-code. Before acting on this prompt, pick the best-fit ck-code skill and invoke it with the Skill tool: announce it in one line (`→ /ck-code:<skill> <args>`), then call it. The prompt itself is the consent — never ask "should I use /ck-code:fix?" first.
| Intent (first match wins) | Skill |
|---|---|
| PR merged or issue closed but the story, board or issue does not show it; fix bookkeeping drift | `doctor --fix` |
| what is broken in the project itself — indexes, stories, layout, "why is this broken" | `doctor` |
| upgrade an old layout, or move a ck-code-lite project (`tasks/PLAN.md`) to full ck-code | `migrate` |
| settings — issue tracking, trunk branch, GitHub Project board or columns, a plan's integration level | `config` (`config integration <tasks/plan> <story\|epic\|plan>`) |
| bug, crash or regression in built code | `fix` |
| publish the plan to GitHub Issues | `plan --publish` |
| commit, PR, "ship it", deliver finished work; the PR for a finished epic or plan | `ship` / `ship --promote` |
| implement or continue an existing story; several ready stories; a whole epic | `build` / `build <ids>` / `build --epic NN` |
| new functionality no story covers — small (one story) | `plan --quick <brief>` |
| new functionality no story covers — large, or new work to break into epics, stories, a roadmap | `plan` |
| expert or guide skills are stale after a stack or folder change | `team --refresh` |
| stakeholder-facing feature spec | `spec` |
| link a Claude Design URL, or refresh the linked design system | `design ds [url]` |
| architecture, tech choices, data or flow design; bloated docs → `design optimize` | `design` |
| expert or guide skills, house coding conventions | `team` |
| progress, status, which story is next | `track` |
| explain what was built, how to verify it, or what an epic is for | `explain` |
| unsure which skill fits, or no task yet | `guide` |
Do not route when: a ck-code skill is already running and this prompt answers its question — continue it; the prompt is a question, a read-only or non-code request — answer directly; the prompt is a one-off edit that adds no behaviour (a typo, a rename, a config value) — do it, but first read the matching expert or guide skill under `.claude/skills/` and follow its conventions, test first.
Never route to a skill whose prerequisite is missing — name the prerequisite instead (`build` and `plan --quick` need a plan in `tasks/`; `plan` and `team` need `docs/architecture/`; `ship` needs implemented work).
