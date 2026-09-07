---
name: vendor
description: Use when a project should carry ck-code itself instead of depending on an installed plugin, so a clone on another machine runs every /ck-code:* command with no marketplace. Also use when the vendored copy needs syncing to a newer release, when a teammate reports ck-code commands are missing, or when every /ck-code:* command appears twice because two copies of the plugin are live. Argument is `install`, `update`, `check`, `status`, `dedupe`, `gitignore` or `remove`.
argument-hint: "[install | update [--to vX.Y.Z] | check | status | dedupe | gitignore | remove]"
effort: low
allowed-tools: Bash(ck-vendor*) Bash(git add*) Bash(git status*) Bash(git diff*) Bash(git commit*) Read Skill
---

# Vendor — Ship ck-code Inside the Project

Copies the plugin into `<project>/.claude/skills/ck-code/` and commits it, so the
project stops depending on whatever is installed on the machine that opens it.

**Why this works.** Claude Code adopts any directory under `<project>/.claude/skills/`
that contains `.claude-plugin/plugin.json` as a full project-scope plugin with the id
`ck-code@skills-dir`. Its skills, agents, hooks and `workflows/` all register, `bin/`
joins the Bash PATH, `${CLAUDE_PLUGIN_ROOT}` resolves to the vendored folder, and it is
**enabled by default** — no `/plugin install`, no marketplace, no network. Commands keep
their exact names (`/ck-code:build`, agent `ck-code:story-implementer`) because the
namespace comes from `plugin.json`'s `name`, not from where the folder sits.

The mechanical work lives in `scripts/ck-vendor.sh`. This skill runs it, judges what its
output means, asks before the one irreversible-looking edit, and commits the result.
Never re-implement a step of it in prose.

## VERSION GATE

**Never gates.** This skill touches `.claude/` and `.gitignore` only — never `tasks/` or
`docs/` — and a pre-v6 project on a machine with no plugin must be able to vendor first
and run `/ck-code:migrate` second. See [`version-gate.md`](../../references/version-gate.md).

## INPUT & MODE

Parse `$ARGUMENTS`:

| Argument | Mode |
|---|---|
| empty, `status` | **STATUS** (Phase 1) — read-only |
| `install` | **INSTALL** (Phase 2) |
| `update` (optionally `--to vX.Y.Z`) | **UPDATE** (Phase 3) |
| `check` | **STATUS**, but run `ck-vendor check --online` instead |
| `dedupe` | **DEDUPE** (Phase 4) |
| `gitignore` | **GITIGNORE** (Phase 5) |
| `remove` | **REMOVE** (Phase 6) |

## PHASE 1: STATUS

```bash
ck-vendor status
```

Return the output verbatim, then read the rows:

| Row | What it means |
|---|---|
| `vendored no` | the project depends on an installed plugin — offer INSTALL |
| `duplicates RISK` | a marketplace copy loads beside the vendored one, so every `/ck-code:*` command is listed twice — run DEDUPE |
| `installed <scope> <version>` | the marketplace copies that apply to this workspace. Two enabled scopes is the duplicate cause; a `project`/`local` scope pinned to an older version is why the project never got the current release |
| `git IGNORED` | the vendored copy will not be committed, so it will **not** travel — run GITIGNORE |
| `git not committed yet` | vendored but unstaged; nothing travels until it is committed |
| `local edits N` | those files differ from the release. `update` preserves them; `install --force` discards them |
| `auto-check` | whether the SessionStart hook probes for new releases (`false` silences it) |

## PHASE 2: INSTALL

```bash
ck-vendor install
```

This vendors the **running** plugin version, writes the file digests it will need to
update intelligently later, and pins both plugin ids in `.claude/settings.json` so
exactly one copy stays live. It refuses to overwrite an existing vendored copy — for that
the user wants UPDATE, or `install --force` to re-baseline from the running version and
discard local edits.

Then handle the `.gitignore` finding it reports, per Phase 5, and commit:

```bash
git add .claude/skills/ck-code .claude/settings.json .gitignore
git commit -m "chore(ck-code): vendor ck-code <version> into the project"
```

Close by telling the user the two things only they can do:

