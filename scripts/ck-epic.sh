#!/usr/bin/env bash
# ck-epic.sh — allocate epic numbers (and plan --quick story numbers) that stay unique
# across every branch and every clone, with the git remote as the only shared state.
#
# Reading the next number off the working tree alone is what let two plans both mint epic
# 37: a plan still in a PR, on another branch, or on a teammate's machine is invisible
# there. So a number is the maximum of everything this clone can see, PLUS every
# reservation on the remote, and taking one is an atomic create-only push of a hidden ref:
#
#   refs/ck-code/epics/<NN>       refs/ck-code/stories/<EE>-<SS>
#
# `git push --atomic --force-with-lease=<ref>:` creates the ref only if it does not exist,
# checked by the server under its own lock. Two people reserving at the same moment get
# different numbers: the loser is rejected and retries with the next one. Nothing waits.
# The refs live outside refs/heads and refs/tags, so no branch list, tag list or default
# fetch ever shows them. A reserved number is never released — a cancelled plan leaves a
# gap, and gaps are harmless.
#
# Never blocking is the other half of the contract: no remote, no network, an auth prompt
# or a host that refuses custom refs all degrade to the local + fetched-branch scan with a
# WARN, and still print a number. `ck-doctor` reports any collision that slips through.
#
# Usage:
#   ck-epic.sh next                          print the next free epic number (reserves nothing)
#   ck-epic.sh reserve <count> <tasks/plan>  reserve <count> consecutive epics; print the first
#   ck-epic.sh next-story <EE>               print the next free story number in epic EE
#   ck-epic.sh reserve-story <EE> <tasks/plan>  reserve it; print SS
#   ck-epic.sh check                         list epic and story numbers used by more than one
#                                            plan across the working tree and every local and
#                                            remote-tracking branch (offline; exit 0 always)
#
# Numbers print zero-padded to two digits on stdout; status and WARN lines go to stderr.
# CK_EPIC_OFFLINE=1 skips the network; CK_EPIC_REMOTE overrides the remote (default origin).

set -uo pipefail

CK_HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck source=scripts/lib/ck-common.sh
. "$CK_HERE/lib/ck-common.sh"

ck_root || { r="$(git rev-parse --show-toplevel 2>/dev/null)" && cd "$r"; } || true
die() { echo "ck-epic: ERROR — $*" >&2; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"

REMOTE="${CK_EPIC_REMOTE:-origin}"
NS="refs/ck-code"
TMP="$(mktemp -d 2>/dev/null || mktemp -d -t ck-epic)"
trap 'rm -rf "$TMP"' EXIT

# Never let a network call stop to ask for a password or hang on an unreachable host.
export GIT_TERMINAL_PROMPT=0
[ -n "${GIT_SSH_COMMAND:-}" ] || export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10"

ONLINE=1; REASON=""
if [ "${CK_EPIC_OFFLINE:-0}" = 1 ]; then ONLINE=0; REASON="CK_EPIC_OFFLINE=1"
elif ! git remote get-url "$REMOTE" >/dev/null 2>&1; then ONLINE=0; REASON="no remote \`$REMOTE\`"
fi

pad() { printf '%02d' "$((10#$1))"; }

# fetch — refresh remote branches and mirror every reservation into the local refs/ck-code/*,
# so `next` and `check` see what teammates pushed. A failure only switches to offline.
fetch() {
  [ "$ONLINE" = 1 ] || return 0
  if ! git fetch --quiet --no-tags "$REMOTE" "+refs/heads/*:refs/remotes/$REMOTE/*" "+$NS/*:$NS/*" 2>"$TMP/fetch.err"; then
    ONLINE=0; REASON="fetch from \`$REMOTE\` failed: $(grep -v '^$' "$TMP/fetch.err" | head -1)"
  fi
}

# refs — one ref per distinct tasks/ tree, across every local and remote-tracking branch.
# Many branches share a tree; scanning each tree once keeps this cheap on a busy remote.
refs() {
  : > "$TMP/trees"
  git for-each-ref --format='%(refname)' refs/heads refs/remotes | while IFS= read -r ref; do
    case "$ref" in */HEAD) continue ;; esac
    t="$(git rev-parse -q --verify "$ref:tasks" 2>/dev/null)" || continue
    grep -qx "$t" "$TMP/trees" && continue
    echo "$t" >> "$TMP/trees"
    printf '%s\t%s\n' "$t" "${ref#refs/}"
  done
}

