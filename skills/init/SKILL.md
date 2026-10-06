---
name: init
description: Use when bringing ck-code into a project for the first time — especially an existing codebase that already has source and maybe its own docs but no spec, no docs/architecture/ and no tasks/ — or when checking that a project has everything ck-code needs installed and wired. Argument is optional `--deps-only`.
argument-hint: "[--deps-only]"
effort: high
allowed-tools: Bash(ck-bootstrap*) Bash(ck-index*) Bash(command -v*) Bash(gh auth status*) Bash(git status*) Bash(git rev-parse*) Bash(git ls-files*) Bash(git mv*) Bash(awk*) Bash(find*) Bash(grep*) Bash(ls*) Bash(sort*) Bash(head*) Bash(mkdir*) Bash(date*) Skill
---

# Init — Bring ck-code Into a Project

The **brownfield entry point**. The normal flow, `spec → design`, assumes the project is an
idea. A project that already has code has no spec to write. It needs its architecture read
off the code as it is built, and it needs ck-code's project-side pieces installed. This
skill does both, and writes **no spec**.

| Mode           | When (Phase 1 decides)                                | Does                                                                         |
| -------------- | ----------------------------------------------------- | ---------------------------------------------------------------------------- |
| **EXISTING**   | tracked source, no ck-code feature docs               | dependencies + doc discovery + code survey + architecture docs _as built_    |
| **EMPTY**      | no source yet                                         | dependencies only, then hands off to `spec` (or `design` when a spec exists) |
| **DOCUMENTED** | `docs/architecture/features/*/index.md` already exist | dependencies only; recommends `design sync` / `team`                         |
| `--deps-only`  | any                                                   | dependencies only                                                            |

