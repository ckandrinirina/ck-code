#!/usr/bin/env bash
# ck-team.sh — the team-skill refresh contract, for skills that cannot source the library.
#
# Usage:
#   ck-team.sh digest   # the SOURCES digest /ck-code:team stamps into every owned skill
#   ck-team.sh stale    # owned skills whose stamp no longer matches, one path per line
set -uo pipefail
CK_HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck source=scripts/lib/ck-common.sh
. "$CK_HERE/lib/ck-common.sh"
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1
case "${1:-}" in
  digest) ck_team_digest ;;
  stale)  ck_team_stale ;;
  *) sed -n '3,6p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
