#!/usr/bin/env bash
# ck-project.sh — keep a GitHub Projects v2 board in step with a ck-code plan.
#
# The board is a GENERATED VIEW of story frontmatter, exactly like STORIES_INDEX.md
# (see references/data-model.md). Nothing about a card is authoritative: `sync` reads
# every story's `status:`, `delivery:` and `issue:`, computes the column each card
# belongs in, and pushes only the differences. That is why there is no "migrate"
# subcommand — a board that was never synced and a board that is half-synced take the
# identical code path.
#
# Two axes decide a column: `status` (is the work finished?) and `delivery` (how far has
# it travelled toward the trunk branch?). `delivery` is a cache over an immutable anchor
# — the `pr:` number — so `sync` re-answers it from GitHub on every run and it cannot
# drift. See references/github-projects.md.
#
# Usage:
#   ck-project.sh discover [--repo O/R]              # projects + current settings, as JSON
#   ck-project.sh init --project N [--extend]        # adopt an existing project
#   ck-project.sh init --project N --reorder         # rewrite the column order to the preset
#   ck-project.sh init --create "<title>"            # create one, provision the 7 columns
#   ck-project.sh sync [tasks/<slug>] [--dry-run]    # refresh delivery, then every card
#   ck-project.sh backfill [tasks/<slug>]            # recover pr: for pre-6.4 work
#   ck-project.sh closes <story|epic-dir|plan-dir>   # print the PR body's Closes footer
#   ck-project.sh set <issue> <role>                 # push one card (manual escape hatch)
#   ck-project.sh show                               # print resolved settings
#
# Options:
#   --owner LOGIN    project owner (default: the repo owner; "@me" for yourself)
#   --repo O/R       target repository (default: the current repo)
#   --pace N         seconds between mutating gh calls (default 1; env CK_PROJECT_PACE)
#   --dry-run        print every change that would be made; change nothing
#
# Config lives in tasks/SETTINGS.md as flat frontmatter, read by the same awk helpers
# ck-issues.sh uses. Column NAMES are authoritative; the *_id values beside them are a
# cache — on any miss the ids are re-resolved from the live board and rewritten, so
# renaming a column in the GitHub UI self-heals instead of failing.
#
# An empty board_<role> means "this board has no such column": that transition is
# skipped, never failed. A board is never mutated by `init` unless --extend says so.
#
# Portable to bash 3.2 (no associative arrays — maps are files under a temp dir).
# JSON is parsed by `gh --jq`, which embeds its own jq engine: no jq on PATH required.

set -uo pipefail

SETTINGS_REL="tasks/SETTINGS.md"
CMD=""
PLAN=""
DRY=0
OWNER_ARG=""
REPO_ARG=""
PROJECT_ARG=""
CREATE_TITLE=""
EXTEND=0
REORDER=0
PACE="${CK_PROJECT_PACE:-1}"
SET_ISSUE=""
SET_ROLE=""

# Roles, in board order. The order is the column order a provisioned board gets, and
# also the order map_columns claims live columns in — so a role that must win an
# ambiguous name (bug over blocked) has to be listed before its rival.
ROLES="blocked todo in_progress ready_to_ship in_review bug done"

usage() { sed -n '2,31p;38,39p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

[ $# -gt 0 ] || usage 1
CMD="$1"; shift

while [ $# -gt 0 ]; do
  case "$1" in
    --project)  PROJECT_ARG="${2:-}"; shift 2 ;;
    --create)   CREATE_TITLE="${2:-}"; shift 2 ;;
    --owner)    OWNER_ARG="${2:-}"; shift 2 ;;
    --repo)     REPO_ARG="${2:-}"; shift 2 ;;
    --pace)     PACE="${2:-}"; shift 2 ;;
    --extend)   EXTEND=1; shift ;;
    # Deliberately does NOT imply --extend: ensure_options matches preset NAMES, so on
    # a board spelling them "Backlog"/"On hold" it would add duplicate columns. Reorder
    # rearranges what is already there; pass both flags to do both.
    --reorder)  REORDER=1; shift ;;
    --dry-run)  DRY=1; shift ;;
    -h|--help)  usage 0 ;;
    -*)         echo "ck-project: unknown option $1" >&2; usage 1 ;;
    *)
      case "$CMD" in
        set) if [ -z "$SET_ISSUE" ]; then SET_ISSUE="$1"; else SET_ROLE="$1"; fi ;;
        *)   PLAN="${1%/}" ;;
      esac
      shift ;;
  esac
done

# Run from the repo root so tasks/ and tasks/SETTINGS.md resolve identically no
# matter which subdirectory the caller sat in.
if [ ! -d tasks ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$ROOT" ] && [ -d "$ROOT/tasks" ] && cd "$ROOT"
fi
SETTINGS="$SETTINGS_REL"

# `closes` answers from frontmatter alone, so it must work with no gh and no network —
# ship pastes its output into a PR body on a machine that may never have authenticated.
case "$CMD" in
  closes) ;;
  *) command -v gh >/dev/null 2>&1 || { echo "ck-project: gh not found on PATH" >&2; exit 1; } ;;
esac

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT TERM
mkdir -p "$WORK/opt" "$WORK/item" "$WORK/status" "$WORK/issue" "$WORK/pr"

CHANGED=0
ADDED=0
SKIPPED=0
FAILURES=0

warn() { echo "ck-project: WARN — $*" >&2; }
fail() { echo "ck-project: ERROR — $*" >&2; FAILURES=$((FAILURES + 1)); }
pace() { [ "$DRY" -eq 1 ] || sleep "$PACE"; }

