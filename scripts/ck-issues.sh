#!/usr/bin/env bash
# ck-issues.sh — publish a ck-code tasks/<slug>/ plan to GitHub Issues.
#
# The plan files are the source of truth (see references/data-model.md). This script
# reads them, creates the issues for the chosen mode, and writes each new issue number
# back into the matching frontmatter `issue:` field so `ship` can later resolve issues
# by number instead of by title.
#
# Usage:
#   ck-issues.sh tasks/<slug> --mode feature|epics|stories [options]
#
# Options:
#   --dry-run        print every issue that would be created; create nothing
#   --repo O/R       target repository (default: the current repo)
#   --pace N         seconds between gh calls (default 1; env CK_ISSUES_PACE)
#   --no-index       skip the trailing ck-index regeneration
#
# Why a script and not one `gh` call per issue: a stories-mode publish of a 12-epic
# plan is ~140 gh calls plus ~70 frontmatter edits. Driving that from a skill means
# ~200 tool round-trips, so callers improvise a throwaway script instead — and pace
# every call with a foreground `sleep`, which agent harnesses commonly block. Here the
# pacing is a subprocess detail and the whole publish is one deterministic call.
#
# Re-running is safe and is the supported way to finish a partial publish: anything
# whose frontmatter already carries an `issue:` is reused, never recreated. Epic bodies
# are relinked from the current numbers on every run, so a run interrupted between the
# story issues and the relink is repaired by running the same command again.
#
# Portable to bash 3.2 (no associative arrays — maps are files under a temp dir).

set -uo pipefail

PLAN=""
MODE=""
DRY=0
REPO=""
PACE="${CK_ISSUES_PACE:-1}"
RUN_INDEX=1

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)     MODE="${2:-}"; shift 2 ;;
    --repo)     REPO="${2:-}"; shift 2 ;;
    --pace)     PACE="${2:-}"; shift 2 ;;
    --dry-run)  DRY=1; shift ;;
    --no-index) RUN_INDEX=0; shift ;;
    -h|--help)  usage 0 ;;
    -*)         echo "ck-issues: unknown option $1" >&2; usage 1 ;;
    *)          PLAN="$1"; shift ;;
  esac
done

[ -n "$PLAN" ] || { echo "ck-issues: no plan directory given" >&2; usage 1; }

case "$MODE" in
  feature|epics|stories) ;;
  "") echo "ck-issues: --mode is required (feature|epics|stories)" >&2; exit 1 ;;
  *)  echo "ck-issues: invalid --mode '$MODE' (feature|epics|stories)" >&2; exit 1 ;;
esac

