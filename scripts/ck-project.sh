#!/usr/bin/env bash
# ck-project.sh — keep a GitHub Projects v2 board in step with a ck-code plan.
#
# The board is a GENERATED VIEW of story frontmatter, exactly like STORIES_INDEX.md
# (see references/data-model.md). Nothing about a card is authoritative: `sync` reads
# every story's `status:` and `issue:`, computes the column each card belongs in, and
# pushes only the differences. That is why there is no "migrate" subcommand — a board
# that was never synced and a board that is half-synced take the identical code path.
#
# Usage:
#   ck-project.sh discover [--repo O/R]              # projects + current settings, as JSON
#   ck-project.sh init --project N [--extend]        # adopt an existing project
#   ck-project.sh init --create "<title>"            # create one, provision the 5 columns
#   ck-project.sh sync [tasks/<slug>] [--dry-run]    # reconcile every card
#   ck-project.sh set <issue> <role>                 # push one card (used for in_review)
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
PACE="${CK_PROJECT_PACE:-1}"
SET_ISSUE=""
SET_ROLE=""

# Roles, in board order. The order is the column order a provisioned board gets.
ROLES="todo in_progress in_review blocked done"

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }

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

command -v gh >/dev/null 2>&1 || { echo "ck-project: gh not found on PATH" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT TERM
mkdir -p "$WORK/opt" "$WORK/item" "$WORK/status" "$WORK/issue"

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
      if (!done) { print key ": " val; done=1 }
      inb=0; print; next
    }
    inb {
      i=index($0,":")
      if (i>0) { k2=substr($0,1,i-1); gsub(/^[ \t]+|[ \t]+$/,"",k2)
        if (k2==key) { print key ": " val; done=1; next } }
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
---

# Project Settings

Written by `/ck-code:ship --to-issues` and `/ck-code:config`; safe to edit by hand.

`github_issues` is the master switch: when it is `false` or absent, every board
call in `build` and `ship` becomes a no-op and no GitHub Project is touched.

Column **names** are authoritative. Each `*_id` beside them is a cache that is
re-resolved automatically whenever it stops matching the live board, so renaming
a column in the GitHub UI needs no edit here. An **empty** `board_<role>` means
this board has no such column — that transition is skipped rather than failed.

| Role | Set when |
|---|---|
| `board_todo` | story `status: todo` with every dependency met |
| `board_in_progress` | story `status: in-progress` |
| `board_in_review` | `ship` opened a PR — sticky until the story is done |
| `board_blocked` | story `status: bug`, or an unmet `blocked_by` |
| `board_done` | story `status: done` |

`board_archive_skip: true` archives the card of any `status: skip` story.
EOF
  fi
  set_fm "$f" schema 1
  set_fm "$f" github_issues true
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
# "review" is rejected for todo before "ready" is accepted, so a board with a
# "Ready for review" column maps it to in_review rather than to todo.
role_matches() {
  case "$1" in
    todo)        case "$2" in *review*) return 1 ;; *todo*|*"to do"*|backlog*|*ready*|new|*triage*) return 0 ;; esac ;;
    in_progress) case "$2" in *review*) return 1 ;; *progress*|*wip*|*doing*|*active*|*building*) return 0 ;; esac ;;
    in_review)   case "$2" in *review*|*qa*|*testing*|*verify*|*approval*) return 0 ;; esac ;;
    blocked)     case "$2" in *block*|*bug*|*hold*|*stall*|*waiting*) return 0 ;; esac ;;
    done)        case "$2" in *done*|*complete*|*shipped*|*closed*|*merged*) return 0 ;; esac ;;
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

role_for_story() { # role_for_story FILE → role name, or "archive"
  local st
  st=$(fm "$1" status)
  case "$st" in
    done)        echo done ;;
    skip)        echo archive ;;
    bug)         echo blocked ;;
    in-progress) echo in_progress ;;
    *)           if deps_met "$1"; then echo todo; else echo blocked; fi ;;
  esac
}

role_for_epic() { # role_for_epic EPICDIR → rollup role
  local f st any_started all_done=1 any=0
  any_started=0
  for f in $(find "$1/stories" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort); do
    st=$(fm "$f" status)
    [ "$st" = "skip" ] && continue
    any=1
    case "$st" in
      done) ;;
      in-progress|bug) any_started=1; all_done=0 ;;
      *) all_done=0 ;;
    esac
  done
  [ "$any" -eq 1 ] || { echo todo; return; }
  [ "$all_done" -eq 1 ] && { echo done; return; }
  [ "$any_started" -eq 1 ] && { echo in_progress; return; }
  echo todo
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

  # Sticky In Review: once ship has moved a card to the review column, only
  # `done` may move it out. Without this, the next sync would drag an open PR's
  # card back to In Progress, because frontmatter still reads in-progress.
  if [ "$role" != "done" ] && [ -n "${ROLE_in_review:-}" ] && [ "$col" = "$ROLE_in_review" ]; then
    SKIPPED=$((SKIPPED+1)); return 0
  fi

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

preset_name() {
  case "$1" in
    todo) echo "Todo" ;; in_progress) echo "In Progress" ;;
    in_review) echo "In Review" ;; blocked) echo "Blocked" ;; done) echo "Done" ;;
  esac
}
preset_color() {
  case "$1" in
    todo) echo GRAY ;; in_progress) echo YELLOW ;;
    in_review) echo PURPLE ;; blocked) echo RED ;; done) echo GREEN ;;
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
    echo "  would create the project, link it to $REPO, and provision 5 columns"
    return 0
  fi

  PROJECT_ID=$(gh project view "$NUMBER" --owner "$OWNER" --format json --jq .id 2>/dev/null)
  [ -n "$PROJECT_ID" ] || { echo "ck-project: project $NUMBER not found for owner $OWNER" >&2; exit 1; }

  load_field || exit 1
  [ "$EXTEND" -eq 1 ] && { ensure_options; load_field || exit 1; }
  map_columns

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
  build_status_map
  load_items

  echo "ck-project: syncing $([ -n "$PLAN" ] && echo "$PLAN" || echo 'every plan') → project #$NUMBER ($OWNER)$([ "$DRY" -eq 1 ] && echo ' · DRY RUN')"

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

  echo "ck-project: $ADDED added, $CHANGED changed, $SKIPPED already correct, $FAILURES failures"
  return "$(( FAILURES == 0 ? 0 : 1 ))"
}

# ---------------------------------------------------------------------------
# Subcommand: set
# ---------------------------------------------------------------------------

cmd_set() {
  [ -n "$SET_ISSUE" ] && [ -n "$SET_ROLE" ] || { echo "ck-project: set needs <issue> <role>" >&2; exit 1; }
  case " $ROLES " in *" $SET_ROLE "*) ;; *) echo "ck-project: unknown role '$SET_ROLE' ($ROLES)" >&2; exit 1 ;; esac
  require_board
  load_items
  # A one-shot push is the only path that may move a card INTO in_review, so it
  # bypasses the stickiness check that protects the card afterwards.
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
  for r in $ROLES; do
    printf '  %-22s %s\n' "$r" "$(fm "$SETTINGS" "board_$r")"
  done
}

# ---------------------------------------------------------------------------

case "$CMD" in
  discover) cmd_discover ;;
  init)     cmd_init ;;
  sync)     cmd_sync ;;
  set)      cmd_set ;;
  show)     cmd_show ;;
  -h|--help|help) usage 0 ;;
  *) echo "ck-project: unknown command '$CMD'" >&2; usage 1 ;;
esac
