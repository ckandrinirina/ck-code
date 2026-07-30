# Native Claude Code commands — when to reach for them

These are **built-in Claude Code commands** (not ck-code skills). ck-code skills
can recommend them, but cannot toggle them on your behalf — you type them. Use this
map to combine ck-code's structured workflow with Claude Code's native power.

## `/goal` — autonomous, criteria-driven completion (CC ≥ 2.1.139)

`/goal` sets a verifiable completion condition and keeps Claude working across turns
until a fast/cheap verifier model confirms it holds — no manual re-prompting. A story's
**Acceptance Criteria** are already a goal condition.

| ck-code phase | Suggested `/goal` |
|---|---|
| `build` QA / manual-test loop (Phase 7–8) | `/goal "all acceptance criteria in <story> pass and the full test suite is green"` |
| `build` Bug-Fix Mode (a `bug` story's recorded fix) | `/goal "the fix-written reproduction test passes and the full suite stays green"` |
| `build` PARALLEL MODE wave | `/goal "every story in epic NN reaches done with green tests"` |

Token note: the verifier runs on a cheap model, so `/goal` is *cheaper* than re-prompting
each turn yourself. One goal per session; run `/goal` with no argument to see turns/tokens spent.

## `/fast` — faster Opus output (user toggle only)

`/fast` (or `"fastMode": true` in `~/.claude/settings.json`) routes through a faster
serving path — same Opus model (available on Opus 5 and 4.x), quicker output. **A plugin
cannot enable it for you.** Use it intelligently:

| Situation | `/fast`? |
|---|---|
| Small / mechanical: size `S` story, simple `fix`, `plan --quick`, `track`, `guide`, `explain` | ✅ **On** — deliberation not needed |
| Big / complex: `design`, `plan`, `spec`, size `M` SOLID-heavy `build`, architecture | 🧠 **Off** — keep full reasoning |

The skill-side lever that *is* automatic is `effort:` frontmatter — every ck-code skill sets
it (`low` for `track`/`guide`/`explain`/`doctor`, `high` for `design`/`plan`/`spec`/`build`).
The read-only skills additionally pin `model: haiku`, so they cost a cheap model regardless
of your session model. Neither lever can reach `/fast`, which is a serving path, not a model.

## Other native commands worth pairing

- **`/code-review` / `/code-review --fix`** — deeper read-only diff review before `ship`; `--fix` applies findings.
- **`/context`** — visual context-usage grid; run it before a long `build`/`plan` if you suspect bloat.
- **`/rewind`** — roll code+conversation back to a checkpoint; useful before a risky refactor in `build` Phase 6.
- **`/compact`** — compress history with a focus hint when a long session nears capacity.
- **`/plugin`** — where ck-code's own settings live (model-tier overrides; see `userConfig` in
  `plugin.json`). Set them there rather than exporting `CK_MODEL_*` by hand.

## What ck-code already does for you (do not re-do it manually)

| You might reach for | ck-code already does it |
|---|---|
| Approving each `git`/`gh` call during `build`/`ship` | `allowed-tools` pre-approves them for the invoking turn |
| `cat tasks/VERSION.md` before a skill runs | injected into the skill at load time via `` !`…` `` — Phase 0 costs no turn |
| `git commit` without an AI trailer | a skill-scoped `PreToolUse` hook blocks the commit if one is present |
| Tracking which build phase you are in | `TodoWrite` — one todo per phase, updated as it runs |