# Locate the plan: fall back to the git repo root so a run from a subdirectory
# resolves the same relative path a skill would pass.
if [ ! -d "$PLAN" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$ROOT" ] && [ -d "$ROOT/$PLAN" ]; then
    cd "$ROOT"
  else
    echo "ck-issues: plan directory not found: $PLAN (cwd: $PWD)" >&2
    exit 1
  fi
fi
PLAN="${PLAN%/}"
[ -d "$PLAN/epics" ] || { echo "ck-issues: no $PLAN/epics directory — is this a ck-code plan?" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || { echo "ck-issues: gh not found on PATH" >&2; exit 1; }
if [ "$DRY" -eq 0 ]; then
  gh auth status >/dev/null 2>&1 || { echo "ck-issues: gh is not authenticated — run 'gh auth login'" >&2; exit 1; }
fi

GH_REPO_ARGS=""
[ -n "$REPO" ] && GH_REPO_ARGS="--repo $REPO"
if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo '?')"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT TERM
mkdir -p "$WORK/epicmap" "$WORK/storymap"

FAILURES=0
CREATED=0
REUSED=0
WRITTEN=0
LINKED=0

warn() { echo "ck-issues: WARN — $*" >&2; }
fail() { echo "ck-issues: ERROR — $*" >&2; FAILURES=$((FAILURES + 1)); }

summary() {
  local verb="created"
  [ "$DRY" -eq 1 ] && verb="would be created"
  echo "ck-issues: $CREATED $verb, $REUSED reused, $WRITTEN issue: fields written, $LINKED sub-issues linked, $FAILURES failures"
}

# fm FILE KEY — print a frontmatter scalar (between the first --- fences).
# Surrounding quotes are stripped: YAML 1.1 reads a bare `01` as octal, so a plan
# writer may legitimately quote `epic: "01"`.
fm() {
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
# Rewrites through a temp file and copies content back, so the original file's
# permissions and inode survive.
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
  WRITTEN=$((WRITTEN + 1))
  return 0
}

# section FILE HEADING — print one `## HEADING` body, blank lines trimmed off both
# ends. `###` subheadings are kept; the next `## ` ends the section.
section() {
  [ -f "$1" ] || return 0
  awk -v h="$2" '
    { sub(/\r$/,"") }
    !inb && $0 ~ "^##[ \t]+" h "[ \t]*$" { inb=1; next }
    inb && /^##[ \t]/ { inb=0 }
    inb { buf[++n]=$0 }
    END {
      s=1; while (s<=n && buf[s] ~ /^[ \t]*$/) s++
      e=n; while (e>=s && buf[e] ~ /^[ \t]*$/) e--
      for (i=s; i<=e; i++) print buf[i]
    }
  ' "$1"
}

# add_section BODYFILE TITLE CONTENT — append a `## TITLE` block, skipped when empty.
# Trailing newlines are trimmed so a list built up in a variable does not leave a
# double blank line before the next heading.
add_section() {
  local content="$3"
  while [ "${content%$'\n'}" != "$content" ]; do content="${content%$'\n'}"; done
  [ -n "$content" ] || return 0
  printf '## %s\n\n%s\n\n' "$2" "$content" >> "$1"
}

# fmt_list "[a, b]" — one markdown bullet per inline-flow item; empty for [] or blank.
fmt_list() {
  printf '%s' "$1" | tr -d '[]' | tr ',' '\n' | awk '
    { gsub(/^[ \t]+|[ \t]+$/,"") } NF { print "- " $0 }'
}

pace() { [ "$DRY" -eq 1 ] || sleep "$PACE"; }

# create_issue BODYFILE TITLE LABEL... — echo the new issue number, or exit non-zero.
#
# Callers run this in a command substitution, so it executes in a SUBSHELL: any
# counter it incremented would be discarded when that subshell exits. CREATED and
# FAILURES are therefore tallied by the caller, never here — an earlier version
# counted inside and reported "0 created, 0 failures" after five real creations and
# would have exited 0 on a failed publish.
create_issue() {
  local body="$1" title="$2" out num
  shift 2
  local labels=""
  for l in "$@"; do labels="$labels --label $l"; done

  if [ "$DRY" -eq 1 ]; then
    echo "would create: $title [$*] ($(wc -l < "$body" | tr -d ' ') body lines)" >&2
    echo "DRY"
    return 0
  fi

  # shellcheck disable=SC2086
  out=$(gh issue create $GH_REPO_ARGS --title "$title" --body-file "$body" $labels 2>&1)
  num=$(printf '%s\n' "$out" | sed -n 's|.*/issues/\([0-9][0-9]*\).*|\1|p' | tail -1)
  pace
  if [ -z "$num" ]; then
    echo "ck-issues: ERROR — issue create failed for '$title': $(printf '%s' "$out" | tail -2 | tr '\n' ' ')" >&2
    return 1
  fi
  echo "$num"
}

# ---------------------------------------------------------------------------
# Read the plan
# ---------------------------------------------------------------------------

OVERVIEW=""
for f in PROJECT_OVERVIEW.md FEATURE_OVERVIEW.md; do
  [ -f "$PLAN/$f" ] && { OVERVIEW="$PLAN/$f"; break; }
done

PROJECT_NAME=""
if [ -n "$OVERVIEW" ]; then
  PROJECT_NAME=$(awk '/^# / { sub(/^# /,""); sub(/^[A-Za-z ]+: /,""); print; exit }' "$OVERVIEW")
fi
[ -n "$PROJECT_NAME" ] || PROJECT_NAME=$(basename "$PLAN")

EPIC_DIRS=$(find "$PLAN/epics" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
[ -n "$EPIC_DIRS" ] || { echo "ck-issues: no epic folders under $PLAN/epics" >&2; exit 1; }

SIZES=$(find "$PLAN/epics" -type f -path '*/stories/*.md' 2>/dev/null | sort | while read -r s; do
  fm "$s" size
done | awk 'NF' | sort -u)

N_EPICS=$(printf '%s\n' "$EPIC_DIRS" | awk 'NF' | wc -l | tr -d ' ')
N_STORIES=$(find "$PLAN/epics" -type f -path '*/stories/*.md' 2>/dev/null | wc -l | tr -d ' ')

echo "ck-issues: repo $REPO · mode $MODE · plan $PLAN · $N_EPICS epics / $N_STORIES stories$([ "$DRY" -eq 1 ] && echo ' · DRY RUN')"

# ---------------------------------------------------------------------------
# Labels
# ---------------------------------------------------------------------------

mklabel() {
  [ "$DRY" -eq 1 ] && { echo "would ensure label: $1"; return 0; }
  # shellcheck disable=SC2086
  gh label create "$1" $GH_REPO_ARGS --color "$2" --description "$3" --force >/dev/null 2>&1 \
    || warn "could not create label '$1'"
  pace
}

case "$MODE" in
  feature) mklabel feature 0E8A16 "Whole-feature tracking issue" ;;
  epics)   mklabel epic 6F42C1 "Epic-level issue" ;;
  stories)
    mklabel epic 6F42C1 "Epic-level issue"
    mklabel story 0075CA "Implementation story"
    for s in $SIZES; do
      case "$s" in
        S) mklabel "size/S" C2E0C6 "Small story" ;;
        M) mklabel "size/M" BFDADC "Medium story" ;;
        *) mklabel "size/$s" EDEDED "Story size $s" ;;
      esac
    done
    ;;
