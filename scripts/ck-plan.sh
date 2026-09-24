#!/usr/bin/env bash
# ck-plan.sh — read and set a plan's record, tasks/<plan>/OVERVIEW.md frontmatter.
#
# The plan record carries what belongs to a whole plan: its integration level, the branch
# a plan-level PR comes from, and that PR and issue. Like ck-story for a story, this is the
# one way skills write it, so the enums are checked in one place.
#
# Usage:
#   ck-plan.sh get <tasks/plan> [key…]
#   ck-plan.sh set <tasks/plan> key=value [key=value…]
#
# Mutable keys: integration (story|epic|plan), branch, issue, pr, delivery (|pr|merged|direct).
# Setting integration to plan with no branch yet also records branch: plan/<slug>.

set -uo pipefail

CK_HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck source=scripts/lib/ck-common.sh
. "$CK_HERE/lib/ck-common.sh"

ck_root || true
die() { echo "ck-plan: ERROR — $*" >&2; exit 1; }

CMD="${1:-}"; PLAN="${2:-}"
case "$CMD" in
  get|set) ;;
  -h|--help|"") sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) die "unknown command: $CMD (get|set)" ;;
esac
PLAN="${PLAN%/}"
[ -n "$PLAN" ] && [ -d "$PLAN" ] || die "no such plan directory: ${PLAN:-<empty>}"
OV="$PLAN/OVERVIEW.md"
[ -f "$OV" ] || die "$PLAN has no OVERVIEW.md — run /ck-code:migrate if this is a v6 plan"
shift 2

if [ "$CMD" = get ]; then
  if [ "$#" -eq 0 ]; then ck_fm_dump "$OV"; else for k in "$@"; do printf '%s: %s\n' "$k" "$(ck_fm "$OV" "$k")"; done; fi
  exit 0
fi

[ "$#" -gt 0 ] || die "no key=value given"
for kv in "$@"; do
  case "$kv" in *=*) ;; *) die "expected key=value, got: $kv" ;; esac
  k="${kv%%=*}"; v="${kv#*=}"
  case "$k" in
    integration) case "$v" in story|epic|plan) ;; *) die "integration must be story|epic|plan (got: $v)" ;; esac ;;
    delivery)    case "$v" in ""|pr|merged|direct) ;; *) die "delivery must be empty|pr|merged|direct (got: $v)" ;; esac ;;
    issue|pr)    case "$v" in ""|*[!0-9]*) [ -z "$v" ] || die "$k must be a number or empty (got: $v)" ;; esac ;;
    branch)      ;;
    *) die "\`$k\` is not a mutable plan field (integration, branch, issue, pr, delivery)" ;;
  esac
done
for kv in "$@"; do
  k="${kv%%=*}"; v="${kv#*=}"
  old="$(ck_fm "$OV" "$k")"
  [ "$old" = "$v" ] && { echo "ck-plan: $k already $v"; continue; }
  ck_fm_set "$OV" "$k" "$v" || exit 1
  echo "ck-plan: $PLAN $k ${old:-∅} → ${v:-∅}"
  if [ "$k" = integration ] && [ "$v" = plan ] && [ -z "$(ck_fm "$OV" branch)" ]; then
    slug="$(ck_fm "$OV" slug)"; [ -n "$slug" ] || slug="$(basename "$PLAN" | sed 's/^[0-9-]*_//')"
    ck_fm_set "$OV" branch "plan/$slug" && echo "ck-plan: $PLAN branch ∅ → plan/$slug"
  fi
done
