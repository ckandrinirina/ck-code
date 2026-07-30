#!/usr/bin/env bash
# ck-code statusLine: renders a compact view of ck-code project state in the
# Claude Code status bar — the active story (derived from the git branch) plus
# the counts of the plan that branch belongs to.
#
# The branch picks the plan, never the directory alone: story ids and epic numbers
# are unique per plan, not across plans, so a `tasks/` holding several features (or a
# multi-repo project whose code repo carries a stale `tasks/` of its own) can offer
# several answers for one branch. A plan is used only when the branch confirms it, and
# a branch no visible plan owns renders nothing at all.
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

# Two roots, deliberately kept apart. Every git probe runs HERE, in the session's own
# checkout: that is the repo whose branch names the work and whose worktrees hold the
# fan-out. The plan is resolved separately below, because a multi-repo project keeps
# `tasks/` in a parent repo while the code is checked out underneath it.
repo_dir=$PWD

# Active story: derived from the branch name, never stored (branch-topology.md).
# story/<EE>-<SS>-<slug> and fix/<EE>-<SS>-<slug> both carry the id outright.
# epic/<NN>-<slug> carries only the epic, so the story is resolved from the index:
# an epic branch is where an `integration: epic|feature` session sits while its
# stories are built, and it names no story of its own.
#
# The trailing slug is kept too: with several plans in play the id alone is ambiguous
# (every feature has an epic 02), and the slug is the only part of the branch name that
# says WHICH one.
story_id=""
epic_id=""
bslug=""
# `branch --show-current` (git >= 2.22) is empty on a detached HEAD and, unlike
# `rev-parse --abbrev-ref HEAD`, does not error on an unborn branch.
branch=$(git branch --show-current 2>/dev/null)
[ -n "$branch" ] || branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
btail=${branch#*/}
case "$branch" in
  story/*|fix/*)
    story_id=$(printf '%s' "$btail" | awk -F- \
      '$1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ { print $1 "-" $2 }')
    [ -n "$story_id" ] && bslug=${btail#"$story_id"-}
    ;;
  epic/*)
    epic_id=$(printf '%s' "$btail" | awk -F- '$1 ~ /^[0-9]+$/ { print $1 }')
    [ -n "$epic_id" ] && bslug=${btail#"$epic_id"-}
    ;;
esac
# An id with no slug after it leaves the tail untouched by the strip above.
[ "$bslug" = "$btail" ] && bslug=""

# Plan roots: every ancestor holding a generated index, nearest first. A `tasks/` beside
# the code is a CANDIDATE, not an answer — in a multi-repo project it is routinely an
# abandoned plan from before the split, while the plan being built sits one level up.
# Bounded to 8 levels and stopped at $HOME, so a render never walks the whole filesystem.
roots=""
d=$repo_dir
depth=0
while [ "$depth" -lt 8 ]; do
  set -- "$d"/tasks/*/STORIES_INDEX.md
  [ -f "$1" ] && roots="$roots$d
"
  [ "$d" = "/" ] && break
  [ "$d" = "$HOME" ] && break
  d=${d%/*}
  [ -n "$d" ] || d="/"
  depth=$((depth + 1))
done

# No generated index anywhere → the project is planned but not indexed (or is not a
# ck-code project at all); say nothing rather than render an empty scoreboard.
[ -n "$roots" ] || exit 0

# Does plan $1 own the current branch? 2 = the slug confirms it, 1 = the number or id
# matches but nothing corroborates it, 0 = no.
plan_score() {
  p=$1
  if [ -n "$epic_id" ]; then
    hit=0
    for e in "$p"/epics/"$epic_id"_*; do
      [ -d "$e" ] || continue
      hit=1
      [ -n "$bslug" ] || continue
      s=${e##*/}; s=${s#*_}
      [ "$s" = "$bslug" ] && { echo 2; return; }
      # An epic renamed after its branch was cut still answers to its `slug:` field.
      fs=$(awk '/^slug:[[:space:]]*[^[:space:]]/ {
        sub(/^slug:[[:space:]]*/, ""); gsub(/[[:space:]]/, ""); print; exit }' \
        "$e/EPIC.md" 2>/dev/null)
      [ -n "$fs" ] && [ "$fs" = "$bslug" ] && { echo 2; return; }
    done
    [ "$hit" -eq 1 ] || { echo 0; return; }
    [ -n "$bslug" ] || { echo 1; return; }
    # Number matches, slug does not. Accept only if the epic still has open work: a
    # finished epic NN in an unrelated or abandoned plan is the false positive this
    # whole resolution exists to reject, while an epic you are actually building
    # always has a story that is not DONE.
    open=$(awk -F'|' -v e="$epic_id" '
      function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR == 1 || NF < 9 { next }
      { id = trim($3); st = trim($(NF - 4))
        if (index(id, e "-") == 1 && st != "DONE" && st != "SKIP") n++ }
      END { print n+0 }' "$p/STORIES_INDEX.md" 2>/dev/null)
    [ "${open:-0}" -gt 0 ] && { echo 1; return; }
    echo 0
    return
  fi

  # Story branch: the id must be in the index, and the branch slug is corroboration —
  # any word of it (4+ chars, so `the` and `api` cannot carry a match on their own)
  # appearing in the row's title or file path.
  awk -F'|' -v want="$story_id" -v bslug="$bslug" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    FNR == 1 || NF < 9 { next }
    trim($3) == want {
      s = 1
      if (bslug != "") {
        hay = tolower($0); n = split(bslug, w, "-")
        for (i = 1; i <= n; i++)
          if (length(w[i]) >= 4 && index(hay, w[i]) > 0) { s = 2; break }
      }
      exit
    }
    END { print s+0 }' "$p/STORIES_INDEX.md" 2>/dev/null
}

# Pick the plan the branch confirms: a slug-confirmed match anywhere beats an
# id-only match nearer by, and among equals the nearest root wins.
plan=""
plan_root=""
best=0
if [ -n "$story_id" ] || [ -n "$epic_id" ]; then
  while IFS= read -r root; do
    [ -n "$root" ] || continue
    for p in "$root"/tasks/*/; do
      p=${p%/}
      [ -f "$p/STORIES_INDEX.md" ] || continue
      s=$(plan_score "$p")
      if [ "${s:-0}" -gt "$best" ]; then
        best=$s; plan=$p; plan_root=$root
        [ "$best" -eq 2 ] && break
      fi
    done
    [ "$best" -eq 2 ] && break
  done <<EOF
$roots
EOF
  # The branch names ck-code work that no visible plan owns. Say nothing rather than
  # answer with another feature's scoreboard — the plan is simply not in this checkout,
  # and a confident wrong number is worse than an empty status bar.
  [ "$best" -gt 0 ] || exit 0
fi

if [ -n "$plan" ]; then
  # Counts are the FEATURE's, not the project's: with the plan known, folding in every
  # other feature ever planned would answer a question nobody asked.
  set -- "$plan/STORIES_INDEX.md"
else
  # No ck-code branch to go on (`main`, a detached HEAD): nothing identifies one plan,
  # so the counts stay project-wide and no epic segment is drawn.
  plan_root=$(printf '%s\n' "$roots" | awk 'NF { print; exit }')
  set -- "$plan_root"/tasks/*/STORIES_INDEX.md
  [ -f "$1" ] || exit 0
fi

# Epic context: the epic whose roll-up is worth showing — the active story's own
# epic on a story branch, the branch's epic on an epic branch.
case "$story_id" in
  *-*) epic_ctx="${story_id%%-*}" ;;
  *)   epic_ctx="$epic_id" ;;
