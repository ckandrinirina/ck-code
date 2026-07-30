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

# Epic context: the epic whose roll-up is worth showing — the active story's own
# epic on a story branch, the branch's epic on an epic branch.
case "$story_id" in
  *-*) epic_ctx="${story_id%%-*}" ;;
  *)   epic_ctx="$epic_id" ;;
esac

# One awk pass over every plan's index: aggregate counts AND resolve the active
# story, its epic's roll-up, and the next ready story. Row shape is
# `| Epic | ID | Title | Status | Size | Blocked by | File |`, so with -F'|' a clean
# row has NF==9 ($1 and $9 are the empty ends).
#
# Fields are addressed from the RIGHT because a title may legitimately contain a
# `|` (ck-index.sh escapes it as `\|`, which awk still splits on, inflating NF).
# Status/Size/Blocked by/File can never contain one, so NF-4 is always Status.
#
# awk emits ONE tab-separated record rather than the finished line: the criteria
# count, the integration level and the worktree count are cheap shell probes that
# depend on what awk resolved (which story file, which epic), so composition
# happens below in bash. Rendering here would mean a second pass over the indexes.
record=$(awk -F'|' -v want="$story_id" -v want_epic="$epic_id" -v epic_ctx="$epic_ctx" '
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

  # Plan directory of the index being read — the File column is relative to it.
  function plandir(   d) { d = FILENAME; sub(/\/[^\/]*$/, "", d); return d }

  FNR == 1 { next }
  NF < 9   { next }
  {
    st = trim($(NF - 4))
    if      (st == "TODO")        todo++
    else if (st == "IN PROGRESS") ip++
    else if (st == "DONE")        dn++
    else if (st == "BUG")         bug++
    else next   # SKIP, the header row and the separator row are all excluded

    id = trim($3)

    # Epic roll-up for the epic in context, counted over the same rows.
    if (epic_ctx != "" && index(id, epic_ctx "-") == 1) {
      etotal++
      if (st == "DONE") edn++
    }

    # Next ready story: a TODO whose blockers are all DONE. Blockers can appear
    # after their dependents in the index, so this is resolved in END.
    if (st == "TODO") { ntodo++; tid[ntodo] = id; tblk[ntodo] = trim($(NF - 2)) }
    stat[id] = st

    # Story ids are unique per plan, not across plans, so a multi-plan project can
    # offer several matches for one branch. Prefer the one that is actually open.
    if (want != "" && id == want) {
      if (wid == "" || (ws != "IN PROGRESS" && ws != "BUG")) {
        wid = want; wt = title(); ws = st; wfile = trim($(NF - 1)); wdir = plandir()
      }
    }
    # On an epic branch only open stories can be the active one — a TODO story is
    # work not started, not work you are on. IN PROGRESS beats BUG; among equals the
    # lowest id wins, so the pick is stable across renders and across plans.
    else if (want_epic != "" && (st == "IN PROGRESS" || st == "BUG")) {
      if (index(id, want_epic "-") == 1 \
          && (wid == "" || (ws == "BUG" && st == "IN PROGRESS") || (ws == st && id < wid))) {
        wid = id; wt = title(); ws = st; wfile = trim($(NF - 1)); wdir = plandir()
      }
    }
  }

  END {
    total = todo + ip + dn + bug
    if (total == 0) exit 0

    # First TODO whose every blocker is DONE. "-" means unblocked; ids not present
    # in this project (a typo, or a blocker in another plan) are treated as blocking,
    # so the segment never advertises a story that build would refuse.
    for (i = 1; i <= ntodo && nid == ""; i++) {
      b = tblk[i]
      if (b == "" || b == "-") { nid = tid[i]; continue }
      n = split(b, deps, /,[ ]*/); ok = 1
      for (j = 1; j <= n; j++) if (stat[trim(deps[j])] != "DONE") { ok = 0; break }
      if (ok) nid = tid[i]
    }

    # US (0x1f) separates the fields, not a tab: tab is an IFS *whitespace*
    # character, so bash `read` would collapse the empty fields a branch with no
    # active story legitimately produces, shifting every field after it.
    US = sprintf("%c", 31)
    print wid US ws US shorten(wt, 32) US wfile US wdir US \
          dn US total US ip+0 US bug+0 US edn+0 US etotal+0 US nid
  }
' "$@" 2>/dev/null)

[ -n "$record" ] || exit 0

US=$(printf '\037')
IFS="$US" read -r wid ws wt wfile wdir dn total ip bug edn etotal nid <<EOF
$record
EOF

# --- cheap probes, each gated on what awk resolved -----------------------------

# Unchecked acceptance criteria of the active story — the "am I done" signal that
# otherwise only the model knows. One file, one grep, only when a story is active.
crit=0
if [ -n "$wfile" ] && [ -f "$wdir/$wfile" ]; then
  crit=$(awk '/^[[:space:]]*-[[:space:]]*\[ \]/ { n++ } END { print n+0 }' \
    "$wdir/$wfile" 2>/dev/null)
  [ -n "$crit" ] || crit=0
fi

# Integration level of the epic in context (branch-topology.md). Only `epic` and
# `feature` are shown — `story` (the default, and an absent key) merges straight to
# the default branch, which is what everyone already assumes.
integ=""
if [ -n "$epic_ctx" ]; then
  # Prefer the plan the active story came from, then any plan's epic of that number.
  # `$@` still holds the index list the wave aggregation below needs, so this glob
  # must never go through `set --`.
  for e in "$wdir"/epics/"$epic_ctx"_*/EPIC.md tasks/*/epics/"$epic_ctx"_*/EPIC.md; do
    [ -f "$e" ] || continue
    integ=$(awk '/^integration:[[:space:]]*(epic|feature)[[:space:]]*$/ {
      sub(/^integration:[[:space:]]*/, ""); gsub(/[[:space:]]/, ""); print; exit }' "$e" 2>/dev/null)
    [ -n "$integ" ] && break
  done
fi

# Live fan-out: worktrees beyond the main one are PARALLEL MODE implementers, which
# are otherwise invisible from an idle main session. Count only — per-agent detail
# belongs in the subagent rows, which already have each worktree's path.
wave_pct=""
wt_count=0
wt_list=$(git worktree list --porcelain 2>/dev/null)
if [ -n "$wt_list" ]; then
  wt_count=$(printf '%s\n' "$wt_list" | awk '/^worktree /{n++} END{print n+0}')
  wt_count=$((wt_count - 1))
  [ "$wt_count" -lt 0 ] && wt_count=0
fi

# Wave progress: aggregate acceptance criteria across the stories currently held by
# worktrees. Criteria are the only progress signal with a *denominator* — a diff stat
# or a token count has no "out of how much" — so a percentage can only ever mean
# "boxes ticked", which the implementing agent ticks as it goes.
#
# Read from each WORKTREE's own copy of the story file, never the main checkout's:
# the agent ticks boxes in its worktree, so the main copy shows 0% until the merge.
if [ "$wt_count" -gt 0 ]; then
  # The first porcelain record is the main worktree. Skipping it keeps the percentage
  # counting exactly the stories the `N wt` count reports — on a story branch the
  # session's own story would otherwise be folded in, and the two would disagree.
  wave_ids=$(printf '%s\n' "$wt_list" | awk '
    /^worktree /  { n++; path = substr($0, 10) }
    /^branch /    { b = substr($0, 8); sub(/^refs\/heads\//, "", b)
                    if (n > 1 && b ~ /^(story|fix)\//) {
                      sub(/^[^\/]*\//, "", b)
                      n = split(b, p, "-")
                      if (p[1] ~ /^[0-9]+$/ && p[2] ~ /^[0-9]+$/) print p[1] "-" p[2] "\t" path
                    } }')
  if [ -n "$wave_ids" ]; then
    # id → path-relative-to-plan, from the indexes the main checkout already has.
    # awk builds the id list too — the script's only hard dependencies stay awk + git.
    ids=$(printf '%s\n' "$wave_ids" | awk -F'\t' '$1 != "" { printf "%s,", $1 }')
    map=$(awk -F'|' -v ids="$ids" '
      function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR == 1 || NF < 9 { next }
      { id = trim($3)
        if (index("," ids, "," id ",")) {
          d = FILENAME; sub(/\/[^\/]*$/, "", d)
          print id "\t" d "/" trim($(NF - 1))
        } }' "$@" 2>/dev/null)
    # One path per line, so a directory containing a space stays one filename.
    files=""
    while IFS='	' read -r id path; do
      [ -n "$id" ] || continue
      rel=$(printf '%s\n' "$map" | awk -F'\t' -v i="$id" '$1 == i { print $2; exit }')
      [ -n "$rel" ] || continue
      if   [ -f "$path/$rel" ]; then files="$files$path/$rel
"
      elif [ -f "$rel" ];       then files="$files$rel
"
      fi
    done <<EOF
$wave_ids
EOF
    if [ -n "$files" ]; then
      # Each input line IS a filename; awk reads it with getline, so no word
      # splitting and no temp file.
      wave_pct=$(printf '%s' "$files" | awk '
        NF {
          while ((getline line < $0) > 0) {
            if      (line ~ /^[[:space:]]*-[[:space:]]*\[[xX]\]/) d++
            else if (line ~ /^[[:space:]]*-[[:space:]]*\[ \]/)    o++
          }
          close($0)
        }
        END { t = d + o; if (t > 0) printf "%d", (d * 100) / t }' 2>/dev/null)
    fi
  fi
fi

# --- compose ------------------------------------------------------------------

# Literal escapes, so the line is printed with %s — a title is data and must never
# be walked by printf's %b escape interpretation.
ESC=$(printf '\033')
DIM="${ESC}[2m"; RESET="${ESC}[0m"
GRN="${ESC}[32m"; YEL="${ESC}[33m"; RED="${ESC}[31m"; CYN="${ESC}[36m"
SEP="${DIM} · ${RESET}"

out="${DIM}ck-code${RESET} "

if [ -n "$wt" ]; then
  case "$ws" in
    "IN PROGRESS") g="${YEL}⚡" ;;
    DONE)          g="${GRN}✓" ;;
    BUG)           g="${RED}✗" ;;
    *)             g="${CYN}○" ;;
  esac
  out="${out}${g} ${wid}${RESET} ${wt}${SEP}"
elif [ -n "$nid" ]; then
  # No story in play: the next ready one is the only story worth naming.
  out="${out}${DIM}next${RESET} ${CYN}${nid}${RESET}${SEP}"
fi

[ "${etotal:-0}" -gt 0 ] && out="${out}${DIM}epic ${epic_ctx}${RESET} ${edn}/${etotal}${SEP}"
[ "${crit:-0}" -gt 0 ]   && out="${out}${YEL}${crit} ☐${RESET}${SEP}"
if [ -n "$integ" ]; then
  if [ -n "$epic_id" ]; then
    # Already sitting on the epic branch: naming it as the target is noise. Only the
    # level above it — where the epic PR will go — is news worth a segment.
    [ "$integ" = feature ] && out="${out}${CYN}→ feat${RESET}${SEP}"
  else
    out="${out}${CYN}→ epic/${epic_ctx}${RESET}"
    [ "$integ" = feature ] && out="${out}${DIM} → feat${RESET}"
    out="${out}${SEP}"
  fi
fi

# The percentage earns its place on the plan total, where the denominator is large
# enough that a ratio no longer reads at a glance; `0/3` on an epic already does.
out="${out}${GRN}${dn}/${total} ✓${RESET}${DIM} $((dn * 100 / total))%${RESET}"
[ "${ip:-0}"  -gt 0 ] && out="${out}${SEP}${YEL}${ip} ⚡${RESET}"
[ "${bug:-0}" -gt 0 ] && out="${out}${SEP}${RED}${bug} ✗${RESET}"
if [ "$wt_count" -gt 0 ]; then
  out="${out}${SEP}${DIM}⚙${RESET} ${wt_count} wt"
  [ -n "$wave_pct" ] && out="${out} ${YEL}${wave_pct}%${RESET}"
fi

printf '%s\n' "$out"

exit 0
