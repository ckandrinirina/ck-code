# Parallel Mode — Orchestration Detail (P1–P9)

Detail for `SKILL.md` § PARALLEL MODE. Read when two or more stories are in scope, when
`--epic NN` orchestrates a single remaining story, or for the sections SINGLE-STORY DISPATCH
links (P3 team gate, P5 solo integrity, model tier, affected tests). The orchestrator decides, verifies, and
merges; it never builds, tests, or reads source.

Companions: [agent-prompts.md](agent-prompts.md) (prompts + return schema) ·
[wave-mode.md](wave-mode.md) (wave planning) ·
[conflict-format.md](conflict-format.md) (every report shape).

## Two dispatch shapes

Every story here is implemented by a dispatched agent. What changes with wave width is
**isolation**, and everything downstream of it:

| Wave width | Shape | Isolation | P6 conflicts | P8 merge |
|---|---|---|---|---|
| ≥ 2 stories | **fan-out** | one worktree per story | runs | merge each branch into `$TARGET` |
| exactly 1 story | **solo** | none — the main checkout | skipped (no peer branch) | nothing to merge across branches |

Solo keeps the orchestrator/implementer split (this context still never builds or reads
source) while dropping the worktree, its cold dependency install, and the whole
conflict-and-merge stage that only exists because peers run concurrently.

**Where solo commits.** The agent works in the main checkout on `$TARGET`, which P1 has
already checked out. `$TARGET` is never a protected branch here — at `integration: story` P1
raises the level-switch gate instead of targeting the trunk (§ P1, § P3), so implementation
never lands on `main`/`develop` (forbidden project-wide, SKILL.md 3.5). The branch the solo
agent is placed on is called `$WORKBRANCH` below, and it is always `$TARGET`; the separate
name is what P5's drift guard and the dispatch prompt check against.

## The P-step map

What this context does at each step, and the one thing that must never bend. Every row is
detailed in its section below.

| Step | What this context does | Non-negotiable |
|---|---|---|
| **P1** | Resolve `$TARGET` from the plan's `integration:` level (`ck-plan get`; dirty tree or detached HEAD stops the run), **check it out — creating it if absent — and verify HEAD**, announce it with its reason and staleness, and resolve the story set from `STORIES_INDEX.md` | Never `Read` a story body; never dispatch before HEAD is on `$TARGET`; never merge into a hardcoded `main`, into whatever branch happened to be checked out, or into the trunk (level `story` → switch to `epic` or cancel at P3) |
| **P2** | Order the scope into waves by `Blocked by`, then split each wave so no two stories share a declared `files:` path | Print every excluded story with its reason |
| **P3** | Team gate (see § P3) + criteria ambiguity + the level-`story` switch when P1 raised it, folded into **one `AskUserQuestion`, ≤ 4 questions** — asked only when one of them is needed; the wave plan alone is printed, not asked. `--auto`: no question | Never dispatch with zero project skills without asking (unless `experts: none`) — agents cannot prompt |
| **P4** | Dispatch the wave: **fan-out** (≥ 2) = one worktree `Agent` per story in a single message; **solo** (= 1) = one `Agent` on `$WORKBRANCH`, no worktree. Both `subagent_type: "ck-code:story-implementer"`, stable name `story-EE-SS`, `MODE: delegated` | Every story goes to an agent; a worktree only when a peer runs beside it. Tier the model by reasoning complexity, never `size` |
| **P5** | Integrity **the moment an agent returns** → ✓ complete / ◐ incomplete (resume the same agent, cap 2) / ⚠ deletion review (ask accept-or-exclude) / 🚫 blocked | "Done" comes from git, never the agent's self-report |
| **P6** | `ck-code:conflict-analyzer` dry-runs each ✓ branch onto `$TARGET` and returns a merge order | Cross-branch by construction — the fan-out wave's one barrier. **Skipped entirely on a solo wave.** Every dry-run is aborted; nothing lands here |
| **P7** | One `ck-code:qa-validator` per ✓ story, launched as it clears P5 | Acceptable = ✓ complete + `QA: PASS` (+ conflict-free, fan-out only) |
| **P8** | Fan-out: merge in P6's order — without asking when every branch is ✓, `QA: PASS` and conflict-free. Solo: nothing to merge. Then `ck-index` + `ck-project sync` **once** (local; no view is committed), run `qa-validator` on `$TARGET`, then the SKILL.md 8.5 manual gate once for the wave (deferrable for the remaining waves; deferred under `--auto`) | Never accept work that has not passed P7; a deferred gate is listed at P9, never dropped |
| **P9** | Re-resolve the next wave from the regenerated index and loop from P3; when the epic is done, hand off to `/ck-code:ship --promote --epic NN` (one ask) | A held story keeps its branch (and worktree, if any) and holds its dependents; never tell the user to ship each story |

**P5 and P7 are pipelined, P6 and P8 are barriers.** P5 and P7 judge one story against
itself, so each walks them as soon as its agent returns — the fastest story's QA runs
while the slowest is still coding. P6 derives an order from the overlaps *between* branches
and P8 merges into a moving `$TARGET`; neither can start on a partial set. Barriering P5 or
P7 on the whole wave is the single largest avoidable delay in this mode. On a solo wave the
pipeline collapses to one story and P6 does not run at all.

