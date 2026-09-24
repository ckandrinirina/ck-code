#!/usr/bin/env bash
# ck-qa.sh — run QA commands once per code state, and never twice on the same one.
#
# Usage:
#   ck-qa.sh state
#   ck-qa.sh run <id> [--parallel] [--reuse] <label>=<command> [<label>=<command>…]
#   ck-qa.sh wait <id>
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
#        The commands run detached, and run waits up to CK_QA_WAIT seconds (default 540,
#        under the 600 s cap of one agent Bash call). A longer run prints
#        `ck-qa: RUNNING` (exit 3) and keeps going. The same run started again while it
#        is going waits on it instead of starting a second copy.
# wait   waits up to CK_QA_WAIT seconds more on the run for <id> and prints its result,
#        or RUNNING again. Once it has ended, wait prints that result again.

set -uo pipefail

die() { echo "ck-qa: ERROR — $*" >&2; exit 2; }
TMP="${TMPDIR:-/tmp}"; TMP="${TMP%/}"
STAMPS="$TMP/ck-qa"
RUNS="$TMP/ck-qa-run"
SELF="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")"

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

# Waits on the run for $1 for up to CK_QA_WAIT seconds, then prints its result and exits
# with its code, or prints RUNNING and exits 3 while it is still going.
await_run() {
  local d="$RUNS/$1" budget="${CK_QA_WAIT:-540}" t0=$SECONDS
  [ -f "$d/pid" ] || die "no ck-qa run for $1 — start it with ck-qa run $1 …"
  while [ ! -f "$d/rc" ]; do
    if ! kill -0 "$(cat "$d/pid")" 2>/dev/null; then
      [ -f "$d/rc" ] && break
      die "the ck-qa run for $1 stopped without a result — start it again with ck-qa run"
    fi
    if [ $((SECONDS - t0)) -ge "$budget" ]; then
      echo "ck-qa: RUNNING — $1 has run $(( $(date +%s) - $(cat "$d/start") ))s; run 'ck-qa wait $1' to keep waiting, never start it again"
      exit 3
    fi
    sleep 2
  done
  cat "$d/out"
  exit "$(cat "$d/rc")"
}

CMD="${1:-}"
case "$CMD" in
  state) state; exit 0 ;;
  wait) [ -n "${2:-}" ] || die "wait needs an id"; await_run "$2" ;;
  run|__worker) ;;
  -h|--help|"") sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) die "unknown command: $CMD (state|run|wait)" ;;
esac
shift
ARGS=("$@")
ID="${1:-}"; [ -n "$ID" ] || die "run needs an id (the story id, e.g. 02-05)"; shift
case "$ID" in */*|.|..) die "id must not contain / (got: $ID)" ;; esac

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
mkdir -p "$STAMPS" "$RUNS" || die "cannot create $STAMPS"

cmd_of() { eval "printf '%s' \"\$CMD_$1\""; }

# run: start the commands detached, so a run longer than one Bash call survives it, and
# wait on it. An identical run already going is waited on, never started a second time.
if [ "$CMD" = run ]; then
  D="$RUNS/$ID"
  KEY="$( { pwd -P; echo "$PARALLEL $REUSE"; for l in $LABELS; do echo "$l=$(cmd_of "$l")"; done; } | git hash-object --stdin)"
  if [ -f "$D/pid" ] && [ ! -f "$D/rc" ] && kill -0 "$(cat "$D/pid")" 2>/dev/null; then
    [ "$(cat "$D/key" 2>/dev/null)" = "$KEY" ] \
      || die "a different ck-qa run for $ID is still going — ck-qa wait $ID first"
    echo "ck-qa: $ID is already running — waiting on that run, not starting another"
  else
    rm -rf "$D"; mkdir -p "$D" || die "cannot create $D"
    echo "$KEY" >"$D/key"; date +%s >"$D/start"
    D="$D" nohup bash -c '"$0" __worker "$@" >"$D/out" 2>&1; echo $? >"$D/rc.tmp"; mv "$D/rc.tmp" "$D/rc"' \
      "$SELF" "${ARGS[@]}" </dev/null >/dev/null 2>&1 &
    echo $! >"$D/pid"
  fi
  await_run "$ID"
fi

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