# epic_rows — "NN_slug<TAB>plan/NN_slug<TAB>where" for every epic folder anywhere visible.
epic_rows() {
  find tasks -mindepth 3 -maxdepth 3 -type d -path 'tasks/*/epics/*' 2>/dev/null \
    | awk -F/ '{ printf "%s\t%s/%s\tworking tree\n", $4, $2, $4 }'
  refs | while IFS="$(printf '\t')" read -r t where; do
    git ls-tree -r -d --name-only "$t" 2>/dev/null \
      | awk -F/ -v w="$where" 'NF == 3 && $2 == "epics" { printf "%s\t%s/%s\t%s\n", $3, $1, $3, w }'
  done
}
epic_numbers() { epic_rows | awk -F'\t' '{ n = $1; sub(/_.*/, "", n); if (n ~ /^[0-9]+$/) print n + 0 }'; }

# story_rows EE — "EE-SS<TAB>path<TAB>where" for every story of epic EE anywhere visible,
# from frontmatter `id:` (never the filename: a drifted SS_ prefix would mint a duplicate).
story_rows() {
  local ee="$1" pat
  pat="^id:[[:space:]]*[\"']?${ee}-[0-9]+"
  find tasks -path "tasks/*/epics/${ee}_*/stories/*.md" -type f 2>/dev/null | while IFS= read -r f; do
    grep -m1 -E "$pat" "$f" 2>/dev/null | awk -v f="$f" '{ printf "%s:%s\n", f, $0 }'
  done | id_rows "working tree"
  refs | while IFS="$(printf '\t')" read -r t where; do
    git grep -E "$pat" "$t" -- "*/epics/${ee}_*/stories/*.md" 2>/dev/null \
      | awk -v t="$t:" '{ print "tasks/" substr($0, length(t) + 1) }' | id_rows "$where"
  done
}
# id_rows WHERE — "path:id: EE-SS…" lines in, "EE-SS<TAB>path<TAB>WHERE" out.
id_rows() {
  awk -v w="$1" '{ p = index($0, ":id:"); if (!p) next
    if (match(substr($0, p + 4), /[0-9]+-[0-9]+/)) printf "%s\t%s\t%s\n", substr($0, p + 4 + RSTART - 1, RLENGTH), substr($0, 1, p - 1), w }'
}
story_numbers() { story_rows "$1" | awk -F'\t' '{ sub(/^[0-9]+-/, "", $1); print $1 + 0 }'; }

reserved() { # reserved epics|stories [EE] — numbers already held on the remote (as mirrored)
  git for-each-ref --format='%(refname:lstrip=3)' "$NS/$1" | if [ "$1" = stories ]; then
    awk -F- -v e="$2" '$1 + 0 == e + 0 { print $2 + 0 }'
  else awk '/^[0-9]+$/ { print $1 + 0 }'; fi
}

max_of() { awk 'BEGIN { m = 0 } $1 + 0 > m { m = $1 + 0 } END { print m }'; }
next_epic() { { epic_numbers; reserved epics; } | max_of | awk '{ print $1 + 1 }'; }
next_story() { { story_numbers "$1"; reserved stories "$1"; } | max_of | awk '{ print $1 + 1 }'; }

# push_reserve PLAN REF… — one atomic, create-only push. Returns 0 reserved, 2 taken, 1 other.
push_reserve() {
  local plan="$1" tree commit by args="" r; shift
  by="$(git config user.name 2>/dev/null || echo unknown)"
  tree="$(git hash-object -t tree -w /dev/null)" || return 1
  commit="$(printf 'ck-code reservation\n\nplan: %s\nby: %s\nrefs: %s\nnonce: %s-%s-%s\n' \
    "$plan" "$by" "$*" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$$" "$RANDOM" \
    | git -c user.name="${by}" -c user.email="$(git config user.email 2>/dev/null || echo ck-code@localhost)" commit-tree "$tree")" || return 1
  for r in "$@"; do args="$args --force-with-lease=$r: $commit:$r"; done
  # shellcheck disable=SC2086  # $args is a list of plain ref specs, no spaces inside
  if git push --porcelain --atomic "$REMOTE" $args >"$TMP/push.out" 2>&1; then
    for r in "$@"; do git update-ref "$r" "$commit"; done
    return 0
  fi
  # Taken or refused? Ask the remote rather than parse the message: a race lost on the
  # client says "stale info", one lost on the server says "cannot lock ref", and a host
  # that refuses custom refs says something else again. Any of our refs now existing
  # there means someone holds the number.
  # shellcheck disable=SC2068
  [ -n "$(git ls-remote "$REMOTE" $@ 2>/dev/null)" ] && return 2
  REASON="push to \`$REMOTE\` failed: $(grep -E '^(fatal|error|!|remote:)' "$TMP/push.out" | head -1)"
  return 1
}

