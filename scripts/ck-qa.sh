#!/usr/bin/env bash
# ck-qa.sh — run QA commands once per code state, and never twice on the same one.
#
# Usage:
#   ck-qa.sh state
#   ck-qa.sh run <id> [--parallel] [--reuse] <label>=<command> [<label>=<command>…]
#
# state  prints the code-state id: the git tree of the working copy, untracked
#        (non-ignored) files included, so an uncommitted change is a different state.
# run    runs each command from the current directory, output to
#        ${TMPDIR:-/tmp}/ck-<id>-<label>.log, and stamps every pass with
#        (state, directory, command). --reuse reports a command already passed on that
#        exact triple as REUSED instead of running it. --parallel runs them concurrently
#        and reports every failure; the default is in order, stopping at the first one.
#        Prints one line per command, the last 40 log lines of each failure, then
#        `ck-qa: PASS` (exit 0) or `ck-qa: FAIL — <labels>` (exit 1).

set -uo pipefail

die() { echo "ck-qa: ERROR — $*" >&2; exit 2; }
TMP="${TMPDIR:-/tmp}"; TMP="${TMP%/}"
STAMPS="$TMP/ck-qa"

# The tree id of the working copy, computed in a throwaway index so the real one is never
# touched. Prints nothing outside a git repository — a state that can never be reused.
state() {
  local top idx real
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  idx="$(mktemp "$TMP/ck-qa-index.XXXXXX")" || return 0
  real="$(git -C "$top" rev-parse --path-format=absolute --git-path index 2>/dev/null)"
  if [ -f "$real" ]; then cp "$real" "$idx"; else rm -f "$idx"; fi
  ( cd "$top" && GIT_INDEX_FILE="$idx" git add -A >/dev/null 2>&1 && GIT_INDEX_FILE="$idx" git write-tree 2>/dev/null )
  rm -f "$idx"
}

stamp_of() { printf '%s\n%s\n%s\n' "$1" "$(pwd -P)" "$2" | git hash-object --stdin; }

CMD="${1:-}"
case "$CMD" in
  state) state; exit 0 ;;
  run) ;;
  -h|--help|"") sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) die "unknown command: $CMD (state|run)" ;;
esac
shift
ID="${1:-}"; [ -n "$ID" ] || die "run needs an id (the story id, e.g. 02-05)"; shift

PARALLEL=0; REUSE=0; LABELS=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --parallel) PARALLEL=1 ;;
    --reuse) REUSE=1 ;;
    *=*) l="${1%%=*}"
         case "$l" in ""|*[!A-Za-z0-9_-]*) die "label must be [A-Za-z0-9_-]+ (got: $l)" ;; esac
         LABELS="$LABELS $l"; eval "CMD_$l=\"\${1#*=}\"" ;;
    *) die "expected <label>=<command>, got: $1" ;;
  esac
  shift
done
[ -n "$LABELS" ] || die "no <label>=<command> given"
mkdir -p "$STAMPS" || die "cannot create $STAMPS"

cmd_of() { eval "printf '%s' \"\$CMD_$1\""; }
log_of() { printf '%s/ck-%s-%s.log' "$TMP" "$ID" "$1"; }

S0="$(state)"
RESULT=""   # "<label>:<PASS|FAIL|REUSED|SKIPPED>" words

run_one() {  # label → writes the exit code to <log>.rc
  local l="$1" log; log="$(log_of "$l")"
  bash -c "$(cmd_of "$l")" >"$log" 2>&1
  echo $? >"$log.rc"
}

TORUN=""
for l in $LABELS; do
  if [ "$REUSE" = 1 ] && [ -n "$S0" ] && [ -f "$STAMPS/$(stamp_of "$S0" "$(cmd_of "$l")")" ]; then
    RESULT="$RESULT $l:REUSED"
  else
    TORUN="$TORUN $l"
  fi
done

if [ "$PARALLEL" = 1 ]; then
  for l in $TORUN; do run_one "$l" & done
  wait
else
  stop=0
  for l in $TORUN; do
    if [ "$stop" = 1 ]; then rm -f "$(log_of "$l").rc"; continue; fi
    run_one "$l"
    [ "$(cat "$(log_of "$l").rc")" = 0 ] || stop=1
  done
fi

S1="$(state)"
[ "$S0" = "$S1" ] || echo "ck-qa: WARN — a command changed the working tree (formatter, snapshot update?); nothing stamped, fix that before trusting a PASS"

FAILED=""
for l in $TORUN; do
  rc_file="$(log_of "$l").rc"
  if [ ! -f "$rc_file" ]; then RESULT="$RESULT $l:SKIPPED"; continue; fi
  rc="$(cat "$rc_file")"; rm -f "$rc_file"
  if [ "$rc" = 0 ]; then
    RESULT="$RESULT $l:PASS"
    [ -n "$S0" ] && [ "$S0" = "$S1" ] && : >"$STAMPS/$(stamp_of "$S0" "$(cmd_of "$l")")"
  else
    RESULT="$RESULT $l:FAIL"; FAILED="$FAILED $l"
  fi
done

for r in $RESULT; do
  l="${r%%:*}"; v="${r#*:}"
  case "$v" in
    REUSED)  echo "$l: REUSED — already passed on this code state here" ;;
    SKIPPED) echo "$l: SKIPPED — an earlier command failed" ;;
    *)       echo "$l: $v — log $(log_of "$l")" ;;
  esac
done
for l in $FAILED; do
  echo "--- $l (last 40 lines of $(log_of "$l")) ---"
  tail -n 40 "$(log_of "$l")"
done

if [ -n "$FAILED" ]; then echo "ck-qa: FAIL —${FAILED}"; exit 1; fi
echo "ck-qa: PASS"
