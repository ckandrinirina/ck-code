---
name: update-skill
description: >
  Use when creating a new skill, agent, or references file in ck-code or ck-tools,
  or updating an existing one. Covers design, token-efficiency review, and full
  marketplace release (version bump, tag, GitHub Release).
argument-hint: "[skill-name or agent-name]  # e.g. parallel-build or conflict-analyzer"
---

# Update Skill — Create or Update Skills & Agents, Then Release

Creates or updates skills/agents in this plugin project following project conventions,
verifies token efficiency, then publishes a versioned marketplace release.

References:
- `references/templates.md` — frontmatter template, commit & release formats

## INPUT

`$ARGUMENTS` is an optional name of the skill or agent to create/update.
- If provided: locate the file and enter edit mode (skip interactive prompt).
- If empty: ask the user what to create/update and in which plugin.

## PHASE 1: DISCOVER

### 1.1 Identify Target

Determine what is being created or updated:

| Target type | Path |
|---|---|
| Skill (ck-code) | `ck-code/skills/<name>/SKILL.md` |
| Skill (ck-tools) | `ck-tools/skills/<name>/SKILL.md` |
| Agent | `ck-code/agents/<name>.md` |
| References file | `ck-code/skills/<name>/references/<file>.md` |

If `$ARGUMENTS` is provided, locate existing files:

```bash
find /Users/admin/Dev/ck-claude-plugins -name "*.md" | grep -i "$ARGUMENTS"
```

### 1.2 Read Existing (Edit Mode)

If editing, Read the target file fully before proposing any changes. Never edit
from memory.

### 1.3 Confirm Scope

State: the exact file path, create vs. update, and a one-sentence summary of
the planned change. Wait for user confirmation before writing.

## PHASE 2: WRITE OR EDIT

### 2.1 Skill Conventions

All skills follow these conventions (copy-paste template in `references/templates.md`):

**Frontmatter** — required: `name`, `description`. Optional: `argument-hint`,
`disable-model-invocation`, `allowed-tools`. Total ≤ 1024 chars.

**Description rules:**
- Third-person, starts with `"Use when …"`
- Triggering conditions only — never summarize phases or workflow steps
- If the description can answer "what does it do?", rewrite it

**Body structure:**
- Complex workflows → `## PHASE N: TITLE` with `### N.1` subphases
- Static data / examples / templates → offload to `references/`
- Close with `## RULES` block: absolute constraints (`Never X`, not `Try to avoid X`)

### 2.2 Agent Conventions

Agents in `ck-code/agents/` are lightweight delegation targets:

- Frontmatter: `name`, `description`, `tools` list only
- Three mandatory sections: **Inputs**, **Outputs**, **Constraints**
- Constraints must include: "Never commit or push"
- No phases, no release logic — agents execute one focused task

### 2.3 Write the File

Write or Edit the target file. For new skills, create the `references/` subfolder
if heavy reference material (templates, examples, format specs > 50 lines) is needed.

## PHASE 3: TOKEN EFFICIENCY REVIEW

Run these checks before marking the skill ready. Fix every issue found.

1. **Description ≤ 500 chars and workflow-free** — no phase names, no step summaries
2. **No duplication** — same instruction does not appear in both SKILL.md and references/
3. **Heavy data offloaded** — static tables, templates, or examples > 50 lines live in references/
4. **Rules are absolute** — `"Never X"` not `"Try to avoid X"` or `"Consider X"`
5. **Bash examples use real commands** — no pseudo-code, no `<placeholder>` values
6. **Size target met** — simple skills ≤ 150 lines; complex multi-phase skills ≤ 350 lines

If a check fails, fix inline before proceeding to Phase 4.

## PHASE 4: RELEASE

### 4.1 Determine Plugin and Bump Type

| Where the change lives | Plugin to bump |
|---|---|
| `ck-code/skills/` or `ck-code/agents/` | `ck-code/.claude-plugin/plugin.json` |
| `ck-tools/skills/` | `ck-tools/.claude-plugin/plugin.json` |

| Change type | Semver bump |
|---|---|
| New skill or agent | minor (X.**Y+1**.0) |
| Update to existing skill/agent | patch (X.Y.**Z+1**) |

Read the current version before bumping:
```bash
grep '"version"' /Users/admin/Dev/ck-claude-plugins/<plugin>/.claude-plugin/plugin.json
```

### 4.2 Commit Feature

Stage only the changed skill/agent files:

```bash
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> add skills/<name>/ # or agents/<name>.md
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> commit -m "<type>(<name>): <description>"
```

Conventional types: `feat` (new), `fix` (bugfix/correction), `docs` (docs-only),
`refactor` (restructure without behavior change). See `references/templates.md`
for examples.

### 4.3 Bump Version in plugin.json

Edit `<plugin>/.claude-plugin/plugin.json` — increment `"version"` to `X.Y.Z`.

```bash
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> add .claude-plugin/plugin.json
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> commit -m "chore(release): bump version to X.Y.Z"
```

### 4.4 Tag, Push, and Release

```bash
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> tag vX.Y.Z
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> push origin main --tags
```

Create the GitHub Release (a tag alone is not visible in the marketplace):

```bash
gh release create vX.Y.Z --repo ckandrinirina/<plugin> \
  --title "vX.Y.Z" \
  --notes "$(cat <<'EOF'
### <Feat|Fix|Refactor>

- **<skill-name>**: <what changed and why in one sentence>
EOF
)"
```

Verify release is live:
```bash
gh release list --repo ckandrinirina/<plugin> | head -3
```

## RULES

- **Never skip Phase 3** — every skill ships to production users; token efficiency is not optional.
- **Never push a tag without creating a GitHub Release** — a tag alone is invisible in the marketplace.
- **Never modify marketplace.json** to add a plugin entry without explicit user instruction.
- **Always use conventional commits** — `feat:`, `fix:`, `docs:`, `refactor:`, `chore(release):`.
- **Never add "Co-authored by Claude"** or generated-by notes to commits or PRs.
- **Description must not summarize workflow** — it is a trigger condition, not a readme.
- **Agents never commit or push** — agents are invoked by skills, not autonomous actors.