esac

# ---------------------------------------------------------------------------
# Body builders
# ---------------------------------------------------------------------------

story_line() { # story_line FILE  → "[EE-SS] Title (SIZE)"
  local id title size
  id=$(fm "$1" id); title=$(fm "$1" title); size=$(fm "$1" size)
  printf '[%s] %s%s' "$id" "$title" "$([ -n "$size" ] && printf ' (%s)' "$size")"
}

epic_stories() { # epic_stories EPICDIR — sorted story files
  find "$1/stories" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort
}

# epic_body EPICDIR OUTFILE MODE — `epics` uses [EE-SS] tokens, `stories` uses issue
# refs (falling back to #TBD for any story not yet created).
epic_body() {
  local dir="$1" out="$2" style="$3" ef="$1/EPIC.md" list="" sf id num
  : > "$out"
  add_section "$out" "Description" "$(section "$ef" Description)"
  add_section "$out" "Goals" "$(section "$ef" Goals)"

  for sf in $(epic_stories "$dir"); do
    if [ "$style" = "stories" ]; then
      id=$(fm "$sf" id)
      num=""
      [ -f "$WORK/storymap/$id" ] && num=$(cat "$WORK/storymap/$id")
      [ -n "$num" ] || num="TBD"
      list="$list- [ ] #$num - $(fm "$sf" title)
"
    else
      list="$list- [ ] $(story_line "$sf")
"
    fi
  done
  add_section "$out" "Stories" "$list"
  add_section "$out" "Acceptance Criteria" "$(section "$ef" 'Acceptance Criteria')"
  add_section "$out" "Technical Notes" "$(section "$ef" 'Technical Notes')"
}

story_body() { # story_body STORYFILE OUTFILE EPICNUM EPICTITLE
  local sf="$1" out="$2" enum="$3" etitle="$4" eissue="" deps files
  : > "$out"
  [ -f "$WORK/epicmap/$enum" ] && eissue=$(cat "$WORK/epicmap/$enum")
  if [ -n "$eissue" ]; then
    add_section "$out" "Parent Epic" "Belongs to #$eissue - $etitle"
  else
    add_section "$out" "Parent Epic" "Belongs to Epic $enum - $etitle"
  fi
  add_section "$out" "Description" "$(section "$sf" Description)"
  add_section "$out" "Acceptance Criteria" "$(section "$sf" 'Acceptance Criteria')"
  add_section "$out" "Technical Notes" "$(section "$sf" 'Technical Notes')"
  files=$(fmt_list "$(fm "$sf" files)")
  add_section "$out" "Files" "$files"
  deps=$(fmt_list "$(fm "$sf" blocked_by)")
  add_section "$out" "Dependencies" "$deps"
  printf '## Size: %s\n' "$(fm "$sf" size)" >> "$out"
}