Feature docs written here carry **`design: built`**. That value means the doc describes
shipped code, with nothing waiting to be planned, so `plan` never re-plans what already
exists ([`data-model.md`](../../references/data-model.md#feature-doc-design-output)).
New work on an existing project goes through `design` (Feature Mode) or `plan --quick`
afterwards.

## ROUTING CHECK (do first)

- A ck-code-lite project (`tasks/PLAN.md`) or an older ck-code layout → `/ck-code:migrate`
  (Phase 0 routes it)
- A new feature for a project ck-code already manages → `/ck-code:design` or `/ck-code:plan --quick`
- Something is broken in a ck-code project → `/ck-code:doctor`

Full matrix: [`workflow-map.md`](../../references/workflow-map.md#misuse-redirects--am-i-the-right-skill).
**Next step after this skill:** `/ck-code:team` (EXISTING), `/ck-code:spec` (EMPTY).

## PROGRESS TRACKING

Open a `TodoWrite` list as the first action of Phase 0, one todo per phase this run will
execute. Flip each to `in_progress` when it starts and `completed` when its gate passes,
and drop a phase the mode skips. Never batch the updates to the end.

## PHASE 0: VERSION GATE (hard, inline)

The stamp is injected at skill-load time — **do not spend a `Read` on it**:

Layout stamp: !`cat "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tasks/VERSION.md" 2>/dev/null || echo "ABSENT — no tasks/VERSION.md"`

- `layout: v7` → **PASS**. A stamp alone does not mean the docs exist: Phase 1 still picks
  the mode, and every Phase 2 write is idempotent.
- Anything else, including `ABSENT` → run the Tier-2 probe of the shared
  [version gate](../../references/version-gate.md#tier-2--full-detection-only-when-the-stamp-is-missing-or-stale)
  verbatim. `NEWER` → its update message, stop. `V6` / `LEGACY` / `LITE` → its BLOCK and
  `migrate` hand-off; never initialise over an older layout. **No marker → continue**: this
  skill writes the stamp itself in Phase 2.

Not a git repository (`git rev-parse --show-toplevel` fails) → say ck-code needs one
(`git init` first) and stop.

## PHASE 1: DETECT MODE (read-only)

`--deps-only` → mode is `--deps-only`; skip the probe. Otherwise one batched probe:

```bash
find docs/architecture/features -mindepth 2 -maxdepth 2 -name index.md -exec grep -l '^slug:' {} + 2>/dev/null | head -3
find docs/architecture -type f -not -path 'docs/architecture/archive/*' 2>/dev/null | head -5
git ls-files | grep -vE '^(docs|tasks|\.claude|\.github)/|^[^/]+\.(md|txt|rst)$|^(LICENSE|\.git|\.editorconfig)' | head -5
```

| Result        | Mode           |
| ------------- | -------------- |
| line 1 prints | **DOCUMENTED** |
| line 3 prints | **EXISTING**   |
| neither       | **EMPTY**      |

**Foreign `docs/architecture/`** — line 2 prints but line 1 does not: the folder holds the
project's own docs, not ck-code's, and Phase 5 would write over them. In EXISTING mode,
ask once (`AskUserQuestion`): **Archive** — `git mv` them under
`docs/architecture/archive/` (needs a clean `git status --porcelain`; dirty → STOP and ask
for a commit or stash), still read as source docs in Phase 3 / **Cancel**. Never write into
a foreign `docs/architecture/` unarchived, and never delete a source doc.

Announce the mode in one line, e.g. `Mode: EXISTING — 214 tracked files, no ck-code docs.`

## PHASE 2: DEPENDENCIES (every mode)

### 2.1 Machine side (check, never install)

Runs first: `ck-bootstrap install` (2.2) needs `python3` to merge `.claude/settings.json`.

```bash
command -v git awk python3 gh jq rtk npx
gh auth status
```

Report one row per tool from [references/dependencies.md](references/dependencies.md):
tool, `present` / `missing`, what ck-code uses it for, and the install hint when missing.
A missing **required** tool is flagged above the table, never a reason to stop: 2.2 still
runs, and `ck-bootstrap` prints the hand-merge it needs when `python3` is absent. **Never
install, upgrade or configure a tool yourself**: package managers, `gh auth login`,
`rtk init` and MCP setup are the user's to run. context7 counts as present when an
`mcp__*context7*` tool is in this session or `npx` is on PATH.

GitHub issue tracking, the trunk branch and the project board are settings, not
dependencies. Mention `/ck-code:config` once in the summary; never run it from here.

### 2.2 Project side (writes)

1. **Stamp** `tasks/VERSION.md` per [§ Stamp](../../references/version-gate.md#stamp-writing-tasksversionmd)
   (`mkdir -p tasks`, `layout: v7`, `requires: ck-code >= <MIN_PLUGIN>`). Never rewrite an
   existing v7 stamp.
2. `ck-bootstrap install` — the committed guard (`.claude/ck-code-required.sh`) and its
   `.claude/settings.json` wiring, which also enables the plugin for the project. Then
   `ck-bootstrap check`; relay any line that is not OK.
3. `ck-index` — writes `tasks/.gitignore` (the views stay out of git). Relay every
   `ck-index: WARN` line.

`--deps-only`, EMPTY and DOCUMENTED stop after this phase; jump to
Phase 6.

## PHASE 3: DISCOVER (EXISTING, read-only)

Follow [references/as-built.md § Discovery](references/as-built.md#discovery): the
existing-docs inventory, the repo shape, the manifests and the stack. **Orchestrator cap:
15 file reads in this phase.** Depth belongs to Phase 5's per-feature pass, never here.

Record the commit with `git rev-parse --short HEAD`. Every generated doc cites it.

## PHASE 4: FEATURE LIST (EXISTING)

1. Derive the feature list per [references/as-built.md § Features](references/as-built.md#features).
   Each feature gets a short kebab `<slug>`, a one-line boundary and the source paths it
   owns. Infra used by two or more features goes to `_shared.md`, never into a feature.
2. Present the list as a table (slug · feature · owned paths · source doc, if any), plus the
   `_shared.md` candidates, then one `AskUserQuestion`: **Proceed** / **Adjust** (the user
   renames, merges, splits or drops; re-present once) / **Cancel** (stop; Phase 2's writes
   stay — they are correct on their own).

This is the only question in the run. Never open spec-style Q&A rounds: a gap is
written as `[TO BE DEFINED]`, never asked about.

## PHASE 5: GENERATE THE ARCHITECTURE AS BUILT (EXISTING)

Templates come from [`design`'s architecture-templates.md](../design/references/architecture-templates.md),
used verbatim, with only the as-built deltas in
[references/as-built.md § Template deltas](references/as-built.md#template-deltas)
(`design: built`, the README source block, a source path for every component). Never
redefine a template here.

1. `mkdir -p docs/architecture/features`.
2. **Globals first, inline:** `README.md`, `overview.md`, `folder-structure.md`,
   `tech-stack.md`, `_shared.md`, `configuration.md`, `dev-guide.md`, in that order.
   `_shared.md` is then **frozen** for step 3.
3. **Feature docs — count, then branch, before writing the first one.** Announce it
   (`Fan-out: 6 features ≥ 3 → dispatching 6 agents.`):
   - **≥ 3 features** → one `general-purpose` Agent per feature, all in one message, the
     artifact variant of [`subagent-fanout.md`](../../references/subagent-fanout.md),
     `model: sonnet`, with the dispatch prompt and return schema in
     [references/as-built.md § Feature agent](references/as-built.md#feature-agent). Each
     writes only `docs/architecture/features/<slug>/index.md`.
   - **< 3** → write them inline; say so in one line.
4. **Collect** each `{slug, status, path, lines, gaps, shared_candidates}`. A failed or missing
   return → write that doc inline from the same prompt; never leave a feature without its doc.
   Report `shared_candidates` that recur in two or more docs as a `/ck-code:design optimize`
   suggestion. Never edit the frozen `_shared.md` after dispatch.
5. Fill the README's Feature Documents rows (orchestrator only), then run `ck-index`.
6. **Placeholder check** — a bracket that is neither a link, a checkbox nor
   `[TO BE DEFINED]`:

   ```bash
   grep -rnE '\[[^] x][^]]*\]([^(:]|$)' docs/architecture --include=*.md | grep -v 'TO BE DEFINED' | grep -v '/archive/'
   ```

   Every hit is reviewed. A template placeholder that was left in (`[Component Name]`,
   `[type]`) is replaced with real content or `[TO BE DEFINED]`, then the check re-runs.

## PHASE 6: SUMMARY & HAND-OFF

Print the summary block from [references/as-built.md § Summary](references/as-built.md#summary):
mode, files written, the dependency table, the gaps per doc, and **what to commit**. The
guard is useless until `.claude/ck-code-required.sh`, `.claude/settings.json`,
`tasks/VERSION.md`, `tasks/.gitignore` and `docs/architecture/` are committed. This skill
never commits; `/ck-code:ship` can.

Then hand off per [`skill-invocation.md`](../../references/skill-invocation.md) (DIRECT,
one question):

- **EXISTING** → `/ck-code:team`, which generates the expert and guide skills from the
  docs just written.
- **EMPTY** → `/ck-code:design <spec>` when a `docs/specs/*/spec.md` or a legacy spec file
  exists, else `/ck-code:spec`.
- **DOCUMENTED** → no hand-off. Name `/ck-code:design sync` and `/ck-code:team` as the next
  steps.

## RULES

- **Never write a spec** — no `docs/specs/` file and no spec Q&A. The code is the input; a
  gap is `[TO BE DEFINED]`.
- **Never invent architecture** — every component, endpoint, table and flow names the
  source path it was read from. Unread means `[TO BE DEFINED]`, never a plausible guess.
- **Never write a feature doc `design: pending`** — init documents shipped code, so every
  feature doc it writes is `design: built`. `pending` would make `plan` re-plan built work.
- **Never move, edit or delete a project's own docs** — they are read-only sources. The one
  exception is the confirmed archive `git mv` of a foreign `docs/architecture/` (Phase 1).
- **Never initialise over an older or newer layout** — the Phase 0 gate routes it to
  `migrate` or a plugin update first.
- **Never install, upgrade or authenticate a machine tool** — report it with its install hint.
- **Never write the feature docs inline at ≥ 3 features** — count and announce the dispatch
  decision before the first doc.
- **Never edit `_shared.md` after the feature agents are dispatched** — it is their frozen
  input; report shared candidates for `design optimize` instead.
- **Never commit or stage** — report the files to commit.
- **Always relay `ck-index: WARN` lines** and every non-OK `ck-bootstrap check` line.
- **Always output in English**, whatever the language of the code comments or source docs.