# jqesc — escape a string for embedding inside a double-quoted jq string literal.
jqesc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# rget NAME — read a dynamically named variable (bash 3.2 has no name refs and
# no associative arrays, so the ROLE_*/ROLEID_* families are addressed this way).
rget() { eval "printf '%s' \"\${$1:-}\""; }
lc()   { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

# ---------------------------------------------------------------------------
# Frontmatter helpers — same contract as ck-issues.sh (one key per line, no
# block scalars; see references/data-model.md "Format contract").
# ---------------------------------------------------------------------------

# fm FILE KEY — print a frontmatter scalar, surrounding quotes stripped.
fm() {
  [ -f "$1" ] || return 0
  awk -v key="$2" '
    function unquote(s) {
      if (s ~ /^".*"$/ || s ~ /^'"'"'.*'"'"'$/) s = substr(s, 2, length(s)-2)
      return s
    }
    { sub(/\r$/,"") }
    FNR==1 && $0!="---" { exit }
    FNR==1 { next }
    $0=="---" { exit }
    { i=index($0,":"); if(i>0){ k=substr($0,1,i-1); v=substr($0,i+1);
        gsub(/^[ \t]+|[ \t]+$/,"",k); gsub(/^[ \t]+|[ \t]+$/,"",v);
        if(k==key){print unquote(v); exit} } }
  ' "$1"
}

# set_fm FILE KEY VALUE — set a frontmatter scalar, adding the line if absent.
# Content is copied back through the original file so its inode and permissions
# survive.
set_fm() {
  local f="$1" k="$2" v="$3" tmp
  [ "$(head -1 "$f" 2>/dev/null | tr -d '\r')" = "---" ] || {
    warn "no frontmatter fence in $f — '$k' not written"
    return 1
  }
  tmp="$WORK/fm.$$"
  awk -v key="$k" -v val="$v" '
    { sub(/\r$/,"") }
    FNR==1 { inb=1; print; next }
    inb && $0=="---" {
      if (!done) { print (val=="" ? key ":" : key ": " val); done=1 }
      inb=0; print; next
    }
    inb {
      i=index($0,":")
      if (i>0) { k2=substr($0,1,i-1); gsub(/^[ \t]+|[ \t]+$/,"",k2)
        if (k2==key) { print (val=="" ? key ":" : key ": " val); done=1; next } }
      print; next
    }
    { print }
  ' "$f" > "$tmp" || return 1
  cat "$tmp" > "$f" || return 1
  rm -f "$tmp"
  return 0
}

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

REPO=""; OWNER=""; NUMBER=""; PROJECT_ID=""; FIELD_NAME=""; FIELD_ID=""
ARCHIVE_SKIP=""; ISSUES_ON=""

load_settings() {
  [ -f "$SETTINGS" ] || return 1
  ISSUES_ON=$(fm "$SETTINGS" github_issues)
  OWNER=$(fm "$SETTINGS" github_project_owner)
  NUMBER=$(fm "$SETTINGS" github_project_number)
  PROJECT_ID=$(fm "$SETTINGS" github_project_id)
  FIELD_NAME=$(fm "$SETTINGS" board_field)
  FIELD_ID=$(fm "$SETTINGS" board_field_id)
  ARCHIVE_SKIP=$(fm "$SETTINGS" board_archive_skip)
  [ -n "$FIELD_NAME" ] || FIELD_NAME="Status"
  return 0
}

resolve_repo() {
  if [ -n "$REPO_ARG" ]; then REPO="$REPO_ARG"; return 0; fi
  REPO=$(fm "$SETTINGS" github_repo)
  [ -n "$REPO" ] && return 0
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
  [ -n "$REPO" ] || { echo "ck-project: cannot determine the repository — pass --repo OWNER/REPO" >&2; return 1; }
  return 0
}

write_settings() { # write_settings — create or update tasks/SETTINGS.md
  local f="$SETTINGS" r
  mkdir -p tasks
  if [ ! -f "$f" ]; then
    cat > "$f" <<'EOF'
---
schema: 1
github_issues: true
trunk_branch:
---

# Project Settings

Written by `/ck-code:ship --to-issues` and `/ck-code:config`; safe to edit by hand.

`github_issues` is the master switch: when it is `false` or absent, every board
call in `build` and `ship` becomes a no-op and no GitHub Project is touched.

Column **names** are authoritative. Each `*_id` beside them is a cache that is
re-resolved automatically whenever it stops matching the live board, so renaming
a column in the GitHub UI needs no edit here. An **empty** `board_<role>` means
this board has no such column — that transition is skipped rather than failed.

Two frontmatter axes decide a column: `status` (is the work finished?) and
`delivery` (empty → `pr` → `merged`: how far it has travelled toward the trunk).
Columns are listed in board order; precedence is bug → blocked → delivery → status.

| Role | Set when |
|---|---|
| `board_blocked` | story `status: todo` with an unmet `blocked_by` |
| `board_todo` | story `status: todo` with every dependency met |
| `board_in_progress` | story `status: in-progress`, no open PR |
| `board_ready_to_ship` | story `status: done`, `delivery` empty — finished, no PR yet |
| `board_in_review` | `delivery: pr` — a PR is open |
| `board_bug` | story `status: bug`, at any delivery |
| `board_done` | story `status: done` and `delivery: merged` |

`board_archive_skip: true` archives the card of any `status: skip` story.

`trunk_branch` names the branch a PR must merge into for a story to count as
delivered, and the base every PR targets. Absent, it is the repository default.
EOF
  fi
  set_fm "$f" schema 1
  set_fm "$f" github_issues true
  # Rewriting trunk_branch with its own value inserts the key when it is absent and
  # never overwrites the answer the user gave.
  set_fm "$f" trunk_branch "$(fm "$f" trunk_branch)"
  set_fm "$f" github_repo "$REPO"
  set_fm "$f" github_project_owner "$OWNER"
  set_fm "$f" github_project_number "$NUMBER"
  set_fm "$f" github_project_id "$PROJECT_ID"
  set_fm "$f" board_field "$FIELD_NAME"
  set_fm "$f" board_field_id "$FIELD_ID"
  for r in $ROLES; do
    set_fm "$f" "board_$r" "$(rget "ROLE_$r")"
    set_fm "$f" "board_${r}_id" "$(rget "ROLEID_$r")"
  done
  set_fm "$f" board_archive_skip "${ARCHIVE_SKIP:-true}"
}

# ---------------------------------------------------------------------------
# Board field resolution
# ---------------------------------------------------------------------------

# load_field — populate FIELD_ID and $WORK/opt/<lowercased name> = option id.
# Falls back to the first single-select field when the configured name is gone,
# which is what makes a UI rename recoverable rather than fatal.
load_field() {
  local out esc
  # Drop any cache from an earlier call — init calls this twice, before and
  # after provisioning columns, and stale options would mask the new ones.
  rm -rf "$WORK/opt" "$WORK/fieldid"; mkdir -p "$WORK/opt"
  esc=$(jqesc "$FIELD_NAME")
  out=$(gh project field-list "$NUMBER" --owner "$OWNER" --format json --limit 50 --jq \
    ".fields[] | select(.type == \"ProjectV2SingleSelectField\") | select(.name == \"$esc\") | .id as \$f | .options[] | [\$f, .id, .name] | @tsv" 2>/dev/null)

  if [ -z "$out" ]; then
    out=$(gh project field-list "$NUMBER" --owner "$OWNER" --format json --limit 50 --jq \
      '[.fields[] | select(.type == "ProjectV2SingleSelectField")][0] as $s | $s.options[] | [$s.id, .id, .name] | @tsv' 2>/dev/null)
    [ -n "$out" ] || { fail "project $NUMBER has no single-select field to use as a board"; return 1; }
    local newname
    newname=$(gh project field-list "$NUMBER" --owner "$OWNER" --format json --limit 50 --jq \
      '[.fields[] | select(.type == "ProjectV2SingleSelectField")][0].name' 2>/dev/null)
    warn "board field '$FIELD_NAME' not found — falling back to '$newname'"
    FIELD_NAME="$newname"
  fi

  # Each option is cached as "<id>\t<name as the board spells it>", keyed by the
  # lowercased name. Keeping the original casing here is what lets map_columns
  # match case-insensitively without a second field-list call per role.
  FIELD_ID=""
  printf '%s\n' "$out" | while IFS="$(printf '\t')" read -r fid oid oname; do
    [ -n "$oname" ] || continue
    printf '%s\t%s' "$oid" "$oname" > "$WORK/opt/$(lc "$oname")"
    printf '%s' "$fid" > "$WORK/fieldid"
  done
  [ -f "$WORK/fieldid" ] && FIELD_ID=$(cat "$WORK/fieldid")
  [ -n "$FIELD_ID" ] || { fail "could not resolve the board field id"; return 1; }
  return 0
}

opt_id()   { [ -f "$WORK/opt/$(lc "$1")" ] && cut -f1 "$WORK/opt/$(lc "$1")"; }
opt_name() { [ -f "$WORK/opt/$(lc "$1")" ] && cut -f2 "$WORK/opt/$(lc "$1")"; }

# role_matches ROLE LOWERCASED-COLUMN-NAME — does this column play this role?
# Ambiguous words are REJECTED by the wrong role before the right one is offered
# the column, because a column one role claims is never re-offered:
#   *review* rejected for todo/in_progress  -> "Ready for review"  = in_review
#   *bug*    rejected for blocked           -> "Bugs"              = bug
#   *ship*   rejected for todo              -> "Ready to Ship"     = ready_to_ship
# todo matches bare *ready* ("Ready", "Ready for dev"), which is why both "Ready for
# review" and "Ready to Ship" need an explicit rejection there.
role_matches() {
  case "$1" in
    todo)          case "$2" in *review*|*ship*|*merge*) return 1 ;; *todo*|*"to do"*|backlog*|*ready*|new|*triage*) return 0 ;; esac ;;
    in_progress)   case "$2" in *review*) return 1 ;; *progress*|*wip*|*doing*|*active*|*building*) return 0 ;; esac ;;
    ready_to_ship) case "$2" in *review*) return 1 ;; *ship*|*"to merge"*|*"ready to"*|*staged*) return 0 ;; esac ;;
    in_review)     case "$2" in *review*|*qa*|*testing*|*verify*|*approval*) return 0 ;; esac ;;
    bug)           case "$2" in *bug*|*defect*|*broken*|*regression*) return 0 ;; esac ;;
    blocked)       case "$2" in *bug*|*defect*) return 1 ;; *block*|*hold*|*stall*|*waiting*) return 0 ;; esac ;;
    done)          case "$2" in *done*|*complete*|*shipped*|*closed*|*merged*) return 0 ;; esac ;;
  esac
  return 1
}

