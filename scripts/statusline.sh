#!/usr/bin/env bash
# ck-code statusLine: renders a compact view of ck-code project state in the
# Claude Code status bar — the active story (derived from the git branch) plus
# plan-wide story counts.
#
# Costs zero tokens by design. The status bar is rendered by the terminal, never
# by the model, so this buys legibility without spending output tokens or
# occupying context — unlike a banner the model would have to print each phase.
#
# Input : the statusLine JSON object on stdin (only `.workspace.current_dir` is read).
# Output: ONE line, or nothing at all outside a ck-code project.
#
# Safe by design: never fails and never blocks a render. `jq` is optional — without
# it the script falls back to $PWD, which is the project dir in the normal case.
# Portable to bash 3.2 (no associative arrays; all aggregation happens in awk).
#
# Install (writes the statusLine key into settings.json):
#   scripts/statusline.sh --install              # ~/.claude/settings.json
#   scripts/statusline.sh --install --project    # .claude/settings.json
#   scripts/statusline.sh --install --force      # replace an existing statusLine
#
# Use as ONE SEGMENT of a status line you already have: pipe the same stdin JSON
# into this script and interpolate its output. It prints nothing (exit 0) when the
# project has no ck-code `tasks/`, so the segment simply disappears.

# ---------------------------------------------------------------- install mode

if [ "${1:-}" = "--install" ]; then
  shift
  scope="user"; force=0
  for arg in "$@"; do
    case "$arg" in
      --project) scope="project" ;;
      --user)    scope="user" ;;
      --force)   force=1 ;;
      *) echo "ck-code statusline: unknown flag '$arg'" >&2; exit 2 ;;
    esac
  done

  command -v jq >/dev/null 2>&1 || {
    echo "ck-code statusline: --install needs jq (settings.json is edited as JSON, never by hand)." >&2
    exit 1
  }

  # Resolve this script's own absolute path — settings.json cannot expand
  # ${CLAUDE_PLUGIN_ROOT}, so the stored command must be absolute.
  self_dir=$(cd "$(dirname "$0")" && pwd -P) || exit 1
  self="$self_dir/$(basename "$0")"

  if [ "$scope" = "project" ]; then
    settings=".claude/settings.json"
    mkdir -p .claude || exit 1
  else
    settings="$HOME/.claude/settings.json"
    mkdir -p "$HOME/.claude" || exit 1
  fi

  [ -f "$settings" ] || printf '{}\n' > "$settings"

  if [ "$force" -eq 0 ] && [ "$(jq -r 'has("statusLine")' "$settings" 2>/dev/null)" = "true" ]; then
    echo "ck-code statusline: $settings already defines statusLine — left untouched." >&2
    echo "  Re-run with --force to replace it, or call this script as one segment of your own." >&2
    exit 1
  fi

  # Rewrite through a temp file and only then take the backup, so a failed edit
  # (invalid JSON, full disk) leaves both the settings and any earlier .bak intact.
  tmp="$settings.tmp.$$"
  if jq --arg cmd "$self" \
       '.statusLine = {type: "command", command: $cmd, refreshInterval: 5}' \
       "$settings" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    cp "$settings" "$settings.bak" 2>/dev/null
    mv "$tmp" "$settings"
    echo "ck-code statusline installed → $settings (previous file kept as $settings.bak)"
    exit 0
  fi
  rm -f "$tmp"
  echo "ck-code statusline: could not update $settings — it may not be valid JSON." >&2
  exit 1
fi

# ---------------------------------------------------------------- render mode

input=$(cat 2>/dev/null)

dir=""
if command -v jq >/dev/null 2>&1; then
  dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // empty' 2>/dev/null)
fi
[ -n "$dir" ] && [ -d "$dir" ] || dir="$PWD"
cd "$dir" 2>/dev/null || exit 0

# Locate tasks/: fall back to the git repo root so a session opened in a
# subdirectory (or a PARALLEL MODE worktree) still resolves the plan.
if [ ! -d tasks ]; then
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  [ -n "$root" ] && [ -d "$root/tasks" ] || exit 0
  cd "$root" 2>/dev/null || exit 0
fi