esac

# Names, not just numbers. `epic 02` is only meaningful once you know WHICH feature's
# epic 02 it is — the exact question a plan holding several features raises, and one no
# branch name answers on a story branch. Both are folder names, so they cost no file read.
#
# Shown only when a plan was resolved: without one the numbers are project-wide and
# there is no single feature to name.
feat_name=""
epic_name=""
if [ -n "$plan" ]; then
  feat_name=${plan##*/}
  # Strip the date stamp and the `feature-` prefix every plan folder carries: filing
  # metadata, identical on every row, and never what distinguishes one feature.
  case "$feat_name" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_*) feat_name=${feat_name#*_} ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*) feat_name=${feat_name#????-??-??-} ;;
  esac
  case "$feat_name" in
    feature-*) feat_name=${feat_name#feature-} ;;
    feat-*)    feat_name=${feat_name#feat-} ;;
  esac

  if [ -n "$epic_ctx" ]; then
    for e in "$plan"/epics/"$epic_ctx"_*; do
      [ -d "$e" ] || continue
      epic_name=${e##*/}; epic_name=${epic_name#*_}
      break
    done
  fi
fi

# Both are slugs, so a hyphen is the safe cut point — the same word-boundary rule the
# title shortening uses, and for the same reason: never cut mid-character.
shorten_slug() {
  [ ${#1} -le "$2" ] && { printf '%s' "$1"; return; }
  printf '%s' "$1" | awk -v max="$2" '{
    n = split($0, w, "-"); o = w[1]
    for (i = 2; i <= n; i++) { if (length(o) + 1 + length(w[i]) > max) break; o = o "-" w[i] }
    printf "%s", (o == $0) ? o : o "…" }'
}
[ -n "$feat_name" ] && feat_name=$(shorten_slug "$feat_name" 18)
[ -n "$epic_name" ] && epic_name=$(shorten_slug "$epic_name" 16)

# The story title yields the width the names take: it is the one field with no fixed
# meaning per character, so it is where a column of width buys the least.
tmax=32
[ -n "$feat_name" ] && tmax=22

# One awk pass over every plan's index: aggregate counts AND resolve the active
# story plus its epic's roll-up. Row shape is
# `| Epic | ID | Title | Status | Size | Blocked by | File |`, so with -F'|' a clean
# row has NF==9 ($1 and $9 are the empty ends). The `Blocked by` column is no longer
# read — it only ever fed the `next` suggestion the line has dropped.
#
# Fields are addressed from the RIGHT because a title may legitimately contain a
# `|` (ck-index.sh escapes it as `\|`, which awk still splits on, inflating NF).
# Status/Size/Blocked by/File can never contain one, so NF-4 is always Status.
#
# awk emits ONE tab-separated record rather than the finished line: the criteria
# count, the integration level and the worktree count are cheap shell probes that
# depend on what awk resolved (which story file, which epic), so composition
# happens below in bash. Rendering here would mean a second pass over the indexes.
record=$(awk -F'|' -v want="$story_id" -v want_epic="$epic_id" -v epic_ctx="$epic_ctx" \
             -v tmax="$tmax" '
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

    # Per-epic tallies, so the feature can be reported in EPICS rather than in stories.
    # A story count spanning a whole feature answers "how much work is left" with a
    # number too coarse to act on; an epic is the unit a feature is actually planned,
    # branched, reviewed and shipped in, so `1/5` says where the feature stands.
    ep = id; sub(/-.*$/, "", ep)
    if (ep != "") {
      if (!(ep in eptot)) epn++
      eptot[ep]++
      if (st == "DONE") epdn[ep]++
    }

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

    # An epic is done when every story it has is done — the same rule `ship` applies
    # when it closes one. An epic with no indexed story cannot be complete, and is not
    # counted at all: it would otherwise start life already finished.
    for (e in eptot) if (epdn[e] == eptot[e]) epdone++

    # US (0x1f) separates the fields, not a tab: tab is an IFS *whitespace*
    # character, so bash `read` would collapse the empty fields a branch with no
    # active story legitimately produces, shifting every field after it.
    US = sprintf("%c", 31)
    # `dn+0`, not `dn`: a feature whose stories are all still open never incremented it,
    # and an uninitialised awk variable prints as the empty string — which reads as the
    # broken `/12 ✓` rather than `0/12 ✓`. Feature-scoped counts hit this constantly;
    # project-wide ones almost never did.
    print wid US ws US shorten(wt, tmax + 0) US wfile US wdir US \
          dn+0 US total US ip+0 US bug+0 US edn+0 US etotal+0 US \
          epdone+0 US epn+0
  }
' "$@" 2>/dev/null)

[ -n "$record" ] || exit 0

US=$(printf '\037')
IFS="$US" read -r wid ws wt wfile wdir dn total ip bug edn etotal epdone epn <<EOF
$record
EOF

# --- cheap probes, each gated on what awk resolved -----------------------------

# Acceptance criteria of the active story — the unit the story level reports in, and the
# "am I done" signal that otherwise only the model knows. Ticked / total, like every level
# above it, so `10/11` reads as nearly done where a bare `1 ☐` had to be interpreted.
#
# The ratio only, never a percentage. Percentages are the FEATURE's and the EPIC's, where
# they summarise many rows and the reader has no denominator of their own; over 8 criteria
# `5/8` is already the finer statement, and the percentage was a second rendering of the
# two numbers beside it.
crit=""
if [ -n "$wfile" ] && [ -f "$wdir/$wfile" ]; then
  crit=$(awk '
    /^[[:space:]]*-[[:space:]]*\[[xX]\]/ { d++ }
    /^[[:space:]]*-[[:space:]]*\[ \]/    { o++ }
    END { t = d + o; if (t > 0) printf "%d/%d", d+0, t }' \
    "$wdir/$wfile" 2>/dev/null)
fi

# Integration level of the epic in context (branch-topology.md). Only `epic` and
# `feature` are shown — `story` (the default, and an absent key) merges straight to
# the default branch, which is what everyone already assumes.
integ=""
if [ -n "$epic_ctx" ] && [ -n "$plan" ]; then
  # Read from the resolved plan only — an epic number means nothing outside it.
  for e in "$plan"/epics/"$epic_ctx"_*/EPIC.md; do
    [ -f "$e" ] || continue
    integ=$(awk '/^integration:[[:space:]]*(epic|feature)[[:space:]]*$/ {
      sub(/^integration:[[:space:]]*/, ""); gsub(/[[:space:]]/, ""); print; exit }' "$e" 2>/dev/null)
    [ -n "$integ" ] && break
  done
fi

# Live fan-out: worktrees beyond the main one are PARALLEL MODE implementers, which are
# otherwise invisible from an idle main session. Each is named by the STORY it holds, not
# just counted: `2 wt` says work is happening somewhere, `02-03, 02-06` says which stories
# are moving — the half of the answer a count cannot give.
#
# Named only, no percentage. A worktree's progress figure had to come from acceptance-criteria
# checkboxes, the only signal with a denominator, and those are ticked at the END of a story
# rather than as the work happens — so it read 0% for almost the whole life of the story it
# was meant to track. The id is the part that was ever reliable.
#
# "Elsewhere" is the point, so the session's OWN checkout is excluded — its story is
# already the story segment, and repeating it here would be the one thing this layout
# exists to avoid. Excluding it by path rather than by position matters from inside a
# fan-out worktree, where the session is not the first record.
#
# Only worktrees on a `story/` or `fix/` branch count: those are implementers. A checkout
# parked on an epic or feature branch is somewhere you work, not something running, and
# counting it would report a fan-out that is not happening.
wt_ids=""
wt_extra=0
wt_count=0
self=$(git rev-parse --show-toplevel 2>/dev/null)
wt_list=$(git worktree list --porcelain 2>/dev/null)

if [ -n "$wt_list" ]; then
  # `count TAB unnamed TAB ids`: a branch carrying no parseable id is still counted, so `⚙`
  # never under-reports the checkouts that exist, and `-` stands in for it while sorting
  # (it precedes every digit, so the unnamed ones can never split the id list).
  wave=$(printf '%s\n' "$wt_list" | awk -v self="$self" '
    /^worktree /  { path = substr($0, 10) }
    /^branch /    { b = substr($0, 8); sub(/^refs\/heads\//, "", b)
                    if (path != self && b ~ /^(story|fix)\//) {
                      sub(/^[^\/]*\//, "", b)
                      parts = split(b, p, "-")
                      rec[++k] = (parts >= 2 && p[1] ~ /^[0-9]+$/ && p[2] ~ /^[0-9]+$/) \
                                 ? p[1] "-" p[2] : "-"
                    } }
    # Sorted by id, not by the order git happens to list the worktrees in: ids are
    # zero-padded, so a string sort is the numeric one, and a wave reads as `01-02,
    # 02-01, 02-03` — grouped by epic, the way the plan is written. Insertion sort
    # because the list is a handful of items and `sort` would be a third dependency.
    END { for (i = 2; i <= k; i++) {
            v = rec[i]
            for (j = i - 1; j >= 1 && rec[j] > v; j--) rec[j + 1] = rec[j]
            rec[j + 1] = v
          }
          for (i = 1; i <= k; i++) {
            if (rec[i] == "-") { unnamed++; continue }
            ids = ids (ids == "" ? "" : " ") rec[i]
          }
          print k+0 "\t" unnamed+0 "\t" ids }')
  IFS='	' read -r wt_count wt_extra wt_ids <<EOF
$wave
EOF
fi

# --- compose ------------------------------------------------------------------

# Literal escapes, so the line is printed with %s — a title is data and must never
# be walked by printf's %b escape interpretation.
ESC=$(printf '\033')
DIM="${ESC}[2m"; RESET="${ESC}[0m"
GRN="${ESC}[32m"; YEL="${ESC}[33m"; RED="${ESC}[31m"; CYN="${ESC}[36m"
SEP="${DIM} · ${RESET}"

# One colour per ROLE, identical at every level, so the eye learns the line once instead
# of once per segment:
#
#   dim    structure — the `ck-code` mark, the `epic`/`⚙` labels, separators
#   cyan   identity  — what a thing is called: feature, epic, story id, story title
#   green  progress  — a done/total ratio, wherever it appears
#   dim    percentage — always, so it reads as the ratio's echo and never competes with it
#   yellow / red  status only — `⚡` open, `✗` bug, and the story glyph
#
# Percentages appear at the FEATURE and EPIC levels only — the two whose ratios summarise
# many rows. Below them the ratio's own numbers are small enough to read directly.
#
# Colour therefore says what KIND of value you are looking at, never which level it came
# from; the level is already carried by position. Only status keeps a colour of its own,
# because that is the one thing on the line worth interrupting a scan for.

# The line reads top-down, one level of the plan per segment, each counted in the unit
# below it and each narrower than the last:
#
#   ck-code <feature> <epics> · epic <NN> <name> <stories> · <story> <criteria> · ⚙ <live>
#
# Nothing jumps levels and nothing repeats what a wider segment already said, so scanning
# left to right answers "which feature, which epic, which story, how far" in that order —
# the order the questions are actually asked in.
out="${DIM}ck-code${RESET} "

# A level's numbers: green ratio, dim percentage. The `✓` the feature ratio used to carry
# is gone — with every level reading done/total it marked nothing the others lacked.
ratio() { printf '%s' "${GRN}$1/$2${RESET}${DIM} $(($1 * 100 / $2))%${RESET}"; }

# 1. FEATURE, counted in epics. Everything after it is scoped to this one plan.
if [ -n "$feat_name" ]; then
  out="${out}${CYN}${feat_name}${RESET}"
  # The percentage is the feature's STORY progress, deliberately finer than the epic
  # ratio it follows — it moves inside an epic, where `1/5` cannot.
  [ "${epn:-0}" -gt 0 ] && out="${out} ${GRN}${epdone}/${epn}${RESET}${DIM} $((dn * 100 / total))%${RESET}"
  # The feature's own health, kept at the level it describes: somewhere in this plan N
  # stories are open and N are bugs. Attached, not separated, so it cannot be read as
  # belonging to the epic or the story segment further right.
  [ "${ip:-0}"  -gt 0 ] && out="${out} ${YEL}${ip}⚡${RESET}"
  [ "${bug:-0}" -gt 0 ] && out="${out} ${RED}${bug}✗${RESET}"
  out="${out}${SEP}"
else
  # No feature resolved (`main`, a detached HEAD): there is no one plan to report in
  # epics, so project-wide story counts are all there is to say.
  out="${out}$(ratio "$dn" "$total")"
  [ "${ip:-0}"  -gt 0 ] && out="${out} ${YEL}${ip}⚡${RESET}"
  [ "${bug:-0}" -gt 0 ] && out="${out} ${RED}${bug}✗${RESET}"
  out="${out}${SEP}"
fi

# 2. EPIC, counted in stories.
if [ "${etotal:-0}" -gt 0 ]; then
  out="${out}${DIM}epic${RESET} ${CYN}${epic_ctx}"
  [ -n "$epic_name" ] && out="${out} ${epic_name}"
  out="${out}${RESET} $(ratio "$edn" "$etotal")${SEP}"
fi

# 3. STORY, counted in acceptance criteria. It sits BELOW its epic: a story is read as
# "which one, inside that epic", and the reverse order asked you to hold the story in mind
# until the epic arrived to give it a context.
#
# With no story in play the segment is simply absent. It used to suggest the next ready one
# instead — a recommendation, not state, and this line reports where you ARE; `track next`
# is the command that answers what to pick up, and it can weigh a choice a status bar cannot.
if [ -n "$wt" ]; then
  case "$ws" in
    "IN PROGRESS") g="${YEL}⚡" ;;
    DONE)          g="${GRN}✓" ;;
    BUG)           g="${RED}✗" ;;
    *)             g="${CYN}○" ;;
  esac
  # Glyph carries the status colour; the id and title are identity, so they are cyan like
  # every other name on the line.
  out="${out}${g}${RESET} ${CYN}${wid} ${wt}${RESET}"
  [ -n "$crit" ] && out="${out} ${GRN}${crit}${RESET}"
  out="${out}${SEP}"
fi

# 4. Where the finished story lands, when it is not the default branch.
if [ -n "$integ" ]; then
  if [ -n "$epic_id" ]; then
    # Already sitting on the epic branch: naming it as the target is noise. Only the
    # level above it — where the epic PR will go — is news worth a segment.
    [ "$integ" = feature ] && out="${out}${DIM}→${RESET} ${CYN}feat${RESET}${SEP}"
  else
    out="${out}${DIM}→${RESET} ${CYN}epic/${epic_ctx}${RESET}"
    [ "$integ" = feature ] && out="${out}${DIM} → ${RESET}${CYN}feat${RESET}"
    out="${out}${SEP}"
  fi
fi

# 5. Live work: every story a worktree is building right now. Named rather than counted —
# `2 wt` cannot tell you WHICH stories are moving.
if [ "${wt_count:-0}" -gt 0 ]; then
  out="${out}${DIM}⚙${RESET}"
  first=1
  for id in $wt_ids; do
    [ "$first" -eq 1 ] && first=0 || out="${out}${DIM},${RESET}"
    out="${out} ${CYN}${id}${RESET}"
  done
  # Worktrees whose branch names no story, so `⚙` never under-reports what is checked out.
  if [ "${wt_extra:-0}" -gt 0 ]; then
    [ "$first" -eq 1 ] && out="${out}${DIM} ${wt_extra} wt${RESET}" \
                       || out="${out}${DIM} +${wt_extra}${RESET}"
  fi
  out="${out}${SEP}"
fi

# Trim the trailing separator: every segment above appends its own, so whichever ends up
# last would otherwise leave the line hanging on a `·`.
case "$out" in *"$SEP") out="${out%"$SEP"}" ;; esac

printf '%s\n' "$out"

exit 0
