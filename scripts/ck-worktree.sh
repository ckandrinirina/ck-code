#!/usr/bin/env bash
# ck-worktree.sh — lift Claude Code's agent lock from a finished worktree, and retire the
# merged, clean agent worktrees earlier runs left behind.
#
# Usage:
#   ck-worktree.sh unlock <path>
#   ck-worktree.sh sweep <target> [--list]
#   ck-worktree.sh submodules <root>
#
# unlock  lifts a "claude agent … (pid N)" lock when N is gone or is this session, so a merged
#         worktree can be removed before the session exits. Any other lock is kept (exit 1).
# sweep   retires every agent worktree under .claude/worktrees/ whose branch is 0 commits ahead
#         of <target>, clean, and untouched for 15 min; prints one line per worktree and a count.
#         --list only names them. Worktrees made by hand, elsewhere, are never touched.
# submodules  fills a fresh worktree's empty submodules, each cloned against <root>'s checkout
#         (--reference, then --dissociate so the worktree never depends on it), the rest the
#         plain way.
#
# Exit 0 on success, 1 when a lock or a worktree was kept, 2 on a usage error.

set -uo pipefail

die() { echo "ck-worktree: ERROR — $*" >&2; exit 2; }
CK_HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
# its test containers and their volumes outlive the directory otherwise
wt_free() { "$CK_HERE/ck-qa.sh" docker-free "$1"; }

# >>> ck-wt — keep this block byte-identical in ck-code's ck-worktree.sh and ck-code-lite's ck-lite
# Claude Code locks each agent worktree "claude agent agent-<id> (pid <N>)" for the life of the
# session process N, not of the agent: a merged worktree stays locked until the session exits.
# wt_unlock lifts that lock only when N is gone or is this very session (an ancestor of this
# shell, whose agents the caller has collected). Any other lock, or one held by another live
# session, is kept and printed (exit 1). The caller defines wt_free <path> (its docker-free).
wt_lock_reason() {  # path → prints the lock reason; exit 1 when the worktree is not locked
  git worktree list --porcelain | awk -v w="$1" '
    /^worktree /{ c = (substr($0, 10) == w) }
    c && /^locked/{ r = $0; sub(/^locked ?/, "", r); print r; f = 1 }
    END { exit !f }'
}
wt_ancestor() {  # pid → exit 0 when it is this shell or one of its ancestors
  local p=$$
  while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null; do
    [ "$p" = "$1" ] && return 0
    p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
  done
  return 1
}
wt_unlock() {  # path → unlocks a lifted claude-agent lock; exit 1 with the reason when kept
  local r pid
  r="$(wt_lock_reason "$1")" || return 0
  case "$r" in "claude agent "*"(pid "*")") ;; *) echo "locked (${r:-no reason})"; return 1 ;; esac
  pid="${r##*(pid }"; pid="${pid%)}"
  case "$pid" in ""|*[!0-9]*) echo "locked ($r)"; return 1 ;; esac
  if kill -0 "$pid" 2>/dev/null && ! wt_ancestor "$pid"; then
    echo "locked by another live Claude Code session (pid $pid)"; return 1
  fi
  git worktree unlock "$1" >/dev/null 2>&1 || { echo "unlock failed"; return 1; }
}
# wt_sweep <target> <0|1> — agent worktrees (under .claude/worktrees/) left by earlier runs.
# One whose branch is 0 commits ahead of <target>, with a clean tree and untouched for 15 min,
# holds nothing that can be lost: 1 lists it as stale, 0 retires it (lock lifted as above,
# wt_free, remove, git branch -d). Every other worktree is printed as kept with its reason and
# never touched — a hand-made worktree outside .claude/worktrees/ is not even listed.
wt_sweep() {
  local wts w b g st ahead why n=0 k=0
  wts="$(git rev-parse --path-format=absolute --git-common-dir)" || return 2
  wts="$(dirname -- "$wts")/.claude/worktrees"
  git worktree prune
  while IFS="$(printf '\t')" read -r w b; do
    case "$w" in "$wts"/*) ;; *) continue ;; esac
    why=""
    # HEAD and its reflog move on every checkout and commit; the index is not read, since a
    # status (ours below included) can rewrite it
    g="$(git -C "$w" rev-parse --absolute-git-dir 2>/dev/null)"
    [ -z "$(find "$g/HEAD" "$g/logs/HEAD" -mmin -15 2>/dev/null)" ] || why="used in the last 15 min"
    ahead="$(git rev-list --count "$1..$b" 2>/dev/null || echo "?")"
    [ -n "$why" ] || [ "$ahead" = 0 ] || why="unmerged ($ahead ahead of $1)"
    # a status that fails prints nothing too — that is never read as clean
    if [ -z "$why" ]; then
      st="$(git -C "$w" --no-optional-locks status --porcelain 2>/dev/null)" || why="git status failed"
      [ -n "$why" ] || [ -z "$st" ] || why="uncommitted changes"
    fi
    if [ -n "$why" ]; then echo "kept $b ($w) — $why"; k=$((k + 1)); continue; fi
    if [ "$2" = 1 ]; then echo "stale $b ($w) — merged into $1, clean"; n=$((n + 1)); continue; fi
    why="$(wt_unlock "$w")" || { echo "kept $b ($w) — $why"; k=$((k + 1)); continue; }
    wt_free "$w" >/dev/null 2>&1
    if ! git worktree remove --force "$w" >/dev/null 2>&1; then
      echo "kept $b ($w) — remove failed"; k=$((k + 1)); continue
    fi
    if git branch -d "$b" >/dev/null 2>&1; then echo "retired $b ($w)"; else echo "retired $w, branch $b kept"; fi
    n=$((n + 1))
  done <<EOF
$(git worktree list --porcelain | awk '/^worktree /{ w = substr($0, 10); n++ } /^branch /{ b = $2; sub("refs/heads/", "", b); if (n > 1) print w "\t" b }')
EOF
  if [ "$2" = 1 ]; then echo "sweep: $n stale · $k kept"; else echo "sweep: $n retired · $k kept"; fi
}
# <<< ck-wt

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"
case "${1:-}" in
  unlock) [ "$#" -eq 2 ] || die "unlock needs <path>"
          why="$(wt_unlock "${2%/}")" || { echo "LOCKED — ${2%/} kept: $why"; exit 1; }
          echo "unlocked ${2%/}" ;;
  sweep) case "$#:${3:-}" in 2:) wt_sweep "$2" 0 ;; 3:--list) wt_sweep "$2" 1 ;; *) die "sweep needs <target> [--list]" ;; esac ;;
  submodules) [ "$#" -eq 2 ] || die "submodules needs <root>"
          [ -f .gitmodules ] || { echo "submodules: none"; exit 0; }
          git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | while read -r _ p; do
            if [ -e "$2/$p/.git" ]; then
              git submodule update --init --reference "$2/$p" --dissociate -- "$p" >/dev/null 2>&1 \
                || echo "submodules: $p — reference clone failed, falling back"
            fi
          done
          git submodule update --init --recursive >/dev/null 2>&1 || { echo "submodules: FAILED — git submodule update --init --recursive"; exit 1; }
          echo "submodules: ready ($(git submodule status --recursive | wc -l | tr -d ' '))" ;;
  -h|--help|"") sed -n '4,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) die "unknown command: $1 (unlock|sweep|submodules)" ;;
esac