# map_columns — fill ROLE_<role>/ROLEID_<role> by matching the board's live
# option names to roles. Column names routinely contain spaces ("In Progress"),
# so the candidate list is read line-by-line and never word-split. A column that
# one role has claimed is not offered to a later role.
map_columns() {
  local r n hit
  : > "$WORK/taken"
  for r in $ROLES; do
    hit=""
    while IFS= read -r n; do
      [ -n "$n" ] || continue
      grep -qxF "$n" "$WORK/taken" && continue
      if role_matches "$r" "$n"; then hit="$n"; break; fi
    done <<EOF
$(ls -1 "$WORK/opt" 2>/dev/null)
EOF
    if [ -n "$hit" ]; then
      printf '%s\n' "$hit" >> "$WORK/taken"
      eval "ROLE_$r=\$(cut -f2 \"\$WORK/opt/\$hit\")"
      eval "ROLEID_$r=\$(cut -f1 \"\$WORK/opt/\$hit\")"
    else
      eval "ROLE_$r=''"
      eval "ROLEID_$r=''"
    fi
  done
}

# ---------------------------------------------------------------------------
# Story → role
# ---------------------------------------------------------------------------

story_files() { # story_files [PLAN]
  if [ -n "${1:-}" ]; then
    find "$1/epics" -type f -path '*/stories/*.md' 2>/dev/null | sort
  else
    find tasks -type f -path '*/epics/*/stories/*.md' 2>/dev/null | sort
  fi
}

# build_status_map — id → status for EVERY story in the project. blocked_by may
# name a story in another plan (data-model.md: ids are globally unique), so this
# always scans all of tasks/ even when sync is scoped to one plan.
build_status_map() {
  local f id
  for f in $(find tasks -type f -path '*/epics/*/stories/*.md' 2>/dev/null); do
    id=$(fm "$f" id)
    [ -n "$id" ] && printf '%s' "$(fm "$f" status)" > "$WORK/status/$id"
  done
}

deps_met() { # deps_met FILE → 0 when every blocked_by story is done
  local raw d st
  raw=$(fm "$1" blocked_by)
  [ -n "$raw" ] || return 0
  for d in $(printf '%s' "$raw" | tr -d '[]' | tr ',' ' '); do
    [ -n "$d" ] || continue
    st=""
    [ -f "$WORK/status/$d" ] && st=$(cat "$WORK/status/$d")
    [ "$st" = "done" ] || [ "$st" = "skip" ] || return 1
  done
  return 0
}

# role_for_story FILE → role name, or "archive".
# Precedence: bug → blocked → delivery → status (references/github-projects.md).
# Only `todo` is gated on dependencies: a finished or in-flight story is never
# dragged back to Blocked by a dependency that has not landed.
role_for_story() {
  local st dv
  st=$(fm "$1" status)
  dv=$(fm "$1" delivery)
  case "$st" in
    skip) echo archive; return ;;
    bug)  echo bug; return ;;
    done)
      case "$dv" in
        merged) echo done ;;
        pr)     echo in_review ;;
        *)      echo ready_to_ship ;;
      esac
      return ;;
    in-progress)
      # A WIP PR is still under review, even though the work is unfinished.
      if [ "$dv" = "pr" ]; then echo in_review; else echo in_progress; fi
      return ;;
  esac
  if deps_met "$1"; then echo todo; else echo blocked; fi
}