# ---------------------------------------------------------------------------
# MODE feature — one issue, no write-back
# ---------------------------------------------------------------------------

if [ "$MODE" = "feature" ]; then
  BODY="$WORK/body.md"
  : > "$BODY"
  OV=""
  if [ -n "$OVERVIEW" ]; then
    OV=$(section "$OVERVIEW" Vision)
    [ -n "$OV" ] || OV=$(section "$OVERVIEW" Overview)
    [ -n "$OV" ] || OV=$(section "$OVERVIEW" Description)
  fi
  add_section "$BODY" "Overview" "$OV"

  for dir in $EPIC_DIRS; do
    ef="$dir/EPIC.md"
    [ -f "$ef" ] || { warn "no EPIC.md in $dir — epic skipped"; continue; }
    enum=$(fm "$ef" epic); etitle=$(fm "$ef" title)
    block="$(fm "$ef" description)

"
    for sf in $(epic_stories "$dir"); do
      block="$block- [ ] $(story_line "$sf")
"
    done
    add_section "$BODY" "Epic $enum: $etitle" "$block"
  done

  [ -n "$OVERVIEW" ] && add_section "$BODY" "Acceptance Criteria" "$(section "$OVERVIEW" 'Acceptance Criteria')"

  if num=$(create_issue "$BODY" "Feature: $PROJECT_NAME" feature); then
    CREATED=$((CREATED + 1))
    [ "$DRY" -eq 0 ] && echo "feature #$num created — $PROJECT_NAME"
  else
    FAILURES=$((FAILURES + 1))
  fi
  summary
  exit "$(( FAILURES == 0 ? 0 : 1 ))"
fi

# ---------------------------------------------------------------------------
# MODE epics / stories — epic issues first (story bodies cross-reference them)
# ---------------------------------------------------------------------------

for dir in $EPIC_DIRS; do
  ef="$dir/EPIC.md"
  [ -f "$ef" ] || { warn "no EPIC.md in $dir — epic skipped"; continue; }
  enum=$(fm "$ef" epic)
  [ -n "$enum" ] || { warn "no 'epic:' in $ef — epic skipped"; continue; }
  etitle=$(fm "$ef" title)
  existing=$(fm "$ef" issue)

  if [ -n "$existing" ]; then
    echo "$existing" > "$WORK/epicmap/$enum"
    REUSED=$((REUSED + 1))
    echo "epic $enum #$existing reused"
    continue
  fi

  BODY="$WORK/epic.$enum.md"
  epic_body "$dir" "$BODY" "$MODE"
  if ! num=$(create_issue "$BODY" "Epic $enum: $etitle" epic); then
    FAILURES=$((FAILURES + 1)); continue
  fi
  CREATED=$((CREATED + 1))
  [ "$DRY" -eq 1 ] && continue
  echo "$num" > "$WORK/epicmap/$enum"
  set_fm "$ef" issue "$num" && echo "epic $enum #$num created → $ef"
done

if [ "$MODE" = "epics" ]; then
  [ "$RUN_INDEX" -eq 1 ] && [ "$DRY" -eq 0 ] && [ "$WRITTEN" -gt 0 ] && "$here/ck-index.sh" "$PLAN"
  summary
  exit "$(( FAILURES == 0 ? 0 : 1 ))"
fi

# --- story issues, in epic order then story order -------------------------

for dir in $EPIC_DIRS; do
  ef="$dir/EPIC.md"
  [ -f "$ef" ] || continue
  enum=$(fm "$ef" epic); etitle=$(fm "$ef" title)
  [ -n "$enum" ] || continue

  for sf in $(epic_stories "$dir"); do
    id=$(fm "$sf" id)
    [ -n "$id" ] || { warn "no 'id:' in $sf — story skipped"; continue; }
    stitle=$(fm "$sf" title); size=$(fm "$sf" size)
    existing=$(fm "$sf" issue)

    if [ -n "$existing" ]; then
      echo "$existing" > "$WORK/storymap/$id"
      REUSED=$((REUSED + 1))
      echo "story $id #$existing reused"
      continue
    fi

    BODY="$WORK/story.$id.md"
    story_body "$sf" "$BODY" "$enum" "$etitle"
    if [ -n "$size" ]; then
      num=$(create_issue "$BODY" "[$id] $stitle" story "size/$size") || num=""
    else
      num=$(create_issue "$BODY" "[$id] $stitle" story) || num=""
    fi
    if [ -z "$num" ]; then FAILURES=$((FAILURES + 1)); continue; fi
    CREATED=$((CREATED + 1))
    [ "$DRY" -eq 1 ] && continue
    echo "$num" > "$WORK/storymap/$id"
    set_fm "$sf" issue "$num" && echo "story $id #$num created → $sf"
  done
