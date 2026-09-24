---
name: track
description: Use when the user wants to see project progress, list ready stories, or pick the next one to implement. Reads the generated story and epic views; read-only. Argument is `status` (default), `next`, or `progress`.
argument-hint: "[status|next|progress]"
effort: low
model: haiku
context: fork
agent: Explore
background: false
allowed-tools: Bash(ck-view*) Bash(ck-index*) Bash(ck-plan get*) Bash(git branch*) Bash(git status*) Bash(git rev-list*)
disallowed-tools: Write, Edit, NotebookEdit
---

# Story Tracker — Project Progress Dashboard

Presents a live view of project progress, story statuses, and what to implement next.

The dashboard is **rendered by `ck-view`**, not by this skill. Every figure in it — the
ready/blocked split, the epic rollups, the percentages, the `next` selection — is a pure
function of `STORIES_INDEX.md` / `EPICS_INDEX.md`, the generated, gitignored projections of
story frontmatter produced by `scripts/ck-index.sh` (see
[`../../references/data-model.md`](../../references/data-model.md)). Computing it in the
model costs tokens for an answer a script already gets exactly right, so this skill runs
one command and relays it.

## INPUT

`$ARGUMENTS` determines the command:

| Command | What It Does |
| ------------------- | ------------------------------------------------ |
| (empty) or `status` | Full status dashboard with all stories |
| `next` | Suggest the next story ready for implementation |
| `progress` | Epic completion percentages and overall progress |

## PHASE 0: VERSION GATE (hint only — Tier 1)

Layout stamp: !`cat "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tasks/VERSION.md" 2>/dev/null || echo "ABSENT — no tasks/VERSION.md"`

Read the injected stamp; never spend a `Read` call on `tasks/VERSION.md`. `layout: v7` →
proceed silently. A newer layout → emit `ℹ newer ck-code layout — update the plugin`;
anything else (older, or `ABSENT` with a `tasks/` folder) → emit
`ℹ older ck-code layout — run /ck-code:migrate`. Then **continue read-only**. Never run
Tier 2, never block, never stamp. See
[`../../references/version-gate.md`](../../references/version-gate.md#scope).

## PHASE 1: RENDER (one call)

```bash
ck-view status                  # or: ck-view next  /  ck-view progress
ck-view status tasks/<slug>     # optional: restrict to one plan
```

Relay its stdout **verbatim** — that output is the deliverable. `ck-view` already:

- regenerates any view that is missing, unstamped or older than the frontmatter it
  projects (`STORIES_INDEX.md` per plan and `tasks/EPICS_INDEX.md`). The views are
  gitignored and disposable, so this invents no state and changes nothing git tracks;
- applies **The Ready rule** ([`../guide/SKILL.md`](../guide/SKILL.md#the-ready-rule)): a
  story is ready when `status: todo` and every `blocked_by` story is `done` or `skip`, or
  when `status: bug`. It resolves `blocked_by` across every plan and marks `bug` rows 🐛;
- reports the two axes separately — `Status` is *is the work finished?*, `Delivery` is
  *how far did it travel toward the trunk?*. A `DONE` row with an empty Delivery prints
  as `not shipped`, which is the exact gap this view exists to close
  ([`../../references/data-model.md`](../../references/data-model.md#two-axes-status-is-work-delivery-is-integration));
- runs the `next` selection algorithm (open bugs first, then epic order, story order,
  size) and ends `next` with the `NEXT: /ck-code:build <path>` directive line;
- renders every plan of a multi-plan project, each under its own heading, named by its
  `OVERVIEW.md` `title:`.

**Never re-derive any of it.** Do not read a story file, `STORIES_INDEX.md`, `EPICS_INDEX.md`, or
[`references/dashboard-templates.md`](references/dashboard-templates.md) to recompute a
count, a percentage or a recommendation — the templates file documents what `ck-view`
emits and is read only when a *field* needs explaining, never to render.

Surface every `ck-view: WARN` / `ck-index: WARN` line the run printed
([stories-index.md](../../references/stories-index.md)): a skipped story is invisible in
every view while its file still exists.

If `ck-view: command not found` appears, the plugin is disabled or predates `bin/ck-view`
— fall back to `"${CLAUDE_PLUGIN_ROOT}"/scripts/ck-view.sh` and say so in one line.

## PHASE 2: BRANCH TOPOLOGY (conditional)

The integration level belongs to the plan, not the epic. Read it once per plan:

```bash
ck-plan get tasks/<plan> integration branch
```

**If every plan is at `story` level (or has no level set), skip this phase entirely** —
the block would be noise for the majority of projects. Otherwise collect, with read-only
git, and render the tree **above** the `ck-view` output:

```bash
git branch --list "epic/*" "story/*" "fix/*" "<recorded plan branch>"
git rev-list --count <parent>..<branch>      # per epic of an epic/plan-level plan, and its open stories
```

The plan branch is whatever the record's `branch:` says (`plan/<slug>` for a new plan; a
migrated plan may still record `feat/<slug>` — the field wins, never guess it from the
folder name).

```
plan/auth-system        -> main          plan level, 2 epics, no PR
  epic/02-auth          -> plan/…        DONE 4/4, merged
  epic/03-profile       -> plan/…        IN PROGRESS 2/5
    story/03-03-avatar  -> epic/03       2 commits unmerged
epic/04-billing         -> main          epic level
```

Branch names derive per
[`../../references/branch-topology.md`](../../references/branch-topology.md). An
`epic/<NN>-*` glob matching a branch whose slug no longer matches its `EPIC.md` `slug:` is
an orphan left by a rename — list it under the tree as `orphan`.

## RULES

- **Never** write, edit, or create any project file — this skill is read-only. The only
  permitted Bash calls are `ck-view`, a `ck-index` fallback (it rewrites only the
  gitignored views), `ck-plan get`, and the **read-only** git queries in Phase 2. Never `checkout`, `merge`, `push` or `branch -d`.
- **Never** re-render, summarize, reformat or "improve" `ck-view` output — relay it
  verbatim. This skill runs forked, so its result is relayed; rewriting it discards the
  one thing the fork was for and reintroduces the arithmetic the script exists to remove.
- **Never** hand-maintain or bootstrap an index by globbing story files — the story
  frontmatter is the source of truth and `ck-index` produces the views.
- **Never** cache state — every run re-reads the index through `ck-view`.
- **Always** reference current skills only (`build`, `fix`, `ship`, `plan`, `migrate`,
  `doctor`); never `sync`, `parallel-build`, `start`, `advise`, `help`, or `to-issues`.
- **Always** end a `next` run with the `NEXT: /ck-code:build <path>` line `ck-view`
  emitted and nothing after it, per
  [`../../references/skill-invocation.md`](../../references/skill-invocation.md). The main
  session offers it as a one-click run so the user never retypes the path. Emit no
  directive for `status` or `progress`, and none when no story is ready.
- **Never** call the `Skill` tool — this skill runs forked and read-only, and an Explore
  fork has no write tools; the `NEXT:` line is how it hands off.
- **Always** output in English.
