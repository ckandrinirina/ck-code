#!/usr/bin/env bash
# ck-reclaim.sh — free the disk a linked worktree's build output holds, keeping its source.
#
# A kept PARALLEL MODE worktree (held, conflicted, blocked) must keep its commits and
# working tree, but its target/, node_modules/ and other rebuildable output can run to
# several GB each — a Tauri target/ alone is often 5–20 GB. This deletes only directories
# ck_build_dirs proves rebuildable (gitignored, no tracked file), and prints one line so
# a caller's context stays small.
#
# Usage:
#   ck-reclaim.sh <worktree-path>…
#
# Refuses the main checkout: its build cache is the user's, and a full rebuild costs them
# minutes. Exit 0 on success, 1 when any path was refused.

set -uo pipefail

CK_HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck source=scripts/lib/ck-common.sh
. "$CK_HERE/lib/ck-common.sh"

case "${1:-}" in
  -h|--help|"") sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

rc=0
for wt in "$@"; do
  wt="${wt%/}"
  if [ ! -d "$wt" ]; then echo "ck-reclaim: $wt — no such directory, skipped"; rc=1; continue; fi
  if ! ck_is_linked_worktree "$wt"; then
    echo "ck-reclaim: $wt — not a linked worktree, refused (the main checkout's build cache is never touched)"
    rc=1; continue
  fi
  dirs=()
  while IFS= read -r d; do [ -n "$d" ] && dirs+=("$d"); done < <(ck_build_dirs "$wt")
  if [ "${#dirs[@]}" -eq 0 ]; then echo "ck-reclaim: nothing to free in $wt"; continue; fi
  kb="$(ck_kb_of "${dirs[@]}")"
  rm -rf "${dirs[@]}"
  awk -v kb="$kb" -v n="${#dirs[@]}" -v wt="$wt" 'BEGIN{
    if (kb >= 1048576) s = sprintf("%.1f GB", kb/1048576); else s = sprintf("%d MB", kb/1024)
    printf "ck-reclaim: freed %s (%d build dir(s)) in %s — source and commits kept\n", s, n, wt }'
done
exit "$rc"
