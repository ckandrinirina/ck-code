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

## `/code-review` — the review pass before `ship`

`/code-review` (alias `/review`) reviews the current diff, or a PR by number, and now takes an
**effort level**: `low`/`medium` return fewer high-confidence findings, `high`/`max` widen
coverage, and `ultra` runs a deep multi-agent review in the cloud. With no level it reuses the
last one you typed, so you set it once per session.

| ck-code phase | Suggested call |
|---|---|
| before `ship` on a size `S` story | `/code-review low --fix` |
| before `ship --promote` on an epic | `/code-review high` |
| a merged epic branch you want audited hard | `/code-review ultra` |

`--fix` applies the findings to the working tree; `--comment` posts them as inline PR comments.
It is user-triggered — a ck-code skill cannot launch it for you.

## `/tasks` — verify a fan-out actually used the right tiers

`/tasks` (and the agent detail dialogs) now show **the model and effort level each subagent ran
on**. That is the direct check on `subagent-fanout.md`'s tier table: after a `build` PARALLEL
MODE wave, open `/tasks` and confirm the mechanical units really landed on `haiku` and only the
escalated ones on `opus`. A wave where every row says `opus` means `model:` was omitted on
dispatch.

## `/loop` — repeat a command on an interval or self-paced

`/loop <interval> <command>` re-runs a prompt or slash command on a schedule; omit the interval
and Claude paces itself. Useful for watching a long `build --epic` wave or re-running
`/ck-code:doctor` while a migration settles. Its cost shows up per-loop in `/usage`.

## Other native commands worth pairing

- **`/context`** — visual context-usage grid; run it before a long `build`/`plan` if you suspect bloat.
- **`/rewind`** — roll code+conversation back to a checkpoint; useful before a risky refactor in `build` Phase 6.
- **`/compact`** — compress history with a focus hint when a long session nears capacity.
- **`/effort`** — your baseline level. It is now saved **per model**, so switching models keeps
  each one's setting. A skill's own `effort:` frontmatter still overrides it for that turn.
- **`/config` → Output style "Concise"** — built-in style that leads with results and skips
  narration. Pairs well with `track`, `guide`, and `explain`, which are already terse by design.
- **`/plugin`** — where ck-code's own settings live (model-tier overrides; see `userConfig` in
  `plugin.json`). Set them there rather than exporting `CK_MODEL_*` by hand.

## What ck-code already does for you (do not re-do it manually)

| You might reach for | ck-code already does it |
|---|---|
| Approving each `git`/`gh` call during `build`/`ship` | `allowed-tools` pre-approves them for the invoking turn |
| `cat tasks/VERSION.md` before a skill runs | injected into the skill at load time via `` !`…` `` — Phase 0 costs no turn |
| `git commit` without an AI trailer | a skill-scoped `PreToolUse` hook blocks the commit if one is present |
| Tracking which build phase you are in | `TodoWrite` — one todo per phase, updated as it runs |
| Setting a subagent's effort or cache TTL | ck-code's registered agents pin `effort:` and `experimental.cacheTtl:` in their own frontmatter — `story-implementer` and `qa-validator` hold a 1-hour prompt cache so a repeated wave dispatch does not re-cache |