role_for_epic() { # role_for_epic EPICDIR → rollup role
  local f st dv any=0 any_bug=0 any_pr=0 any_started=0 all_done=1 all_merged=1
  for f in $(find "$1/stories" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort); do
    st=$(fm "$f" status)
    dv=$(fm "$f" delivery)
    [ "$st" = "skip" ] && continue
    any=1
    [ "$dv" = "pr" ] && any_pr=1
    case "$st" in
      done) [ "$dv" = "merged" ] || all_merged=0 ;;
      bug)  any_bug=1; all_done=0; all_merged=0 ;;
      in-progress) any_started=1; all_done=0; all_merged=0 ;;
      *) all_done=0; all_merged=0 ;;
    esac
  done
  [ "$any" -eq 1 ] || { echo todo; return; }
  [ "$any_bug" -eq 1 ] && { echo bug; return; }
  if [ "$all_done" -eq 1 ]; then
    if [ "$all_merged" -eq 1 ]; then echo done
    elif [ "$any_pr" -eq 1 ]; then echo in_review
    else echo ready_to_ship
    fi
    return
  fi
  [ "$any_pr" -eq 1 ] && { echo in_review; return; }
  [ "$any_started" -eq 1 ] && { echo in_progress; return; }
  echo todo
}

# ---------------------------------------------------------------------------
# Delivery reconciliation — the second axis
# ---------------------------------------------------------------------------
#
# `delivery` answers "how far has this work travelled toward the trunk branch?" It is
# a CACHE over an immutable anchor: `pr:` is a number that cannot drift, and every
# sync re-asks GitHub what that PR did. A PR merged on github.com with no ck-code
# process running is exactly the case this repairs.

TRUNK=""
DELIV_CHANGED=0

# resolve_trunk — the branch a PR must merge into to count as delivered. The project
# gets the first word (tasks/SETTINGS.md), the repo default is the fallback. Same
# resolution as references/branch-topology.md, so the PR base and the delivered test
# can never disagree.
resolve_trunk() {
  [ -n "$TRUNK" ] && return 0
  TRUNK=$(fm "$SETTINGS" trunk_branch)
  [ -n "$TRUNK" ] && return 0
  TRUNK=$(gh repo view "$REPO" --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null)
  [ -n "$TRUNK" ] || TRUNK="main"
}

# load_prs — ONE batched call for the whole run: number → "<state>\t<baseRef>".
# Never one call per story.
load_prs() {
  gh pr list --repo "$REPO" --state all --limit 500 --json number,state,baseRefName --jq \
    '.[] | [(.number|tostring), .state, .baseRefName] | @tsv' 2>/dev/null \
    | while IFS="$(printf '\t')" read -r n st base; do
        [ -n "$n" ] || continue
        printf '%s\t%s' "$st" "$base" > "$WORK/pr/$n"
      done
}

# pr_lookup N — guarantee the cache holds N, fetching the one PR the batch missed.
# The batch is an optimisation, not a correctness limit: in a busy repo a plan's PR
# can fall outside the newest 500, and it must still resolve.
pr_lookup() {
  [ -f "$WORK/pr/$1" ] && return 0
  local out
  out=$(gh pr view "$1" --repo "$REPO" --json state,baseRefName --jq '[.state, .baseRefName] | @tsv' 2>/dev/null)
  [ -n "$out" ] || return 1
  printf '%s' "$out" > "$WORK/pr/$1"
  return 0
}

pr_state() { [ -f "$WORK/pr/$1" ] && cut -f1 "$WORK/pr/$1"; }
pr_base()  { [ -f "$WORK/pr/$1" ] && cut -f2 "$WORK/pr/$1"; }

# resolve_one FILE PRNUM [INHERIT] — write the delivery this PR implies onto FILE.
# With INHERIT set, FILE reached this PR through its epic and does not own the pointer
# yet, so the number is written onto FILE too. Materializing BOTH fields is the whole
# contract: ck-index.sh renders the Delivery cell from `delivery:`/`pr:` on the story
# alone, and ck-doctor.sh reports a `delivery:` with no `pr:` as an ERROR. Writing one
# without the other is what left epic-level stories rendering a bare `PR` and needing a
# hand-made "anchor delivered work" commit.
resolve_one() {
  local f="$1" n="$2" inherit="${3:-}" st base want cur label
  label=$(fm "$f" id); [ -n "$label" ] || label="epic $(fm "$f" epic)"
  if ! pr_lookup "$n"; then
    warn "PR #$n (referenced by $f) not found on $REPO — delivery left unchanged"
    return 0
  fi
  st=$(pr_state "$n"); base=$(pr_base "$n")
  case "$st" in
    MERGED)
      if [ "$base" = "$TRUNK" ]; then
        want=merged
      else
        want=pr
        warn "PR #$n merged into '$base', not the trunk '$TRUNK' — $label is not delivered yet"
      fi ;;
    OPEN)   want=pr ;;
    CLOSED)
      want=""
      warn "PR #$n was closed without merging — clearing delivery for $label" ;;
    *) return 0 ;;
  esac
  # Anchor first. A CLOSED-unmerged PR is not an anchor — it is cleared alongside the
  # delivery it can no longer justify, which returns the story to plain inheritance.
  if [ -n "$inherit" ] && [ "$(fm "$f" pr)" != "$n" ]; then
    if [ "$st" = "CLOSED" ]; then
      :
    else
      echo "  anchor   $label  → PR #$n  (inherited from epic)"
      [ "$DRY" -eq 1 ] || { set_fm "$f" pr "$n" && DELIV_CHANGED=$((DELIV_CHANGED+1)); }
    fi
  fi
  cur=$(fm "$f" delivery)
  [ "$cur" = "$want" ] && return 0
  echo "  delivery $label  ${cur:-(none)} → ${want:-(none)}  (PR #$n)"
  [ "$DRY" -eq 1 ] && return 0
  set_fm "$f" delivery "$want" && DELIV_CHANGED=$((DELIV_CHANGED+1))
}