## Auto mode — `--auto`

`--auto` runs one epic to the end with **no `AskUserQuestion` at all**. Every question below
takes its row here, announced in one line (`Auto: <decision>`) where it would have been asked.

| Question | Auto decision |
|---|---|
| P1 `$TARGET` behind origin | `git merge --ff-only origin/$TARGET`; diverged → hard stop, never a merge commit |
| P3 level switch (level `story`) | **Switch this plan to epic level**: it is local, and the run cannot land anywhere else |
| P3 team gate | **Continue without experts this time**, named in the final report. `/ck-code:team` is interactive, so it is never run from here |
| P3 wave-plan confirmation | every story kept |
| P3 criteria ambiguity | the narrowest reading that matches the literal criterion and the existing code, passed to the agent as `Settled: assumed <reading>` and listed in the report |
| P3 design pending | build without it; each UI story is named in the report |
| P5 ⚠ deletion review | **Exclude this story** (branch kept, reported), never accepted unseen |
| P7 a story without `QA: PASS` | held (fan-out) or the run stops (solo), as below; never asked |
| P8 merge | merge every eligible branch (the default already) |
| P8 post-wave `QA: FAIL` | hard stop: branches kept, nothing reverted, reported |
| P8 manual gate | **deferred**: the wave completes as on PASS so its dependents schedule; its steps go into the final checklist |
| P9 hand-off | **Not yet**: nothing is promoted, shipped or pushed |

Everything else is unchanged: the integrity gate, `QA: PASS` before any merge, the post-wave
area-scope QA, held branches never merged. A hard stop (dirty tree, branch drift, a red post-wave
QA, a resume cap reached on every story) still ends the run. It is reported, never asked. A
project with no manifest row for its QA commands is refused before P1 writes anything
(`--auto needs QA commands`).

The final report adds a **Manual test checklist**: the 8.5.1 steps for every story completed
this run, the `assumed` readings, and the excluded or held stories with their reasons. It ends
with `/ck-code:verify --epic NN` (the guided manual test) and `/ck-code:ship --promote --epic NN`
for once it passes. A problem found there is a bug for `/ck-code:fix`, never a reopened run.

## P1 — Freeze the target and resolve scope

```bash
git status --porcelain && git branch --show-current
```

A dirty tree or a detached HEAD stops the run — say which and stop.

The level is the **plan's**, read once from its record (this mode never asks for it):

```bash
ck-plan get tasks/<Plan> integration branch
```