# No generated index yet → the project is planned but not indexed; say nothing
# rather than render an empty scoreboard.
set -- tasks/*/STORIES_INDEX.md
[ -f "$1" ] || exit 0

# Active story: derived from the branch name, never stored (branch-topology.md).
# story/<EE>-<SS>-<slug> and fix/<EE>-<SS>-<slug> both carry the id outright.
# epic/<NN>-<slug> carries only the epic, so the story is resolved from the index:
# an epic branch is where an `integration: epic|feature` session sits while its
# stories are built, and it names no story of its own.
story_id=""
epic_id=""
# `branch --show-current` (git >= 2.22) is empty on a detached HEAD and, unlike
# `rev-parse --abbrev-ref HEAD`, does not error on an unborn branch.
branch=$(git branch --show-current 2>/dev/null)
[ -n "$branch" ] || branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
case "$branch" in
  story/*|fix/*)
    story_id=$(printf '%s' "${branch#*/}" | awk -F- \
      '$1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ { print $1 "-" $2 }')
    ;;
  epic/*)
    epic_id=$(printf '%s' "${branch#*/}" | awk -F- '$1 ~ /^[0-9]+$/ { print $1 }')
    ;;
esac

# One awk pass over every plan's index: aggregate counts AND the active story's
# title/status. Row shape is `| Epic | ID | Title | Status | Size | Blocked by | File |`,
# so with -F'|' a clean row has NF==9 ($1 and $9 are the empty ends).
#
# Fields are addressed from the RIGHT because a title may legitimately contain a
# `|` (ck-index.sh escapes it as `\|`, which awk still splits on, inflating NF).
# Status/Size/Blocked by/File can never contain one, so NF-4 is always Status.
awk -F'|' -v want="$story_id" -v want_epic="$epic_id" '
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }

  # Rejoin the title fields an escaped pipe was split across, then unescape.
  function title(   i, t) {
    t = $4
    for (i = 5; i <= NF - 5; i++) t = t "|" $i
    gsub(/\\\|/, "|", t)
    return trim(t)
  }

  # awk length()/substr() count bytes, so cutting a long title at a fixed offset
  # can split a multibyte character. Shorten at word boundaries instead — a space
  # is always a safe cut point, whatever the language of the title.
  function shorten(s, max,   n, w, i, out) {
    if (length(s) <= max) return s
    n = split(s, w, " ")
    out = w[1]
    for (i = 2; i <= n; i++) {
      if (length(out) + 1 + length(w[i]) > max) break
      out = out " " w[i]
    }
    # A single word longer than max is kept whole rather than cut mid-character;
    # the status bar clips it. Only a real elision earns the ellipsis.
    return (out == s) ? s : out "…"
  }

  FNR == 1 { next }
  NF < 9   { next }
  {
    st = trim($(NF - 4))
    if      (st == "TODO")        todo++
    else if (st == "IN PROGRESS") ip++
    else if (st == "DONE")        dn++
    else if (st == "BUG")         bug++
    else next   # SKIP, the header row and the separator row are all excluded

    # Story ids are unique per plan, not across plans, so a multi-plan project can
    # offer several matches for one branch. Prefer the one that is actually open.
    if (want != "" && trim($3) == want) {
      if (wid == "" || (ws != "IN PROGRESS" && ws != "BUG")) { wid = want; wt = title(); ws = st }
    }
    # On an epic branch only open stories can be the active one — a TODO story is
    # work not started, not work you are on. IN PROGRESS beats BUG; among equals the
    # lowest id wins, so the pick is stable across renders and across plans.
    else if (want_epic != "" && (st == "IN PROGRESS" || st == "BUG")) {
      id = trim($3)
      if (index(id, want_epic "-") == 1 \
          && (wid == "" || (ws == "BUG" && st == "IN PROGRESS") || (ws == st && id < wid))) {
        wid = id; wt = title(); ws = st
      }
    }
  }

  END {
    total = todo + ip + dn + bug
    if (total == 0) exit 0

    DIM  = "\033[2m";  RESET = "\033[0m"
    GRN  = "\033[32m"; YEL   = "\033[33m"
    RED  = "\033[31m"; CYN   = "\033[36m"

    out = DIM "ck-code" RESET " "

    if (wt != "") {
      if      (ws == "IN PROGRESS") { g = YEL "⚡" }
      else if (ws == "DONE")        { g = GRN "✓" }
      else if (ws == "BUG")         { g = RED "✗" }
      else                          { g = CYN "○" }
      out = out g " " wid RESET " " shorten(wt, 32) DIM " · " RESET
    }

    out = out GRN dn "/" total " ✓" RESET
    if (ip  > 0) out = out DIM " · " RESET YEL ip " ⚡" RESET
    if (bug > 0) out = out DIM " · " RESET RED bug " ✗" RESET

    print out
  }
' "$@" 2>/dev/null

exit 0
