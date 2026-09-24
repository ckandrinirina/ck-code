#!/usr/bin/env bash
# ck-story.sh — the one way to mutate story state, and regenerate in the same breath.
#
# Story frontmatter is the single writable source of truth; every index and every board
# card is a generated view of it (references/data-model.md). That makes ONE invariant
# load-bearing across `build`, `fix`, `ship`, `doctor --fix` and `config`:
#
#   change frontmatter  →  run ck-index  →  run ck-project sync,  in the same phase.
#
# Here it is one call that cannot be half-done.
#
# Usage:
#   ck-story.sh set   <story.md> [<story.md>…] key=value [key=value…] [--no-sync|--no-board]
#   ck-story.sh files <story.md> <path> [<path>…]
#   ck-story.sh get   <story.md> [key…]
#
# set    Paths and key=value pairs may be interleaved, so a whole wave flips in one call:
#        `ck-story set status=in-progress a.md b.md c.md`. Mutable keys are ONLY the state
#        fields skills flip — status, prior_status, delivery, pr, issue, size. Structural
#        fields (id, epic, title, blocked_by) belong to `plan`/`migrate` and are refused:
#        a typo in `id` or `blocked_by` is not a state change, it is a corrupted plan.
# files  Merge paths into the story's `files:` list (sorted, de-duplicated, never
#        shrunk). `build` records every file a story actually touched, which is what
#        parallel conflict detection and expert-skill matching read.
# get    Print frontmatter keys (all of them when none is named).
#
# --no-sync   edit frontmatter only; indexes and board are left alone
# --no-board  regenerate the indexes but skip `ck-project sync`
#
# Inside a linked worktree on a story/ or fix/ branch (a build PARALLEL MODE implementer)
# the board sync is always skipped: that checkout sees only its own story, and the
# orchestrator syncs every card once the wave is merged.

set -uo pipefail

CK_HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck source=scripts/lib/ck-common.sh
. "$CK_HERE/lib/ck-common.sh"

ck_root || true

usage() { sed -n '3,33p' "$0" | sed 's/^# \{0,1\}//'; }

MUTABLE="status prior_status delivery pr issue size"

die() { echo "ck-story: ERROR — $*" >&2; exit 1; }

# validate KEY VALUE — enums come straight from references/data-model.md.
validate() {
  local k="$1" v="$2"
  case " $MUTABLE " in *" $k "*) ;; *) die "\`$k\` is not a mutable field. Allowed: $MUTABLE (files: use \`ck-story files\`)" ;; esac
  case "$k" in
    status)
      case "$v" in todo|in-progress|done|skip|bug) ;; *) die "status must be todo|in-progress|done|skip|bug (got: $v)" ;; esac ;;
    prior_status)
      case "$v" in ""|todo|in-progress|done|skip|bug) ;; *) die "prior_status must be empty or todo|in-progress|done|skip|bug (got: $v)" ;; esac ;;
    delivery)
      case "$v" in ""|pr|merged|direct) ;; *) die "delivery must be empty|pr|merged|direct (got: $v)" ;; esac ;;
    size)
      case "$v" in S|M) ;; *) die "size must be S or M (got: $v)" ;; esac ;;
    pr|issue)
      case "$v" in ""|*[!0-9]*) [ -z "$v" ] || die "$k must be a number or empty (got: $v)" ;; esac ;;
  esac
}

# regenerate PLANS NO_BOARD — the views, then (unless told not to) the board.
regenerate() {
  local plans="$1" no_board="$2" p idx_err idx_rc out rc
  while IFS= read -r p; do
    [ -n "$p" ] && [ -d "$p" ] || continue
    # Capture stderr only so a `ck-index: WARN —` line still reaches the caller.
    idx_err="$(ck_run ck-index "$p" 2>&1 >/dev/null)"
    idx_rc=$?
    if [ "$idx_rc" -eq 0 ]; then
      echo "ck-story: regenerated $p/STORIES_INDEX.md + tasks/EPICS_INDEX.md"
    else
      echo "ck-story: WARN — could not run ck-index for $p; the generated views are now stale." >&2
    fi
    [ -n "$idx_err" ] && printf '%s\n' "$idx_err" >&2
    [ "$no_board" -eq 1 ] && continue
    if ck_in_story_worktree; then
      echo "ck-story: story worktree — board sync left to the orchestrator after the merge."
      continue
    fi
    # Never fatal: a board that is down must not block a build. ck-project decides for
    # itself whether there is a board; its last line says what it did.
    out=$(ck_run ck-project sync "$p" 2>&1)
    rc=$?
    if [ "$rc" -eq 127 ]; then
      echo "ck-story: WARN — ck-project not found; delivery and board not synced." >&2
    elif [ "$rc" -ne 0 ]; then
      echo "ck-story: WARN — ck-project sync reported a failure (board may lag):" >&2
      printf '%s\n' "$out" | tail -3 >&2
    else
      printf '%s\n' "$out" | tail -1
    fi
  done <<<"$plans"
}