`$TARGET` is `resolve_parent(epic NN)`
([`branch-topology.md`](../../../references/branch-topology.md#resolution)) — **not** whatever
branch is currently checked out. At `epic` and `plan` it is `epic/<NN>-*` (at `plan` that epic
branch is cut from the plan branch, the record's `branch:`); at level `story` (or an empty
`integration:`) it resolves to the default branch, which this mode never uses as `$TARGET`
(level-switch gate below). This mode is already scoped to a single epic, so exactly one
`$TARGET` resolves. Every later phase merges into it, never a hardcoded `main`.

**Level `story` — switch or cancel before anything is dispatched.** This mode records the wave
on `$TARGET` (P4 commits there) and merges into it (P8), and **neither may ever happen on the
trunk**. So when `resolve_parent` returns the default branch, do not check it out and do not
plan a dispatch: carry the switch into P3's single question — **Switch this plan to epic
level** (`ck-plan set tasks/<Plan> integration=epic`, create `epic/<NN>-<slug>` from
`<trunk>`, and that branch becomes `$TARGET`) or **Cancel** (the stories stay untouched;
build them one at a time, each by SINGLE-STORY DISPATCH). P2 may be planned meanwhile; nothing is dispatched until
the answer lands.

**Check out `$TARGET` and verify HEAD, before the announce.** Creating it when absent is part
of this step ([Creation](../../../references/branch-topology.md#creation) builds the chain
top-down, so at level `plan` the plan branch — the record's `branch:` — comes first):

```bash
git fetch origin --quiet
git branch "$TARGET" "<parent per branch-topology Creation>"   # only if absent
git checkout "$TARGET"
git rev-parse --abbrev-ref HEAD                                 # must print $TARGET
```

HEAD anywhere else stops the run — every later step assumes it: P4 commits the wave marker
there, fan-out worktrees are cut from its HEAD, P8 merges into it, and the post-wave QA and
manual gate run on it.

**Announce it, with its reason** — one line, before any wave is planned, so a run launched on
an unrelated branch is visible rather than surprising at merge time:

```
Target: epic/02-payments — level epic, all 4 stories land in epic 02's single PR
        (current branch story/01-03-login is not the target)
```

Then check staleness once for the whole run — the fetch above already ran
(`git rev-list --count $TARGET..origin/$TARGET`). When it is behind, say so on a second line
and carry the **Sync `$TARGET` from origin first** option into P3's single question — never a
prompt of its own, never a silent merge. If `$TARGET` already has an open PR (`EPIC.md` `pr:`),
add one line naming it: every story of this run lands inside PR #`<n>`.

Resolving the scope set, by argument shape:

| `$ARGUMENTS` | Scope |
|---|---|
| Story IDs (`02-05 02-07`) | exactly those stories; skip the epic gate — explicit scope is always respected. Every ID must share one epic (`EE`): a set spanning more than one epic is **refused** — list the epics it touches, say to run one `build` per epic, and stop. A run merges into one epic branch, so a cross-epic set has no single target |
| `--epic NN` | every story of epic `NN` that is neither `DONE` nor `SKIP`; skip the epic gate |
| Empty (menu route) | the set the SKILL.md 1.2 menu already resolved — do not re-derive it |

**Resolve the plan from the number, never by asking.** Epic numbers are unique across
every plan ([`data-model.md`](../../../references/data-model.md#epic-and-story-numbers-are-globally-unique)),
so an `--epic NN` — or the `EE` of any story ID — names exactly one plan folder:

```bash
find tasks -mindepth 3 -maxdepth 3 -type d -path 'tasks/*/epics/NN_*'
```

- exactly one match → its `tasks/<Plan>/` is the plan; proceed
- no match → say which epics exist (`ck-index` output) and stop
- more than one match → the project has colliding epic numbers. **Stop** and tell the user
  to run `/ck-code:migrate`; never pick one, and never ask which — a wrong guess here
  builds the wrong story onto the wrong branch

Then read that `tasks/<Plan>/STORIES_INDEX.md` (the generated, gitignored view) to map IDs
to file paths and `Blocked by` sets; regenerate it with `ck-index tasks/<Plan>` first if it
is missing or lacks the `GENERATED by ck-code` header. **Never `Read` an individual story
body in this phase** — the index is the only discovery source.

A story is **ready** when `status: todo` and every `blocked_by` story is `done` or `skip`,
or when `status: bug` (a triaged bug from `/ck-code:fix`; the dispatched run enters Bug-Fix
Mode). A story is **dispatchable** when it is ready, or when it is `IN PROGRESS` inside the
explicit scope (resumed, never re-started). If nothing in scope is dispatchable, list the
still-blocked rows with their unmet blockers and stop.

An `IN PROGRESS` story is not ready, but an explicit scope names it, and it is the state an
interrupted run leaves behind: P4 flips the wave's stories before dispatching them, and a
wave that aborted mid-flight must re-dispatch on the next `--epic NN` rather than strand its
own stories. It is also the state a reverted story returns to ([wave-mode.md](wave-mode.md)
step 4).

**One story in scope from anything other than `--epic NN`** — an explicit story path, a lone
story ID, a single-story pick from the 1.2 menu — **is never orchestrated here**: hand it to
SKILL.md Phase 1.3 and on to SINGLE-STORY DISPATCH (still one solo agent, on the story's own
branch, so the plan's level is never switched for it).
**`--epic NN` always orchestrates**, even when one story remains: it dispatches that story
solo at P4 (no worktree), because an epic run keeps the orchestrator's context clean and lands
every story the same way on `$TARGET`.

## P2 — Plan the waves

```bash
ck-view waves --epic NN
```

One call plans the whole epic: it orders the scope into dependency waves from `Blocked by`,
splits each wave so no two stories in it share a declared `files:` path, labels every wave
`(parallel)` or `(solo)`, and prints the wave plan table
([conflict-format.md](conflict-format.md)) already formatted — plus every `UNSCHEDULABLE`
story with the blocker that holds it, and the un-startable case. Relay that table; do not
re-derive it. The algorithm it implements is [wave-mode.md](wave-mode.md).

Dependency ordering and file-conflict grouping are graph and set problems: reasoning them
out per run costs tokens for an answer that is either exactly right or silently wrong, and
a story dispatched beside its own blocker is the expensive kind of wrong.

This is a heuristic from *declared* scope; P6 still runs the authoritative dry-run merge on
*actual* diffs.

## P3 — Team gate and confirmation

```bash
ls .claude/skills/expert-*/SKILL.md .claude/skills/guide-*/SKILL.md 2>/dev/null
```

Empty output means `/ck-code:team` has never run and every dispatched agent would write
generic code with no project experts, guides, or QA rules. When `tasks/SETTINGS.md` sets
`experts: none` the gate never fires — dispatch as-is. Otherwise warn per
[`skill-detection.md`](../../../references/skill-detection.md) § 4a.1: **Run /ck-code:team
first** (recommended) → `Skill({ skill: "ck-code:team" })`, then dispatch with the generated
skills in place; **Continue without experts this time** → dispatch as-is; **Never ask in this
project** → write `experts: none` to the `tasks/SETTINGS.md` frontmatter, then dispatch as-is.
Never dispatch without asking.

Fold that question, the wave-plan confirmation (`PROCEED` / `DROP A STORY` / `ABORT`), the P1
**Sync `$TARGET` from origin first** option when the target is behind, the P1 **level-switch**
question when the plan's level is `story`, the **design-pending** question when the wave holds a
UI story and the Claude Design link is still pending (once per run —
[`design-system.md` § Pending at build time](../../../references/design-system.md#pending-at-build-time)),
and any genuine acceptance-criteria ambiguity into
**one `AskUserQuestion`, at most 4 questions** — the dispatched agents have no user, so
ambiguity is resolved here or not at all. **The wave plan alone never triggers the call.** An
explicit scope (`--epic NN`, story IDs, or the SKILL.md 1.2 menu pick) already confirmed it, so
print the plan and dispatch. Add the `PROCEED` / `DROP A STORY` / `ABORT` question only when
one of the others is being asked anyway. Under `--auto` nothing is asked
([§ Auto mode](#auto-mode----auto)). When the slots are contended the level-switch question wins, then the
team gate and the sync offer — without a target there is nothing to dispatch, and the other
two change what every dispatched agent starts from.

**The level-switch question (level `story` only).** "Plan `<Plan>` is `integration: story`, so
its target would be `<trunk>` — this mode never commits or merges there. How should it land?"
It offers exactly these two options, never a path into the trunk:

- **Switch this plan to epic level** (recommended) — record it, then run P1's checkout for
  the new target:

  ```bash
  ck-plan set tasks/<Plan> integration=epic
  git branch "epic/<NN>-<slug>" "<trunk>"     # only if absent
  git checkout "epic/<NN>-<slug>"
  ck-project sync tasks/<Plan>
  ```

  `epic/<NN>-<slug>` becomes `$TARGET` for the whole run, and every story of the epic lands in
  that one PR. The switch is plan-wide and applies from here onward, never retroactively —
  say so when stories of the plan are already merged. `OVERVIEW.md` is now modified; the P4
  wave-start commit records it.
- **Cancel** — dispatch nothing and leave every story's status exactly as it is; a
  `story`-level plan is built one story at a time (SKILL.md SINGLE-STORY DISPATCH), each on
  its own `story/…` branch with its own PR.

Never synthesize an epic branch without this answer, and never fall back to the trunk.

## P4 — Dispatch

### Mark the wave in progress (before any worktree is cut)

On `$TARGET`, set `status: in-progress` in the frontmatter of every story dispatching in
**this wave** — never the whole run; a later wave's stories stay `todo` until their turn.
Skip any story already `in-progress` (a resumed wave) or `bug` (Bug-Fix Mode owns that
status and restores it at Phase 8.6).

```bash
ck-story set status=in-progress <story-path>… --no-board
git status --porcelain tasks/          # empty → nothing to record; skip the two commands below
git add <the story files just edited> [tasks/<Plan>/OVERVIEW.md — only after a P3 level switch]
git commit -m "chore(tasks): mark wave <N> in progress"
ck-project sync tasks/<Plan>
```

The commit holds **story files only** (plus `OVERVIEW.md` when P3 switched the level) —
never a view: `STORIES_INDEX.md` and `EPICS_INDEX.md` are gitignored. It exists because the
merge needs a clean target that already reads `in-progress`. One `ck-story` call takes every
story of the wave and regenerates once. `--no-board` holds the card sync back until after
the commit, so the board never advertises a wave that is not yet recorded on `$TARGET`.

**A resumed wave usually changes nothing.** `ck-story` reports one line per story, and
`<id>: already current — no change` means that story was already `in-progress`. When every
story reports it, there is nothing to stage: skip the `git add`/`git commit` and go straight
to the sync. Otherwise the porcelain check above is the gate. Never run `git commit` on an
empty index; it exits non-zero and reads as a failed wave.

One commit and one sync per wave, whatever the wave's width. This is the only place
In Progress can be expressed: a dispatched agent writes `in-progress` inside its own
worktree branch, which `$TARGET` never sees until the merge already made it `done`. Because
the worktrees are cut *after* this commit, every agent branches from a tree that already
reads `in-progress`, so its story-cycle 1.6 edit is a no-op and its 8.6 write of `done` touches
the same line on its own branch — no merge conflict either way. The epic card rolls up to
In Progress automatically, since `role_for_epic` reports `in_progress` when any story is
([`github-projects.md`](../../../references/github-projects.md)).

A board failure here is reported and never stops the dispatch.

### Claim the linked issues (same pass)

Assign the issues this wave will touch to the account running the build, so GitHub shows who
owns the work while it is in flight:

```bash
gh issue edit <story issue> --add-assignee @me   # each dispatched story whose issue: is set
gh issue edit <epic issue>  --add-assignee @me   # --epic NN scope only, once per run
```

Story numbers come from each dispatched story's `issue:` (empty → skipped); the epic number
from the epic's `EPIC.md` `issue:`, and **only when the run's scope is `--epic NN`** — an
explicit story-ID run claims those stories and nothing else. `--add-assignee` is additive, so
an existing assignee is never removed and a resumed wave re-running it changes nothing. Like
the board sync, a failure here is reported and never stops the dispatch — and the dispatched
agents skip the claim themselves (SKILL.md 1.5).

### Shape

Count the wave's stories first — that count, and nothing else, picks the shape.

### Fan-out (wave holds ≥ 2 stories)

Announce the decision first, in one line: `Fan-out: N stories → dispatching N agents.`
(an unannounced dispatch is indistinguishable from a forgotten one). Then dispatch every
story of the wave in a **single message** — one `Agent` call each, all in one turn, so
they run concurrently. Per story (full prompt: [agent-prompts.md](agent-prompts.md)):

- `isolation: "worktree"` — the harness cuts each agent its own git worktree from `$TARGET`;
  no manual `git worktree add`, no base-SHA pinning, no branch-collision guard. Changed
  worktrees persist for merge; unchanged ones auto-clean.
- `subagent_type: "ck-code:story-implementer"` (falls back to `general-purpose`).
- A stable **name** per agent (`story-EE-SS`) so P5 can resume it with `SendMessage`.
- A prompt beginning `MODE: delegated` that names the absolute path of
  [story-cycle.md](story-cycle.md), which the agent follows in place of the `build` skill
  (no branch question, no `ck-index`, no manual gate, no ship), and a
  `Base SHA:` line — `git rev-parse "$TARGET"` after the P4 commit, the commit every worktree
  is cut from — which the agent diffs against to record `files:` (story-cycle.md 8.6).
- Worktree agents flip their own story with `ck-story set … --no-sync`; `ck-story` also
  refuses the board sync by itself inside a story worktree, so no card can move before the
  merge.

### Solo (wave holds exactly 1 story)

One story has no peer to collide with, so it gets no worktree — the agent works in the main
checkout and its commits are already where they need to be.

1. **Resolve `$WORKBRANCH` — it is `$TARGET`.** P1 already created and checked it out, and
   its level-switch gate guarantees it is an `epic/…` branch, never the trunk.
   Re-verify with `git rev-parse --abbrev-ref HEAD` **here in the orchestrator, before
   dispatch** — never let the agent choose or change a branch.
2. **Record the base SHA** — `git rev-parse HEAD` on `$WORKBRANCH`. P5 has no second branch to
   diff against, so this SHA *is* the baseline. Capture it before the agent starts; it is also
   the prompt's `Base SHA:` line the agent records `files:` against.
3. **Announce**: `Solo: 1 story → dispatching 1 agent on <$WORKBRANCH> (no worktree).`
4. **Dispatch one `Agent`** — same `subagent_type`, same stable `story-EE-SS` name, same
   model tiering, same `MODE: delegated` prompt, but **no `isolation` field** and the extra
   branch guard from [agent-prompts.md](agent-prompts.md) § solo: the agent verifies
   `git rev-parse --abbrev-ref HEAD` is `$WORKBRANCH` before its first edit and never runs
   `checkout -b`, `switch -c`, `rebase`, `reset`, or `worktree`.

The tree must be clean at dispatch (P1 already enforced that) and stays the agent's alone
until it returns — never dispatch a solo agent while a fan-out wave is still in flight, and
never edit files in this context while one is running.

### Worktree dependency bootstrap (fan-out only)

A solo wave skips this section entirely — the main checkout already has its dependencies
installed, which is a large part of why solo is cheaper.

Every worktree is a bare checkout — no `node_modules`, no `target/`, no `.venv`. N agents
pay N cold installs and N cold compiles, routinely the largest slice of a parallel run's wall
clock. The rule: **share immutable caches, never a mutable install tree** — a peer that
changes a dependency must not be able to mutate another worktree mid-run.

| Stack | Share this | Never |
|---|---|---|
| npm / yarn | pnpm's global store — `pnpm install` links a per-worktree `node_modules` over one immutable content store | One `node_modules` symlinked into every worktree |
| Rust | `CARGO_TARGET_DIR=<absolute shared path>` — cargo file-locks it, so it is correct; concurrent builds then serialize on that lock, so measure before adopting | — |
| Python | `UV_CACHE_DIR` / `PIP_CACHE_DIR` pointed at one shared path | One `.venv` shared across worktrees |

**Gitignored config goes through `.worktreeinclude`.** A worktree also lacks every
gitignored file the suite reads, such as `.env` or local credentials, so each story's QA fails
on a missing file rather than on the story. List those files in a `.worktreeinclude` at the
repo root, in gitignore syntax. Claude Code **copies** each match into every worktree it
creates, and never links it, so no peer can change another worktree's copy. Never hand-copy
them in a dispatch prompt. `/ck-code:doctor` warns when a gitignored `.env` has no
`.worktreeinclude`. Dependency trees stay with the cache table above; `.worktreeinclude` is for
config, not for `node_modules/`.

Name the scheme in the dispatch prompt when the project has one, so every agent installs the
same way. With no scheme, say so in the launch announce — the cold installs are then the
expected cost, not a stall.

### Model tier — by reasoning complexity, never `size`

Default every story to **balanced → `model: sonnet`**. Escalate to **advanced → `model: opus`**
only on a clear high-reasoning signal (novel algorithm, concurrency/distributed correctness,
intricate state machine, security- or perf-critical path, non-obvious architecture); use
**fast → `model: haiku`** only for trivial mechanical changes. `size` reflects scope, not difficulty, so it never escalates on its own.

**Dispatch the alias, never the tier name** — `model:` takes only `haiku`,
`sonnet`, `opus` (`fable` needs the user's approval); `balanced`/`advanced`/`fast` are rejected. Full map:
[agent-prompts.md](agent-prompts.md#tier-map--write-the-alias-never-the-tier-name).

The operator can repoint any tier in `/plugin` → ck-code (`userConfig`); the resolved values
are substituted into [agent-prompts.md](agent-prompts.md#tier-map--write-the-alias-never-the-tier-name)
at load time. Print the resolved Story → Complexity → Tier → Model line in the launch announce
so a mis-resolution is catchable before work starts.

Create one Claude Task per story (`TaskCreate`, `Implement EE-SS: <title>`, wave-prefixed in
wave mode) as a live board when the Task tools are available; mark each `in_progress` at
dispatch and `completed` when it merges and passes its gate. `TaskList` at P5, P7, and P8.

## P5 — Integrity and resume

Verify each story **the moment its agent returns** — never hold a returned branch waiting on
the wave. The failure to catch is an agent that did nothing yet reported `done`. Same three
checks either way; only the baseline of the diff changes.

**Fan-out** — using the returned `branch` and the story path:

```bash
git diff --shortstat "$TARGET".."<branch>"                     # empty → 🚫 no implementation
git show "<branch>:<story path>" | grep -cE '^\s*-\s*\[ \]'    # >0 → criteria unmet
git diff --name-only --diff-filter=D "$TARGET".."<branch>"     # any → ⚠ unexpected deletion
```

**Solo** — there is no second branch, so diff against the base SHA recorded at P4, and also
confirm the agent left the tree clean and stayed on `$WORKBRANCH`:

```bash
git rev-parse --abbrev-ref HEAD                                # ≠ $WORKBRANCH → 🚫 branch drift
git status --porcelain                                         # non-empty → ◐ uncommitted work
git diff --shortstat <base-sha>..HEAD                          # empty → 🚫 no implementation
grep -cE '^\s*-\s*\[ \]' "<story path>"                        # >0 → criteria unmet
git diff --name-only --diff-filter=D <base-sha>..HEAD          # any → ⚠ unexpected deletion
```

Branch drift on a solo run is a hard stop, not a resume: the agent committed somewhere this
context did not sanction. Report the branch it landed on and stop the wave.

Classify (report format: [conflict-format.md](conflict-format.md)):

- **✓ complete** — non-empty diff, zero unchecked criteria, no unexpected deletion.
  Merge-eligible pending QA. (`criteria_met` from the return is a hint; the grep is the proof.)
- **◐ incomplete** — real diff but criteria still unchecked, or (solo) work left uncommitted
  (the agent ran out of budget). Not failed. **Resume the same agent** with `SendMessage`
  ([agent-prompts.md](agent-prompts.md)) — its context is intact, and so is its worktree
  (fan-out) or the main checkout it left behind (solo). Re-run this gate; cap **2 resume
  rounds**. Still
  incomplete after the cap, or a resume that makes zero new commits → flag `too large /
  stuck`, keep the branch, recommend splitting.
- **🚫 blocked** — empty diff: there is nothing to resume, so re-dispatch fresh via a new
  `Agent` call. Excluded from merge; branch kept; reported for review.
- **⚠ deletion review** — a real diff with its criteria checked that also deletes files.
  **Not blocked**: a story may legitimately delete code, and excluding it strands finished
  work. Print every deleted path and ask (`AskUserQuestion`): **Accept the deletions** → the
  story is ✓ complete and walks on to P7; **Exclude this story** → treat it as 🚫 blocked,
  keep the branch, report it. Never decide either way on the agent's behalf.

Never trust the agent's word; a story is done only when this gate and P7 QA agree.

## P6 — Conflict analysis (dry-run stage, before any merge)

**Skipped on a solo wave** — conflict analysis compares peer branches, and a solo wave has
none. Say so in one line (`Conflicts: skipped (solo wave).`) and go to P7.

**The fan-out wave's one barrier** — starts only once every branch has cleared P5, and runs
while the P7 QA already dispatched is still in flight. It never waits for QA.

**Guard the checkout first** — the dry-runs happen in the main checkout, so a wrong HEAD or a
dirty tree would either measure the wrong target or leave a half-merge behind:

```bash
git rev-parse --abbrev-ref HEAD    # must be $TARGET
git status --porcelain             # must be empty
```

Either check failing stops P6: fix the checkout (P1's `git checkout "$TARGET"`) or report the
dirty paths and stop — never dry-run from somewhere else. The agent repeats the same guard and
returns `order: []` with an error rather than probing, so an unguarded dispatch fails loudly.

Delegate the ✓-complete branches to `ck-code:conflict-analyzer` (falls back inline): it
dry-run `git merge --no-commit`s each branch onto `$TARGET`, classifies risk, and returns a
merge order (fewest overlaps first) — aborting every dry-run so nothing lands. Print the
conflict report ([conflict-format.md](conflict-format.md)); no overlaps → "all branches merge
cleanly." One branch → nothing to compare; skip.

## P7 — QA, one validator per story

Dispatch one `ck-code:qa-validator` agent (Haiku tier) per ✓-complete story **as soon as it
clears P5** — batch whatever cleared in the same turn into one message, but never hold a
cleared branch waiting on a slower peer (the P4 single-message rule governs the implementer
fan-out, not this one). QA judges one story's branch against itself, so it needs no other
branch. Each runs its stack's build/test/lint in its own cheap context and returns
a compact `QA: PASS` / `QA: FAIL — <cmd> — <excerpt>` verdict, keeping the heavy output off
this context (prompt: [agent-prompts.md](agent-prompts.md)).

**Solo wave:** dispatch the same validator **without `isolation`**, against `$WORKBRANCH` in
the main checkout — there is no worktree to check out and re-install. It stays read-only, so
it cannot disturb the checkout.

Resolve each story's commands, its scope and any re-run from [qa-scope.md](qa-scope.md): the
per-stack command table, story versus area scope, and how a check is re-run after a failure.

**P7 never passes `--reuse`**, so its run is always
fresh against the committed branch. That fresh run is the whole point of P7. Mark any QA-failing story **BLOCKED** — from merge in
a fan-out wave — and keep its branch. Its builder already committed `done`, so revert that on
its branch (in its worktree, fan-out): `ck-story set <story-path> status=in-progress --no-sync`
(Bug-Fix Mode: `status=bug prior_status=<prior_status>`), committed as
`chore(tasks): EE-SS back to in-progress — QA failed`. Acceptable = ✓ complete + `QA: PASS`, plus conflict-free
in a fan-out wave.

A solo wave that QA-fails has its work sitting on `$WORKBRANCH` with nothing to withhold, so
"blocked" means *do not proceed to the manual gate or the next wave*: report the failure, keep
the commits (plus the status revert above, committed on `$WORKBRANCH`), and offer the same P8 choices (fix agent on `$WORKBRANCH`, or stop for review).
Never advance P9 past a red solo story — its dependents would build on broken code.

## P8 — Merge, regenerate, verify

Print the final summary ([conflict-format.md](conflict-format.md)). **When every branch of the
wave is ✓ complete, `QA: PASS` and conflict-free, merge them in P6's order without asking**:
that is the only answer the question could take, and the summary already shows what lands.
Ask (**AskUserQuestion**) only when a branch is held, blocked or conflicted:

1. **Merge ready branches now** (conflict-free order) — *fan-out only*
2. **Review branches first, merge manually** — print branch names and stop
3. **Re-dispatch blocked/failed stories** — fresh `Agent` call for empty or errored stories
   only (◐ incomplete is resumed at P5, not here). A new worktree in fan-out; a fresh solo
   dispatch on `$WORKBRANCH` in a solo wave.

Under `--auto` that question takes option 1 for the eligible branches, and the rest stay held.

**A solo wave** has its work already on the target; there is no merge question. Skip straight
to the regenerate below, saying so in one line (`Merge: none needed (solo on <$TARGET>).`).

**Option 1** — merge each eligible branch into `$TARGET` in P6's order, following
[`branch-topology.md`](../../../references/branch-topology.md#story-merge) exactly: the
clean-tree guard before the checkout, `--no-ff` so each story stays a readable unit, the
abort-and-report path on conflict, and `git branch -d` (never `-D`) once it lands. Do not
improvise a merge here, and do not write a story-id merge message — the shape there is the
one every consumer uses. A fan-out branch is still checked out in its worktree, so remove
that worktree first — each holds its own build output (a Rust/Tauri `target/` alone runs to
several GB), and `-d` refuses a branch a worktree still holds. `--merged` is the gate; past
it, `--force` discards untracked build output and nothing else:

```bash
git branch --merged "$TARGET" --format='%(refname:short)' | grep -qx "<branch>" || echo "NOT MERGED — keep"
git worktree remove --force "<path>"   # <path>: the branch's row in `git worktree list`
```

Then **regenerate the views once** on the target branch — every dispatched agent, worktree
or solo, carries only its own story frontmatter at `done` with its touched `files:`
(sub-agents never touch the shared views); the generator rebuilds them from that frontmatter
with no cell-editing and no sole-writer hazard:

```bash
ck-index tasks/<Plan>
ck-project sync tasks/<Plan>
```

Both are local bookkeeping: the views are gitignored, so there is **nothing to commit** —
never stage a view. The sync moves every story merged in this wave to Done and rolls the epic card up; a board failure is reported and never blocks the merge ([`github-projects.md`](../../../references/github-projects.md)). Then dispatch **one** post-merge `ck-code:qa-validator` on
`$TARGET` in the main checkout (the union of the wave's stories' commands, de-duplicated) — a
merge does not make integration failures cheap to find. `QA: FAIL` here is a cross-branch
integration failure by construction; keep the branches and offer `git revert -m 1 <merge-sha>`
or a fix agent on `$TARGET`.

**Post-wave QA runs with `--reuse`.** A command that already passed on this exact code
state, in this checkout, reports `REUSED` instead of running again. After a fan-out merge the
state is new, so everything runs. The P7 runs happened in other worktrees, so they never
count here.

**The post-wave QA runs at area scope** against the wave's `Base SHA` — every test and the
full lint of each area the wave reaches, the whole repo only when `ck-affected` prints FULL —
never a story-scope command
([qa-scope.md § Affected tests](qa-scope.md#affected-tests--the-story-level-test-command)). It is the wave's only
area-scope run.

**Solo wave:** dispatch this post-wave QA too, even though P7 just passed on the same branch.
P7 ran only the story scope, so the area's suite and full lint always run here. Typecheck
and build report `REUSED` when nothing moved since P7, because P7 already checked exactly this
tree in this checkout.
Its failure is not a cross-branch integration failure (there was no merge); recover with a
fix agent on `$WORKBRANCH`, or `git revert <sha>` of this wave's commits when the story must
come back out.

**Manual gate (SKILL.md 8.5, once per wave — solo waves included).** Ask the operator to
exercise the wave's work on `$TARGET` in the main checkout (`AskUserQuestion` `PASS / ISSUES`)
— the only place every story of the wave sits together with real dependencies. A solo wave is
not exempt: one story still lands on the shared target, and the gate is what keeps it from
becoming the next wave's foundation unverified. When later waves remain, add a third answer,
**PASS, and defer the gate for the remaining waves**. It skips the question for the rest of
the run, and their steps join one checklist at P9, so they are never dropped. Under `--auto`
every wave is deferred that way. On `ISSUES`, dispatch `ck-code:story-implementer` solo into the
main checkout on `$TARGET` — the [solo dispatch](agent-prompts.md#per-story-implementer-solo-p4-wave-of-exactly-1)
with `$TARGET` as its branch (`git rev-parse --abbrev-ref HEAD` guard) and its `Cycle:` line,
plus the user's issue report and a pointer to [completion.md § 8.5.3 Bug-Fix Sub-Loop](completion.md#853--manual-test-bug-fix-sub-loop).
It runs that sub-loop and commits the fix on `$TARGET`; then re-ask. The story stays merged — this is a fix, not a re-open.

**Cleanup.** After the merge and its check settle, `git worktree prune` and confirm only the
main worktree and the worktrees of held, blocked or conflicted stories remain. `prune` only
forgets directories already gone — it never deletes one — so a merged story's worktree still
standing is a missed removal above: remove it now and say so. Each surviving worktree keeps its
source and commits but not its rebuildable output: `ck-reclaim <path>…` deletes its gitignored
build directories (`target/`, `node_modules/`, `dist/`, …) and prints one `freed` line to put in
the report; a resume rebuilds them. Option 2 skips this — the user may want to run those
branches as they stand. Then confirm no merged story branch is still standing — the merge step deleted
each with `-d` as it landed, so `git branch --list 'story/*' 'fix/*'` must name only stories
this report calls held, blocked, or conflicted. That is the only state a resume can read
from; merged branches left standing accumulate forever and bury the real ones.

A solo wave has nothing to prune and no branch to delete — its work is on `$TARGET` itself;
say `Cleanup: none (solo on <$TARGET>).` rather than skipping the step silently.

## P9 — Next wave

Re-resolve the following wave from the freshly regenerated index and loop from P3. A story
held back from merge stays non-`done` and holds every story that depends on it — those cannot
dispatch. When no scheduled story remains, print the batch report naming every held,
`UNSCHEDULABLE`, and blocked story with its reason. Any wave whose manual gate was deferred
(by the user, or under `--auto`) adds the **Manual test checklist** from
[§ Auto mode](#auto-mode----auto) here, before the hand-off. A deferred gate is still a gate:
the first hand-off option becomes `/ck-code:verify --epic NN`, and promotion waits for it.
Under `--auto` there is no ask at all: print the checklist and the two commands, then stop.

Then hand off — **DIRECT, one ask** per
[`skill-invocation.md`](../../../references/skill-invocation.md). The merged stories sit on
`$TARGET`, an epic branch, and land through `ship --promote`, never story by story. The first
option follows the level:

- level `epic` — **Open the epic PR now** → `Skill({ skill: "ck-code:ship", args: "--promote --epic NN" })`,
  which opens the epic PR into `<trunk>`.
- level `plan` — **Merge epic NN into `<planbr>`** → the same `Skill` call; at plan level
  `ship --promote` opens no epic PR, it merges the epic `--no-ff` into the plan branch and
  pushes — the plan PR is the one review.
- **Not yet** → print `/ck-code:ship --promote --epic NN` and `/ck-code:track next` for later.

Never tell the user to ship each story. When stories remain held or blocked, say so in the
question: promotion waits until the epic is complete, so the hand-off becomes
`/ck-code:track next` for the remaining work.
