# Branch Topology — Where Work Lands (Shared Source of Truth)

Three integration levels, chosen **once per plan** and stored in the plan record,
`tasks/<plan>/OVERVIEW.md`, as `integration:` ([`data-model.md`](data-model.md#plan-record-tasksplanoverviewmd)).
Everything else on this page is derived from it. `build`, `ship` and `track` link here;
none of them restates the rule.

| Level | Reviewed as | Story branch is cut from & merged into |
|---|---|---|
| `story` (or empty) | one PR per story | the trunk |
| `epic` | one PR per epic | `epic/<NN>-<epic-slug>`, itself cut from the trunk |
| `plan` | one PR for the whole plan | `epic/<NN>-<epic-slug>`, itself cut from the plan branch (the record's `branch:`), which is cut from the trunk |

**Empty is `story`.**

## Who writes the level

The level is written only through `ck-plan set tasks/<plan> integration=<level>`, which
validates the enum and, for `plan`, records `branch: plan/<slug>` when the field is empty.
Exactly three callers use it:

| Caller | When |
|---|---|
| `plan` | once, when it creates the plan (one question: story / epic / plan) |
| `/ck-code:config integration <tasks/plan> <level>` | whenever the user decides to change it |
| `build` PARALLEL MODE P3 | only to switch a `story`-level plan to `epic`, on the user's answer (see [Parallel mode](#parallel-mode-never-targets-the-trunk)) |

No other skill writes it, and no gate offers to. `build` never asks the level; it shows
the base it derived from it.

## Branch names

```
story branch    story/<EE>-<SS>-<kebab-case(title)>    fix/<EE>-<SS>-<slug> for a bug story
epic branch     epic/<NN>-<epic-slug>                  slug = EPIC.md `slug:` else folder slug
plan branch     OVERVIEW.md `branch:`                  new plans: plan/<plan-slug>
```

Story and epic branch names are **derived, never stored**: a stored name is a second
source of truth that can drift from git. The plan branch is the one exception, and it is
stored for a reason: a plan migrated from an older layout keeps its existing
`feat/<slug>` branch, so the record's `branch:` field is what names it. **The field wins**;
never rebuild the name from the slug.

Epic branches are **looked up by the immutable number**, so renaming an epic slug never
orphans its branch. The number is unique project-wide
([`data-model.md`](data-model.md#epic-and-story-numbers-are-globally-unique)), so exactly
one epic can ever claim a given `epic/<NN>-*`:

```bash
git branch --list "epic/<NN>-*"
```

- exactly one match → use it
- no match → create it (see Creation)
- more than one → **a stale branch**, not two epics. The epic was renamed and an old
  branch survived, or a branch was hand-created. `AskUserQuestion` which one to use and
  say the others look stale; never guess, and never delete one unasked.

## Resolution

```
<trunk>   = tasks/SETTINGS.md `trunk_branch:` when set — the project's own answer
            else origin/HEAD (git symbolic-ref refs/remotes/origin/HEAD)
            else gh repo view --json defaultBranchRef -q .defaultBranchRef.name
            fallback "main"
<level>   = ck-plan get tasks/<plan> integration      (empty → story)
<planbr>  = ck-plan get tasks/<plan> branch           (level plan only)

resolve_parent(epic NN, plan)   the branch a story branch is cut from and merged back into
  story | empty  ->  <trunk>
  epic           ->  epic/<NN>-*                       based on <trunk>
  plan           ->  epic/<NN>-*                       based on <planbr>
                     <planbr>                          based on <trunk>

resolve_pr_base(what)
  story PR       ->  <trunk>                           level story only; other levels merge stories locally
  epic PR        ->  <trunk>                           level epic
  plan PR        ->  <trunk>                           level plan: <planbr> -> <trunk>
```

At level `plan` an epic has no PR of its own: it merges into `<planbr>` locally
([Promotion](#promotion)), and the plan PR is the one review. The PR base is **never
asked for**; it is derived from the level.

**`trunk_branch` settles the `main`/`develop` question once.** A team whose integration
branch is not the repo default sets it in `tasks/SETTINGS.md`
([`data-model.md`](data-model.md#project-settings-taskssettingsmd)) and `ship` stops asking
per PR. It is also the branch a PR must merge into for a story to reach
`delivery: merged` ([`github-projects.md`](github-projects.md#reconciliation--how-delivery-merged-happens)):
one trunk, one definition, no way for the PR base and the delivered test to disagree.

## Start point — the base a new story branch is cut from

`resolve_parent` says which branch a story *belongs* on. This section says how a skill
**arrives** there. The checked-out branch is never the answer by default: a build is launched
from wherever the previous run left the tree, and cutting a story from a stale peer branch
puts two unrelated stories in one PR, silently, and only visible at review time.

```
resolve_base(story <EE>-<SS>, epic NN, plan)
  1. git branch --list "story/<EE>-<SS>-*" "fix/<EE>-<SS>-*"
       exactly one  ->  that branch            RESUME  (work already started here)
       more than one ->  ask which; never guess
  2. resolve_parent(NN, plan)                  NEW     (created lazily, see Creation)
  3. the checked-out branch is a legal base ONLY when it equals 1 or 2
```

Every consumer **shows the resolved base with its reason** and lets the user override it. A
base chosen silently is the same defect class as a stored branch name: correct until it is
not, and invisible when it is not.

| Resolved base | Reason shown |
|---|---|
| existing `story/<EE>-<SS>-*` | work already started here — `<N>` commits |
| `<trunk>` | level `story` — this story gets its own PR into `<trunk>` |
| `epic/<NN>-*` | level `epic` — the story lands inside epic `<NN>`'s single PR |
| `epic/<NN>-*` (on `<planbr>`) | level `plan` — the epic merges into `<planbr>`, reviewed in the one plan PR, never on its own into `<trunk>` |

### Four signals that change the suggestion

- **The epic or plan already has an open PR** (`EPIC.md` or `OVERVIEW.md` `pr:` set with
  `delivery: pr`) — say it outright: *this story joins open PR #`<n>`; it is not reviewed
  on its own.* Correct at level `epic`/`plan`, and the single outcome a user most often did
  not intend.
- **The base is behind its remote** — `git rev-list --count <base>..origin/<base>`; when
  greater than 0, offer **Sync base first** *inside the same question* (`git merge
  origin/<base>`, with the identical abort-and-report path as [Story merge](#story-merge)).
  Never a second prompt, never a silent merge.
- **The checked-out branch is another story's** (`story/*` or `fix/*` whose `<EE>-<SS>` is not
  this story's) — never offer it as a base without naming whose it is.
- **The user does not want this work to reach `<trunk>` directly** — that is the plan's
  level, not a base override. Name the command that changes it,
  `/ck-code:config integration tasks/<plan> epic` (or `plan`), and stop; re-resolve after it
  ran. Never write the level from this gate, and never hand-pick a base to simulate one:
  `ship` derives the PR from the *stored* level and would target `<trunk>` anyway.

## Parallel mode never targets the trunk

`build` PARALLEL MODE merges its worktree branches into one integration branch before
anything is reviewed, so it needs an epic or plan branch to merge into. It **never merges
into `<trunk>`**. When the plan is at level `story`, the P3 gate offers exactly two
options:

```
Q: "Plan <slug> is at story level — parallel builds merge into an epic branch. Switch it?"
   > Switch this plan to epic level     ck-plan set tasks/<plan> integration=epic
     Cancel
```

There is no "merge into `<trunk>`" path. After the switch the base re-resolves to
`epic/<NN>-*`, and the run ends with one hand-off to `/ck-code:ship --promote --epic <NN>`
(or the plan at level `plan`), never a per-story ship.

## Creation

Lazy and idempotent: a branch is created from its own parent the first time something must
sit on it, and never recreated. At level `plan`, the chain is built top-down.

```bash
git fetch origin --quiet
git branch <planbr> origin/<trunk>                  # level plan only, if absent
git branch epic/<NN>-<slug> <planbr>                # if absent; origin/<trunk> at level epic
```

## Story merge

Used by `ship` Phase 5 when the level is `epic` or `plan`.

**Clean-tree guard first.** The commit has landed, but deliberately unstaged files can
remain. If `git status --porcelain` is non-empty, do **not** check out — report the dirty
paths and offer **Stash and merge** / **Leave on story branch**.

```bash
git status --porcelain                     # must be empty
git checkout epic/<NN>-<slug>
git merge --no-ff story/<EE>-<SS>-<slug> -m "Merge story <EE>-<SS> <title>"
git branch -d story/<EE>-<SS>-<slug>
```

`--no-ff` is required: it keeps each story a readable unit, so the epic PR reads
story-by-story and `git log --first-parent` is a story list.

**Conflict path — never sloppy.** If the merge exits non-zero:

1. `git merge --abort`
2. `git checkout story/<EE>-<SS>-<slug>` — put the user back exactly where they were
3. report the conflicting paths from the merge output
4. tell them to resolve on the story branch and re-run `/ck-code:ship`

Never leave a half-merged tree. Never auto-resolve a conflict. On success the user stays on
the epic branch; the next story of that epic is cut from it anyway.

## Promotion

`ship --promote` owns both gates below. An epic is **promotable** when the plan's level is
`epic` or `plan`, every non-`skip` story is `status: done`, and either
`git rev-list --count <parent>..epic/<NN>-*` is greater than 0 or it has no open PR.

**Staleness is folded into the gate, never asked separately.** Before offering any promotion,
run `git rev-list --count <branch>..origin/<target>`; if greater than 0, add
**Sync from `<target>` first** as an option *inside* the same question. Syncing is
`git merge origin/<target>`, with the identical abort-and-report path as Story merge.

**Epic gate** — fires once, when the epic rolls up to DONE:

```
level epic
Q: "Epic <NN> is complete (<done>/<total>). Promote it?"
   > Open PR epic/<NN>-<slug> -> <trunk>
     Push epic branch only
     Not yet                              -> /ck-code:ship --promote --epic <NN>

level plan
Q: "Epic <NN> is complete (<done>/<total>). Merge it into <planbr>?"
   > Merge into <planbr>                  --no-ff, same guard and abort path as Story merge
     Not yet                              -> /ck-code:ship --promote --epic <NN>
```

The epic gate never changes the level. A user who wants a different level at this point
runs `/ck-code:config integration` first; it applies from the next promotion onward.

**Every promotion PR records its number.** Opening the epic PR writes that number to the
epic's `EPIC.md` as `pr:` with `delivery: pr`; opening the plan PR writes it to the plan
record with `ck-plan set tasks/<plan> pr=<n> delivery=pr`. Those are the pointers a story
with no PR of its own inherits (story → epic → plan), and without them a story that ships
only through a promotion PR could never leave *Ready to Ship*
([`data-model.md`](data-model.md#two-axes-status-is-work-delivery-is-integration)).
The PR body's footer comes from `ck-project closes tasks/<plan>/epics/NN_<slug>` or
`ck-project closes tasks/<plan>` ([`github-projects.md`](github-projects.md#closes--the-pr-footer-is-derived-not-authored)).

**Plan gate** — level `plan` only. It fires when every epic of the plan is DONE and merged
into `<planbr>`.

```
Q: "All <N> epics of <plan> are merged into <planbr>. Open the PR?"
   > Open PR <planbr> -> <trunk>
     Push only
     Not yet                              -> /ck-code:ship --promote tasks/<plan>
```

## Cleanup

- A merged story branch is deleted **at merge time**: the tool does the chore rather than
  reminding the user to.
- A story branch with an **open PR** is kept; the PR needs it. Its deletion becomes a
  summary reminder, because ship cannot observe the PR merging.
- An epic branch merged into `<planbr>` is deleted at merge time; one with an open PR is
  deleted after that PR merges (a reminder, same reason). The plan branch likewise.

## Rules

- **Never store a story or epic branch name** in frontmatter: derive it from the number and slug. The plan branch lives in the record's `branch:`, and that field wins over any name rebuilt from the slug.
- **Never write the integration level except through `ck-plan set`**, and only from `plan` (at creation), `/ck-code:config integration`, or build P3's switch to `epic`.
- **Never resolve an epic branch by slug**: glob the immutable number, `epic/<NN>-*`.
- **Never ask for the PR base**: derive it from the level and `trunk_branch`, else the repo default.
- **Never let PARALLEL MODE target the trunk**: at level `story` the P3 gate offers only "Switch this plan to epic level" or "Cancel".
- **Never cut a story branch from the checked-out branch by default**: resolve the base
  (`resolve_base`), show it with its one-line reason, and let the user override it. The branch
  a skill happened to be launched on is a legal base only when it is the one that resolved.
- **Never change the base to keep work off `<trunk>`**: change the plan's level with
  `/ck-code:config integration` and re-resolve, or `ship` will target `<trunk>` from the
  stored level regardless.
- **Never open a PR without recording its number**: a story PR writes the story's `pr:`, an epic PR the epic's, a plan PR the plan record's; an unrecorded PR is a story that can never reach Done.
- **Never merge without the clean-tree guard**, and never leave a merge half-applied:
  `git merge --abort` and restore the prior branch.
- **Never auto-open a PR**: promotion is always confirmed.
- **Never treat a level change as retroactive**: it applies from the next story onward.