CMD="${1:-}"; [ -n "$CMD" ] && shift
case "$CMD" in
  -h|--help|"") usage; exit 0 ;;

  get)
    F="${1:-}"; [ -f "$F" ] || die "no such story file: ${F:-<empty>}"
    shift
    if [ "$#" -eq 0 ]; then
      ck_fm_dump "$F"
    else
      for k in "$@"; do printf '%s: %s\n' "$k" "$(ck_fm "$F" "$k")"; done
    fi
    exit 0
    ;;

  files)
    F="${1:-}"; [ -f "$F" ] || die "no such story file: ${F:-<empty>}"
    shift
    [ "$#" -gt 0 ] || die "files needs at least one path (usage: ck-story files <story.md> <path>…)"
    old="$(ck_fm "$F" files)"
    merged="$( { ck_flow_list "$old"; for p in "$@"; do printf '%s\n' "${p#./}"; done; } | grep -v '^$' | LC_ALL=C sort -u)"
    new="[$(printf '%s\n' "$merged" | awk 'NR>1{printf ", "} {printf "%s", $0}')]"
    if [ "$new" = "$old" ]; then
      echo "ck-story: files already current — no change"
      exit 0
    fi
    ck_fm_set "$F" files "$new" || die "could not write files: to $F"
    echo "ck-story: $(ck_fm "$F" id): files $old → $new"
    exit 0
    ;;

  set) ;;
  *) die "unknown command: $CMD (set|files|get)" ;;
esac

# ---- set ---------------------------------------------------------------------
FILES=""
KEYS=""
VALS=""
NO_SYNC=0
NO_BOARD=0
for arg in "$@"; do
  case "$arg" in
    --no-sync)  NO_SYNC=1 ;;
    --no-board) NO_BOARD=1 ;;
    *=*)
      k="${arg%%=*}"; v="${arg#*=}"
      validate "$k" "$v"
      KEYS="$KEYS$k"$'\n'; VALS="$VALS$v"$'\n' ;;
    *)
      [ -f "$arg" ] || die "no such story file: $arg"
      FILES="$FILES$arg"$'\n' ;;
  esac
done
[ -n "$FILES" ] || die "no story file given (usage: ck-story set <story.md> key=value)"
[ -n "$KEYS" ]  || die "no key=value given (allowed: $MUTABLE)"

PLANS=""
SUMMARY=""
FAILED=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  sid="$(ck_fm "$f" id)"; [ -n "$sid" ] || sid="$(basename "$f")"
  changes=""
  i=0
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    i=$((i+1))
    v="$(printf '%s' "$VALS" | sed -n "${i}p")"
    old="$(ck_fm "$f" "$k")"
    [ "$old" = "$v" ] && continue
    if ! ck_fm_set "$f" "$k" "$v"; then
      FAILED=$((FAILED+1))
      continue
    fi
    changes="$changes${changes:+, }$k ${old:-∅} → ${v:-∅}"
  done <<<"$KEYS"
  if [ -n "$changes" ]; then
    SUMMARY="$SUMMARY  $sid: $changes"$'\n'
  else
    SUMMARY="$SUMMARY  $sid: already current — no change"$'\n'
  fi
  p="$(ck_plan_of "$f")"
  case "$PLANS" in *"$p"$'\n'*) ;; *) PLANS="$PLANS$p"$'\n' ;; esac
done <<<"$FILES"

printf 'ck-story: updated\n%s' "$SUMMARY"

if [ "$NO_SYNC" -eq 1 ]; then
  echo "ck-story: --no-sync — indexes and board NOT regenerated."
else
  regenerate "$PLANS" "$NO_BOARD"
fi

if [ "$FAILED" -gt 0 ]; then
  echo "ck-story: ERROR — $FAILED write(s) failed; see the messages above." >&2
  exit 1
fi
exit 0