warn_unreserved() { # what, numbers
  echo "ck-epic: WARN — $1 $2 NOT reserved on the remote ($REASON). Taken from this clone's" \
       "working tree and fetched branches only; push the plan soon. ck-doctor flags a collision." >&2
}

# reserve_loop KIND PLAN COUNT [EE] — the allocate-or-retry loop shared by epics and stories.
reserve_loop() {
  local kind="$1" plan="$2" count="$3" ee="${4:-}" start i n refs_list rc
  fetch
  for _ in 1 2 3 4 5 6 7 8; do
    if [ "$kind" = epics ]; then start="$(next_epic)"; else start="$(next_story "$ee")"; fi
    if [ "$ONLINE" = 0 ]; then break; fi
    refs_list=""; i=0
    while [ "$i" -lt "$count" ]; do
      n="$(pad $((start + i)))"
      if [ "$kind" = epics ]; then refs_list="$refs_list $NS/epics/$n"; else refs_list="$refs_list $NS/stories/$ee-$n"; fi
      i=$((i + 1))
    done
    # shellcheck disable=SC2086
    push_reserve "$plan" $refs_list; rc=$?
    if [ "$rc" = 0 ]; then
      if [ "$kind" = epics ]; then
        echo "ck-epic: reserved epic(s) $(pad "$start")$([ "$count" -gt 1 ] && echo "–$(pad $((start + count - 1)))") on \`$REMOTE\` for $plan" >&2
      else echo "ck-epic: reserved story $ee-$(pad "$start") on \`$REMOTE\` for $plan" >&2; fi
      pad "$start"; echo; return 0
    fi
    [ "$rc" = 2 ] || { ONLINE=0; break; }
    echo "ck-epic: $(pad "$start") was just taken by someone else — retrying with the next number" >&2
    fetch
  done
  [ "$ONLINE" = 1 ] && { ONLINE=0; REASON="still contended after 8 attempts"; }
  if [ "$kind" = epics ]; then warn_unreserved "epic(s)" "$(pad "$start")+"; else warn_unreserved story "$ee-$(pad "$start")"; fi
  pad "$start"; echo
}

# check — numbers used by more than one plan anywhere this clone can see. Read-only, offline.
check() {
  local out="$TMP/check" ees ee
  : > "$out"
  epic_rows | awk -F'\t' '{ n = $1; sub(/_.*/, "", n); if (n ~ /^[0-9]+$/) print n "\t" $2 "\t" $3 }' \
    | sort -u -t "$(printf '\t')" -k1,2 | awk -F'\t' '
        { key = $1 + 0; if (!(key SUBSEP $2 in seen)) { seen[key SUBSEP $2] = 1; c[key]++; l[key] = l[key] (l[key] == "" ? "" : "  ·  ") $2 " (" $3 ")" } }
        END { for (k in c) if (c[k] > 1) printf "epic %02d: %s\n", k, l[k] }' | sort >> "$out"
  ees="$(epic_numbers | sort -nu)"
  for ee in $ees; do
    ee="$(pad "$ee")"
    story_rows "$ee" \
      | awk -F'\t' 'NF == 3 { if (!($1 SUBSEP $2 in seen)) { seen[$1 SUBSEP $2] = 1; c[$1]++; l[$1] = l[$1] (l[$1] == "" ? "" : "  ·  ") $2 " (" $3 ")" } }
          END { for (k in c) if (c[k] > 1) printf "story %s: %s\n", k, l[k] }' | sort >> "$out"
  done
  cat "$out"
}

CMD="${1:-}"
case "$CMD" in
  next)
    fetch; [ "$ONLINE" = 1 ] || echo "ck-epic: WARN — remote not consulted ($REASON); the number may already be taken elsewhere" >&2
    pad "$(next_epic)"; echo ;;
  next-story)
    [ -n "${2:-}" ] || die "next-story needs an epic number"
    fetch; pad "$(next_story "$(pad "$2")")"; echo ;;
  reserve)
    case "${2:-}" in ''|*[!0-9]*|0) die "reserve needs a positive count" ;; esac
    [ -n "${3:-}" ] || die "reserve needs the plan folder (tasks/<plan>)"
    reserve_loop epics "$(basename "${3%/}")" "$2" ;;
  reserve-story)
    case "${2:-}" in ''|*[!0-9]*) die "reserve-story needs an epic number" ;; esac
    [ -n "${3:-}" ] || die "reserve-story needs the plan folder (tasks/<plan>)"
    reserve_loop stories "$(basename "${3%/}")" 1 "$(pad "$2")" ;;
  check) check ;;
  -h|--help|"") sed -n '3,33p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "unknown command: $CMD (next|reserve|next-story|reserve-story|check)" ;;
esac