- **This session** — run `/reload-plugins` so the vendored copy loads now.
- **A fresh clone** — accept the workspace trust dialog once, then `/reload-plugins`.
  Until trust is accepted, Claude Code skips project-scope plugin directories entirely
  and no `/ck-code:*` command exists.

## PHASE 3: UPDATE

```bash
ck-vendor update
```

It resolves a source on its own — the local plugin cache when that is newer, otherwise
the newest published release, downloaded. `--to vX.Y.Z` pins an exact release;
`--offline` refuses to reach the network.

Read the per-file markers back to the user:

| Marker | Meaning |
|---|---|
| `+` | new file in the release |
| `+ (restored)` | a file the release still ships that had gone missing locally |
| `~` | updated |
| `-` | removed by the release |
| `!` | **you had edited this file — it was left exactly as it was** |

Every `!` is a decision the user must make. Show the diff and let them choose:

```bash
git diff -- .claude/skills/ck-code
```

- Keep the edit → nothing to do; the next update reports it again.
- Take the release version → `ck-vendor install --force` re-baselines the whole tree
  from the running plugin, discarding **all** local edits. Say that plainly before running it.

Commit, then tell the user to run `/reload-plugins`.

## PHASE 4: DEDUPE

```bash
ck-vendor dedupe
```

`ck-code@skills-dir` and `ck-code@ck-marketplace` are different plugin ids, so nothing
makes one shadow the other — both load and every command appears twice. Project settings
override user settings, so pinning the marketplace id off in the committed
`.claude/settings.json` fixes it for every machine that clones the repo, not just this one.

Commit `.claude/settings.json`, then `/reload-plugins`.

## PHASE 5: GITIGNORE

A project that ignores `.claude/` silently defeats the whole point: the vendored copy is
never committed, so the next clone has no plugin. Report it and get a decision — **never
edit `.gitignore` without asking first.**

```bash
ck-vendor gitignore
```

It prints the exact replacement block. Show it, explain the one thing that is not
obvious — git cannot re-include a path underneath an excluded directory, so a bare
`.claude/` cannot be negated and has to become the per-child form — and confirm that the
new rules keep everything else in `.claude/` ignored, plus the `settings.json` the
anti-duplication pin lives in. On a yes:

```bash
ck-vendor gitignore --fix
```

If the rule lives anywhere but the project's own `.gitignore` — a global excludesfile,
`.git/info/exclude` — the script reports and stops. That file is not this project's to
rewrite; hand the user the rules and let them place them.

## PHASE 6: REMOVE

```bash
ck-vendor remove
```

Deletes the vendored folder and the settings keys, returning the project to the installed
plugin. If it warns that local edits will be deleted, stop and show them first — that
content exists nowhere else.

Afterwards ck-code loads from the marketplace again, which means **the project stops being
portable**. Say so, and name the install command for a machine that has no ck-code:
`/plugin marketplace add ckandrinirina/ck-code`.

## RULES

- **Never edit `.gitignore` without an explicit yes** (Phase 5) — show the block, explain it, then apply. It is the one edit here that changes a file the user wrote for their own reasons.
- **Never run `install --force` or `remove` without naming what is lost** — both discard local edits to vendored files, and no other copy of those edits exists.
- **Never hand-copy, hand-patch or hand-delete anything under `.claude/skills/ck-code/`** — the digest baseline in `.ck-vendor.sums` is what makes an update able to tell a release change from a user edit, and a copy made outside `ck-vendor` leaves it lying.
- **Never edit `.claude/settings.json` by hand to fix duplicates** — `ck-vendor dedupe` writes both ids and preserves every other key in the file.
- **Never claim the project is portable until the vendored copy is committed** — `git IGNORED` or `not committed yet` in STATUS both mean a fresh clone gets nothing.
- **Never promise the vendored copy works in the current session** — a newly vendored or updated plugin needs `/reload-plugins`, and a fresh clone needs the workspace trust dialog accepted first.
- **Never restate a `ck-vendor` check in prose** — the script defines what is true; this file interprets it.
- **Never return the script output summarised away** — print it, then interpret.
- **Always output in English.**

## NEXT

End with one directive line per [`skill-invocation.md`](../../references/skill-invocation.md):
`NEXT: /ck-code:track` once the project is vendored and committed, or the single
`ck-vendor` command that clears the most severe row STATUS reported.