# reconcile_delivery — refresh every delivery: in scope, materializing inheritance.
# A story with no PR of its own resolves through its epic's (integration: epic or
# feature never gives a story its own PR) and the answer is written onto the STORY,
# so ck-index, track and ck-doctor each read one field on one file.
reconcile_delivery() {
  local dir ef epr sf spr
  resolve_trunk
  load_prs
  for dir in $(find tasks -mindepth 3 -maxdepth 3 -type d -path 'tasks/*/epics/*' 2>/dev/null | sort); do
    case "$PLAN" in
      "") ;;
      *) case "$dir" in "$PLAN"/*) ;; *) continue ;; esac ;;
    esac
    ef="$dir/EPIC.md"
    [ -f "$ef" ] || continue
    epr=$(fm "$ef" pr)
    [ -n "$epr" ] && resolve_one "$ef" "$epr"
    for sf in $(find "$dir/stories" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort); do
      spr=$(fm "$sf" pr)
      # A materialized anchor that was closed without merging is stale, not authoritative:
      # drop it so the story falls back to whatever PR the epic carries now. Without this
      # the story would re-resolve the dead number on every sync and never see its
      # replacement.
      if [ -n "$spr" ] && [ -n "$epr" ] && [ "$spr" != "$epr" ] \
         && pr_lookup "$spr" && [ "$(pr_state "$spr")" = "CLOSED" ]; then
        echo "  anchor   $(fm "$sf" id)  PR #$spr closed unmerged → re-inheriting from epic"
        [ "$DRY" -eq 1 ] || set_fm "$sf" pr ""
        spr=""
      fi
      if [ -n "$spr" ]; then
        resolve_one "$sf" "$spr"
      elif [ -n "$epr" ]; then
        resolve_one "$sf" "$epr" inherit
      fi
    done
  done
}

# regen_views — the generated views are a function of frontmatter, so anything that
# writes frontmatter regenerates them in the same phase (references/data-model.md).
# stderr is deliberately NOT swallowed: ck-index WARN lines must reach the user.
regen_views() {
  [ "$DELIV_CHANGED" -gt 0 ] || return 0
  local gen
  gen="$(dirname "$0")/ck-index.sh"
  if [ -f "$gen" ]; then
    bash "$gen" ${PLAN:+"$PLAN"} >/dev/null || warn "ck-index failed — the generated views are stale"
  elif command -v ck-index >/dev/null 2>&1; then
    ck-index ${PLAN:+"$PLAN"} >/dev/null || warn "ck-index failed — the generated views are stale"
  else
    warn "ck-index not found — run it by hand to refresh the generated views"
  fi
}

# ---------------------------------------------------------------------------
# Board item cache
# ---------------------------------------------------------------------------

# load_items — issue number → "<item id>\t<current column>" for items belonging
# to THIS repo. A project may span repositories, so matching on the issue number
# alone would place cards from an unrelated repo.
load_items() {
  local url
  url="https://github.com/$REPO"
  gh project item-list "$NUMBER" --owner "$OWNER" --format json --limit 2000 --jq \
    ".items[] | select(.content.number != null) | select(.repository == \"$(jqesc "$url")\") | [(.content.number|tostring), .id, (.status // \"\")] | @tsv" 2>/dev/null \
    | while IFS="$(printf '\t')" read -r num iid st; do
        [ -n "$num" ] || continue
        printf '%s\t%s' "$iid" "$st" > "$WORK/item/$num"
      done
}

item_id()  { [ -f "$WORK/item/$1" ] && cut -f1 "$WORK/item/$1"; }
item_col() { [ -f "$WORK/item/$1" ] && cut -f2 "$WORK/item/$1"; }

# ---------------------------------------------------------------------------
# Mutations
# ---------------------------------------------------------------------------

add_item() { # add_item ISSUE → item id
  local iid
  if [ "$DRY" -eq 1 ]; then echo "DRY"; return 0; fi
  iid=$(gh project item-add "$NUMBER" --owner "$OWNER" \
        --url "https://github.com/$REPO/issues/$1" --format json --jq .id 2>/dev/null)
  pace
  [ -n "$iid" ] || return 1
  printf '%s\t' "$iid" > "$WORK/item/$1"
  echo "$iid"
}

set_column() { # set_column ISSUE ITEMID OPTIONID COLNAME
  if [ "$DRY" -eq 1 ]; then return 0; fi
  gh project item-edit --id "$2" --project-id "$PROJECT_ID" \
     --field-id "$FIELD_ID" --single-select-option-id "$3" >/dev/null 2>&1 || return 1
  pace
  return 0
}

archive_item() { # archive_item ITEMID
  if [ "$DRY" -eq 1 ]; then return 0; fi
  gh project item-archive "$NUMBER" --owner "$OWNER" --id "$1" >/dev/null 2>&1 || return 1
  pace
  return 0
}

# place ISSUE ROLE LABEL — the whole per-card decision, shared by sync and set.
place() {
  local issue="$1" role="$2" label="$3" iid col want wantid
  [ -n "$issue" ] || return 0

  if [ "$role" = "archive" ]; then
    [ "${ARCHIVE_SKIP:-true}" = "true" ] || { SKIPPED=$((SKIPPED+1)); return 0; }
    iid=$(item_id "$issue")
    [ -n "$iid" ] || { SKIPPED=$((SKIPPED+1)); return 0; }
    echo "  archive  #$issue  $label"
    archive_item "$iid" || fail "archive failed for #$issue"
    CHANGED=$((CHANGED+1))
    return 0
  fi

  want=$(rget "ROLE_$role")
  if [ -z "$want" ]; then SKIPPED=$((SKIPPED+1)); return 0; fi
  wantid=$(opt_id "$want")
  if [ -z "$wantid" ]; then
    warn "column '$want' no longer exists on the board — #$issue left where it is"
    SKIPPED=$((SKIPPED+1)); return 0
  fi

  iid=$(item_id "$issue")
  col=$(item_col "$issue")

  # No stickiness. In Review used to be pinned here, because "a PR is open" was not
  # expressible in frontmatter and the next sync would drag the card back to In
  # Progress. `delivery: pr` is that fact now, so the column is derived like any
  # other and cards move in both directions.

  if [ -z "$iid" ]; then
    echo "  add      #$issue → $want  $label"
    iid=$(add_item "$issue") || { fail "could not add #$issue to the board"; return 0; }
    ADDED=$((ADDED+1))
    [ "$DRY" -eq 1 ] && return 0
  elif [ "$col" = "$want" ]; then
    SKIPPED=$((SKIPPED+1)); return 0
  else
    echo "  move     #$issue  ${col:-(none)} → $want  $label"
  fi

  set_column "$issue" "$iid" "$wantid" "$want" || { fail "could not set #$issue to $want"; return 0; }
  CHANGED=$((CHANGED+1))
}

# ---------------------------------------------------------------------------
# Subcommand: discover
# ---------------------------------------------------------------------------

cmd_discover() {
  resolve_repo || exit 1
  local owner
  owner="${OWNER_ARG:-${REPO%%/*}}"
  echo "{"
  printf '  "repo": "%s",\n' "$REPO"
  printf '  "owner": "%s",\n' "$owner"
  printf '  "settings_exists": %s,\n' "$([ -f "$SETTINGS" ] && echo true || echo false)"
  if [ -f "$SETTINGS" ]; then
    printf '  "current": { "issues": "%s", "owner": "%s", "number": "%s", "field": "%s" },\n' \
      "$(fm "$SETTINGS" github_issues)" "$(fm "$SETTINGS" github_project_owner)" \
      "$(fm "$SETTINGS" github_project_number)" "$(fm "$SETTINGS" board_field)"
  fi
  printf '  "projects": '
  gh project list --owner "$owner" --limit 50 --format json --jq \
    '[.projects[] | {number, title, id, closed}]' 2>/dev/null || echo '[]'
  echo "}"
}

# ---------------------------------------------------------------------------
# Subcommand: init
# ---------------------------------------------------------------------------

# ensure_options — make the board carry every preset column, preserving the
# colour and description of options that already exist. Only ever called with
# --extend or on a project this run just created.
#
# updateProjectV2Field replaces the whole option set, so the mutation must send
# the UNION: every existing option first (unchanged), then the missing preset
# ones. Sending only the new ones would delete the user's columns.
ensure_options() {
  local existing missing r name opts color desc
  existing=$(gh api graphql -f query='
    query($id: ID!) { node(id: $id) { ... on ProjectV2SingleSelectField {
      options { name color description } } } }' -F id="$FIELD_ID" \
    --jq '.data.node.options[] | [.name, .color, .description] | @tsv' 2>/dev/null)

  opts=""
  while IFS="$(printf '\t')" read -r name color desc; do
    [ -n "$name" ] || continue
    opts="$opts{name: \"$(jqesc "$name")\", color: ${color:-GRAY}, description: \"$(jqesc "${desc:-}")\"}, "
  done <<EOF
$existing
EOF

  missing=0
  for r in $ROLES; do
    name=$(preset_name "$r")
    color=$(preset_color "$r")
    printf '%s\n' "$existing" | cut -f1 | tr 'A-Z' 'a-z' | grep -qxF "$(lc "$name")" && continue
    opts="$opts{name: \"$(jqesc "$name")\", color: $color, description: \"\"}, "
    missing=$((missing+1))
    echo "  column   + $name"
  done

  [ "$missing" -eq 0 ] && { echo "  columns  already complete"; return 0; }
  [ "$DRY" -eq 1 ] && return 0

  opts="${opts%, }"
  gh api graphql -f query="
    mutation { updateProjectV2Field(input: {fieldId: \"$FIELD_ID\", singleSelectOptions: [$opts]}) {
      projectV2Field { ... on ProjectV2SingleSelectField { id } } } }" >/dev/null 2>&1 \
    || { fail "could not add the missing columns — map the existing ones instead"; return 1; }
  pace
  return 0
}

# reorder_options — rewrite the option ORDER to the preset: every role column in
# ROLES order first, then any column no role claimed, keeping its existing position.
# Colours and descriptions are carried over untouched.
#
# updateProjectV2Field replaces the whole option set, so if GitHub re-mints option
# ids the cards lose their column. That is why the caller always runs a full sync
# straight afterwards — it re-places every card from frontmatter, which is the
# source of truth anyway.
reorder_options() {
  local existing name color desc opts="" r mapped
  existing=$(gh api graphql -f query='
    query($id: ID!) { node(id: $id) { ... on ProjectV2SingleSelectField {
      options { name color description } } } }' -F id="$FIELD_ID" \
    --jq '.data.node.options[] | [.name, .color, .description] | @tsv' 2>/dev/null)
  [ -n "$existing" ] || { warn "could not read the board columns — order left as is"; return 1; }

  : > "$WORK/ordered"
  for r in $ROLES; do
    mapped=$(rget "ROLE_$r")
    [ -n "$mapped" ] && printf '%s\n' "$mapped" >> "$WORK/ordered"
  done
  while IFS="$(printf '\t')" read -r name color desc; do
    [ -n "$name" ] || continue
    grep -qxF "$name" "$WORK/ordered" || printf '%s\n' "$name" >> "$WORK/ordered"
  done <<EOF
$existing
EOF

  echo "  order    $(tr '\n' '|' < "$WORK/ordered" | sed 's/|$//; s/|/ · /g')"

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    color=$(printf '%s\n' "$existing" | awk -F'\t' -v n="$name" '$1==n{print $2; exit}')
    desc=$(printf '%s\n' "$existing" | awk -F'\t' -v n="$name" '$1==n{print $3; exit}')
    opts="$opts{name: \"$(jqesc "$name")\", color: ${color:-GRAY}, description: \"$(jqesc "${desc:-}")\"}, "
  done < "$WORK/ordered"

  [ "$DRY" -eq 1 ] && return 0
  opts="${opts%, }"
  gh api graphql -f query="
    mutation { updateProjectV2Field(input: {fieldId: \"$FIELD_ID\", singleSelectOptions: [$opts]}) {
      projectV2Field { ... on ProjectV2SingleSelectField { id } } } }" >/dev/null 2>&1 \
    || { fail "could not reorder the columns — the board keeps its current order"; return 1; }
  pace
  return 0
}

preset_name() {
  case "$1" in
    blocked) echo "Blocked" ;; todo) echo "Todo" ;; in_progress) echo "In Progress" ;;
    ready_to_ship) echo "Ready to Ship" ;; in_review) echo "In Review" ;;
    bug) echo "Bugs" ;; done) echo "Done" ;;
  esac
}
preset_color() {
  case "$1" in
    blocked) echo GRAY ;; todo) echo BLUE ;; in_progress) echo YELLOW ;;
    ready_to_ship) echo ORANGE ;; in_review) echo PURPLE ;;
    bug) echo RED ;; done) echo GREEN ;;
  esac
}

cmd_init() {
  resolve_repo || exit 1
  OWNER="${OWNER_ARG:-${REPO%%/*}}"
  load_settings >/dev/null 2>&1 || true
  [ -n "$FIELD_NAME" ] || FIELD_NAME="Status"

  if [ -n "$CREATE_TITLE" ]; then
    echo "ck-project: creating project '$CREATE_TITLE' for $OWNER"
    if [ "$DRY" -eq 0 ]; then
      NUMBER=$(gh project create --owner "$OWNER" --title "$CREATE_TITLE" --format json --jq .number 2>/dev/null)
      [ -n "$NUMBER" ] || { echo "ck-project: project create failed (does the token carry the 'project' scope? run: gh auth refresh -s project)" >&2; exit 1; }
      pace
      gh project link "$NUMBER" --owner "$OWNER" --repo "$REPO" >/dev/null 2>&1 \
        || warn "could not link project $NUMBER to $REPO"
      pace
    else
      NUMBER="(new)"
    fi
    EXTEND=1
  elif [ -n "$PROJECT_ARG" ]; then
    NUMBER="$PROJECT_ARG"
  else
    echo "ck-project: init needs --project N or --create \"<title>\"" >&2; exit 1
  fi

  if [ "$DRY" -eq 1 ] && [ "$NUMBER" = "(new)" ]; then
    echo "  would create the project, link it to $REPO, and provision 7 columns"
    return 0
  fi

  PROJECT_ID=$(gh project view "$NUMBER" --owner "$OWNER" --format json --jq .id 2>/dev/null)
  [ -n "$PROJECT_ID" ] || { echo "ck-project: project $NUMBER not found for owner $OWNER" >&2; exit 1; }

  load_field || exit 1
  [ "$EXTEND" -eq 1 ] && { ensure_options; load_field || exit 1; }
  map_columns
  if [ "$REORDER" -eq 1 ]; then
    reorder_options && { load_field || exit 1; map_columns; }
  fi

  local r
  echo "ck-project: project #$NUMBER ($OWNER) · field '$FIELD_NAME'"
  local col
  for r in $ROLES; do
    col=$(rget "ROLE_$r")
    printf '  %-13s %s\n' "$r" "${col:-— no column on this board; transition skipped}"
  done

  [ "$DRY" -eq 1 ] && return 0
  write_settings
  echo "ck-project: wrote $SETTINGS"

  # A reorder may have re-minted the option ids, so every card is re-placed from
  # frontmatter before anyone looks at the board.
  if [ "$REORDER" -eq 1 ]; then
    echo "ck-project: re-placing every card after the reorder"
    cmd_sync
  fi
}

# ---------------------------------------------------------------------------
# Subcommand: sync
# ---------------------------------------------------------------------------

require_board() {
  load_settings || { echo "ck-project: no $SETTINGS — run /ck-code:config first" >&2; exit 1; }
  if [ "$ISSUES_ON" != "true" ]; then
    echo "ck-project: github_issues is not enabled in $SETTINGS — nothing to do"
    exit 0
  fi
  resolve_repo || exit 1
  [ -n "$OWNER" ] && [ -n "$NUMBER" ] || { echo "ck-project: $SETTINGS has no project configured — run /ck-code:config" >&2; exit 1; }
  if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gh project view "$NUMBER" --owner "$OWNER" --format json --jq .id 2>/dev/null)
    [ -n "$PROJECT_ID" ] || { echo "ck-project: project $NUMBER not reachable for $OWNER" >&2; exit 1; }
  fi
  load_field || exit 1
  reconcile_ids
}

# reconcile_ids — settings hold names AND cached ids. Names win: re-derive every
# id from the live board, and rewrite the file when a cached id has gone stale.
reconcile_ids() {
  local r name id cached dirty=0
  for r in $ROLES; do
    name=$(fm "$SETTINGS" "board_$r")
    if [ -z "$name" ]; then eval "ROLE_$r=''"; eval "ROLEID_$r=''"; continue; fi
    id=$(opt_id "$name")
    cached=$(fm "$SETTINGS" "board_${r}_id")
    eval "ROLE_$r=\$name"
    eval "ROLEID_$r=\$id"
    [ "$id" != "$cached" ] && dirty=1
  done
  if [ "$dirty" -eq 1 ] && [ "$DRY" -eq 0 ]; then
    for r in $ROLES; do
      set_fm "$SETTINGS" "board_${r}_id" "$(rget "ROLEID_$r")"
    done
    set_fm "$SETTINGS" board_field_id "$FIELD_ID"
  fi
}

cmd_sync() {
  require_board

  echo "ck-project: syncing $([ -n "$PLAN" ] && echo "$PLAN" || echo 'every plan') → project #$NUMBER ($OWNER)$([ "$DRY" -eq 1 ] && echo ' · DRY RUN')"

  # Delivery first: a card cannot be placed correctly until we know what GitHub did
  # with its PR. This is also the step that repairs a merge nobody told us about.
  reconcile_delivery
  regen_views

  build_status_map
  load_items

  local dir ef enum eissue sf sissue role
  for dir in $(find tasks -mindepth 3 -maxdepth 3 -type d -path 'tasks/*/epics/*' 2>/dev/null | sort); do
    case "$PLAN" in
      "") ;;
      *) case "$dir" in "$PLAN"/*) ;; *) continue ;; esac ;;
    esac
    ef="$dir/EPIC.md"
    [ -f "$ef" ] || continue
    enum=$(fm "$ef" epic)
    eissue=$(fm "$ef" issue)
    [ -n "$eissue" ] && place "$eissue" "$(role_for_epic "$dir")" "epic $enum"

    for sf in $(find "$dir/stories" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort); do
      sissue=$(fm "$sf" issue)
      [ -n "$sissue" ] || continue
      role=$(role_for_story "$sf")
      place "$sissue" "$role" "$(fm "$sf" id)"
    done
  done

  echo "ck-project: $ADDED added, $CHANGED changed, $SKIPPED already correct, $DELIV_CHANGED delivery updated, $FAILURES failures"
  return "$(( FAILURES == 0 ? 0 : 1 ))"
}

# ---------------------------------------------------------------------------
# Subcommand: backfill
# ---------------------------------------------------------------------------
#
# Work finished before 6.4 has no `pr:`, so it would sit in Ready to Ship forever.
# GitHub still knows which PR closed each linked issue — `ship` always writes a
# `Closes #<issue>` footer — so the pointer is recoverable rather than lost.

cmd_backfill() {
  require_board
  local dir ef sf f issue prnum found=0 miss=0

  echo "ck-project: backfilling pr: from closed issues$([ "$DRY" -eq 1 ] && echo ' · DRY RUN')"

  for dir in $(find tasks -mindepth 3 -maxdepth 3 -type d -path 'tasks/*/epics/*' 2>/dev/null | sort); do
    case "$PLAN" in
      "") ;;
      *) case "$dir" in "$PLAN"/*) ;; *) continue ;; esac ;;
    esac
    ef="$dir/EPIC.md"
    for f in "$ef" $(find "$dir/stories" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort); do
      [ -f "$f" ] || continue
      [ -n "$(fm "$f" pr)" ] && continue          # never overwrite a known pointer
      issue=$(fm "$f" issue)
      [ -n "$issue" ] || continue
      # The newest linking PR wins: a story reopened for a fix has more than one.
      prnum=$(gh issue view "$issue" --repo "$REPO" \
                --json closedByPullRequestsReferences \
                --jq '[.closedByPullRequestsReferences[]?.number] | max // empty' 2>/dev/null)
      if [ -z "$prnum" ]; then
        miss=$((miss+1))
        echo "  skip     issue #$issue — no linking PR found  ($f)"
        continue
      fi
      found=$((found+1))
      echo "  pr       issue #$issue ← PR #$prnum  ($f)"
      [ "$DRY" -eq 1 ] || set_fm "$f" pr "$prnum"
    done
  done

  if [ "$found" -eq 0 ] && [ "$miss" -eq 0 ]; then
    echo "ck-project: nothing to backfill — every entry already carries a pr: or has no issue:"
    return 0
  fi

  # Having recovered the anchors, answer the delivery question straight away; the
  # caller then only needs a sync to place the cards.
  [ "$DRY" -eq 1 ] || { reconcile_delivery; regen_views; }
  echo "ck-project: $found recovered, $miss without a linking PR, $DELIV_CHANGED delivery updated"
  echo "ck-project: run 'ck-project sync' to place the cards"
  return 0
}

# ---------------------------------------------------------------------------
# Subcommand: closes
# ---------------------------------------------------------------------------
#
# GitHub closes an issue on merge only when the PR body names it with a closing
# keyword. Leaving that footer to be composed by hand is why a promotion PR closed
# every issue one time, all but the epic issue the next, and none the time after —
# the set is derived from frontmatter, so derive it.
#
# Scope follows the argument, which mirrors what the PR actually delivers:
#   a story file  → that story's issue
#   an epic dir   → the epic issue + every non-skip story issue under it
#   a plan dir    → every `feature`-level epic of the plan, with its stories
#
# Reads frontmatter only: no gh, no network, safe to run before a repo has issues.

emit_closes() { # emit_closes FILE LABEL → print one footer line, count it
  local n; n=$(fm "$1" issue)
  [ -n "$n" ] || { CLOSES_MISS=$((CLOSES_MISS+1)); warn "$2 has no issue: — it will not close on merge ($1)"; return 0; }
  case "$n" in
    *[!0-9]*) CLOSES_MISS=$((CLOSES_MISS+1)); warn "$2 has a non-numeric issue: '$n' — skipped ($1)"; return 0 ;;
  esac
  echo "Closes #$n"
  CLOSES_N=$((CLOSES_N+1))
}

closes_epic() { # closes_epic EPICDIR — the epic issue, then its stories in id order
  local dir="$1" sf
  [ -f "$dir/EPIC.md" ] && emit_closes "$dir/EPIC.md" "epic $(fm "$dir/EPIC.md" epic)"
  for sf in $(find "$dir/stories" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort); do
    [ "$(fm "$sf" status)" = "skip" ] && continue
    emit_closes "$sf" "story $(fm "$sf" id)"
  done
}

CLOSES_N=0
CLOSES_MISS=0

cmd_closes() {
  local target="$PLAN" dir
  [ -n "$target" ] || { echo "ck-project: closes needs a story file, an epic directory, or a plan directory" >&2; exit 1; }
  # An EPIC.md path means the epic, not "a file with an issue:" — resolve it to its dir
  # so the caller gets the whole promotion set either way.
  case "$target" in */EPIC.md) target="${target%/EPIC.md}" ;; esac

  if [ -f "$target" ]; then
    emit_closes "$target" "story $(fm "$target" id)"
  elif [ -d "$target/stories" ] || [ -f "$target/EPIC.md" ]; then
    closes_epic "$target"
  elif [ -d "$target/epics" ]; then
    # Feature PR: only `feature`-level epics ride the feature branch. Epics left at
    # `story` or `epic` land independently and must not be closed by this PR.
    for dir in $(find "$target/epics" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort); do
      [ "$(fm "$dir/EPIC.md" integration)" = "feature" ] || continue
      closes_epic "$dir"
    done
    [ "$CLOSES_N" -eq 0 ] && [ "$CLOSES_MISS" -eq 0 ] && \
      warn "no epic in $target is at integration: feature — a feature PR closes nothing"
  else
    echo "ck-project: '$target' is not a story file, an epic directory, or a plan directory" >&2
    exit 1
  fi

  # Nothing on stdout is a valid answer (an unpublished plan), and the caller must be
  # able to tell it apart from a failure — so it is stderr plus exit 0, never an error.
  [ "$CLOSES_N" -eq 0 ] && warn "no linked issues — the PR body gets no Closes footer"
  return 0
}

