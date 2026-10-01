#!/usr/bin/env bash
# ck-team.sh — the team-skill refresh contract, for skills that cannot source the library.
#
# Usage:
#   ck-team.sh digest             # the SOURCES digest /ck-code:team stamps into every owned skill
#   ck-team.sh stale              # owned skills whose stamp no longer matches, one path per line
#   ck-team.sh stack              # the code's current stack fingerprint (deps by major + folders)
#   ck-team.sh drift [--relevant] # what moved since the last snapshot; --relevant: only what
#                                 #   a guide, tech-stack.md or guide-conventions already covers
#   ck-team.sh snapshot           # record the current fingerprint as the team's baseline
#   ck-team.sh restamp FILE…      # move owned skills onto the current digest, body untouched
set -uo pipefail
CK_HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck source=scripts/lib/ck-common.sh
. "$CK_HERE/lib/ck-common.sh"
# shellcheck source=scripts/lib/ck-stack.sh
. "$CK_HERE/lib/ck-stack.sh"
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1
case "${1:-}" in
  digest)   ck_team_digest ;;
  stale)    ck_team_stale ;;
  stack)    ck_stack ;;
  drift)    if [ "${2:-}" = "--relevant" ]; then ck_team_drift_relevant; else ck_team_drift; fi ;;
  snapshot) ck_team_snapshot ;;
  restamp)  shift; ck_team_restamp "$@" ;;
  *) sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