done

# --- attach each story issue to its epic as a native sub-issue -------------
# The `- [ ] #N` checklist in the epic body is a *description*; a sub-issue is a
# real relation, which is what gives the epic a progress bar and lets a Projects
# board roll story cards up to their epic.
#
# Runs on every publish, and is what back-fills a plan published before this
# existed: already-attached stories are skipped, so re-running costs one read per
# epic and creates nothing. The REST endpoint wants the sub-issue's *database id*,
# not its number, so all ids are fetched in one paginated call rather than one
# `issue view` per story.
link_subissues() {
  local dir ef enum eissue sf sid dbid attached n
  [ "$DRY" -eq 1 ] && return 0

  gh api --paginate "repos/$REPO/issues?state=all&per_page=100" \
    --jq '.[] | select(.pull_request == null) | [(.number|tostring), (.id|tostring)] | @tsv' 2>/dev/null \
    | while IFS="$(printf '\t')" read -r n dbid; do
        [ -n "$n" ] && printf '%s' "$dbid" > "$WORK/dbid.$n"
      done

  ls "$WORK"/dbid.* >/dev/null 2>&1 || {
    warn "could not read issue ids for $REPO — sub-issue links skipped"
    return 0
  }

  for dir in $EPIC_DIRS; do
    ef="$dir/EPIC.md"
    [ -f "$ef" ] || continue
    enum=$(fm "$ef" epic)
    eissue=$(fm "$ef" issue)
    [ -n "$eissue" ] || continue

    attached=$(gh api "repos/$REPO/issues/$eissue/sub_issues" --jq '.[].number' 2>/dev/null)
    pace

    for sf in $(epic_stories "$dir"); do
      sid=$(fm "$sf" issue)
      [ -n "$sid" ] || continue
      printf '%s\n' "$attached" | grep -qx "$sid" && continue
      dbid=""
      [ -f "$WORK/dbid.$sid" ] && dbid=$(cat "$WORK/dbid.$sid")
      [ -n "$dbid" ] || { warn "no id for issue #$sid — not linked to epic #$eissue"; continue; }
      if gh api --method POST "repos/$REPO/issues/$eissue/sub_issues" \
           -F sub_issue_id="$dbid" >/dev/null 2>&1; then
        LINKED=$((LINKED + 1))
        echo "story #$sid linked as a sub-issue of epic $enum #$eissue"
      else
        warn "could not link #$sid under epic #$eissue"
      fi
      pace
    done
  done
}

link_subissues

# --- relink epic bodies with the real story numbers -----------------------
# Runs every time, from the current numbers: this is what repairs a run that died
# between the story issues and the relink.

if [ "$DRY" -eq 0 ]; then
  for dir in $EPIC_DIRS; do
    ef="$dir/EPIC.md"
    [ -f "$ef" ] || continue
    enum=$(fm "$ef" epic)
    eissue=$(fm "$ef" issue)
    [ -n "$eissue" ] || continue

    BODY="$WORK/relink.$enum.md"
    epic_body "$dir" "$BODY" stories
    # shellcheck disable=SC2086
    if gh issue edit "$eissue" $GH_REPO_ARGS --body-file "$BODY" >/dev/null 2>&1; then
      echo "epic $enum #$eissue relinked"
    else
      fail "relink failed for epic $enum (#$eissue)"
    fi
    pace
  done
fi

[ "$RUN_INDEX" -eq 1 ] && [ "$DRY" -eq 0 ] && [ "$WRITTEN" -gt 0 ] && "$here/ck-index.sh" "$PLAN"

summary
exit "$(( FAILURES == 0 ? 0 : 1 ))"