# ---------------------------------------------------------------------------
# Subcommand: set
# ---------------------------------------------------------------------------

cmd_set() {
  [ -n "$SET_ISSUE" ] && [ -n "$SET_ROLE" ] || { echo "ck-project: set needs <issue> <role>" >&2; exit 1; }
  case " $ROLES " in *" $SET_ROLE "*) ;; *) echo "ck-project: unknown role '$SET_ROLE' ($ROLES)" >&2; exit 1 ;; esac
  require_board
  load_items
  # A manual escape hatch: it moves one card and writes no frontmatter, so the next
  # sync will move it back to whatever the two axes say. Prefer fixing `delivery:`.
  local want wantid iid
  want=$(rget "ROLE_$SET_ROLE")
  [ -n "$want" ] || { echo "ck-project: this board has no '$SET_ROLE' column — nothing to do"; exit 0; }
  wantid=$(opt_id "$want")
  iid=$(item_id "$SET_ISSUE")
  if [ -z "$iid" ]; then
    iid=$(add_item "$SET_ISSUE") || { echo "ck-project: could not add #$SET_ISSUE to the board" >&2; exit 1; }
  fi
  [ "$(item_col "$SET_ISSUE")" = "$want" ] && { echo "ck-project: #$SET_ISSUE already in $want"; exit 0; }
  set_column "$SET_ISSUE" "$iid" "$wantid" "$want" || { echo "ck-project: could not move #$SET_ISSUE" >&2; exit 1; }
  echo "ck-project: #$SET_ISSUE → $want"
}

# ---------------------------------------------------------------------------
# Subcommand: show
# ---------------------------------------------------------------------------

cmd_show() {
  [ -f "$SETTINGS" ] || { echo "ck-project: no $SETTINGS in this project"; exit 1; }
  local r
  echo "ck-project: $SETTINGS"
  printf '  %-22s %s\n' "github_issues" "$(fm "$SETTINGS" github_issues)"
  printf '  %-22s %s\n' "repo" "$(fm "$SETTINGS" github_repo)"
  printf '  %-22s %s (#%s)\n' "project" "$(fm "$SETTINGS" github_project_owner)" "$(fm "$SETTINGS" github_project_number)"
  printf '  %-22s %s\n' "board field" "$(fm "$SETTINGS" board_field)"
  printf '  %-22s %s\n' "trunk_branch" "$(fm "$SETTINGS" trunk_branch)"
  for r in $ROLES; do
    printf '  %-22s %s\n' "$r" "$(fm "$SETTINGS" "board_$r")"
  done
}

# ---------------------------------------------------------------------------

case "$CMD" in
  discover) cmd_discover ;;
  init)     cmd_init ;;
  sync)     cmd_sync ;;
  backfill) cmd_backfill ;;
  closes)   cmd_closes ;;
  set)      cmd_set ;;
  show)     cmd_show ;;
  -h|--help|help) usage 0 ;;
  *) echo "ck-project: unknown command '$CMD'" >&2; usage 1 ;;
esac
