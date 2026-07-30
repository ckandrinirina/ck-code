#!/usr/bin/env bash
# ck-code subagentStatusLine: renders one compact row body per visible subagent
# in the agent panel (used by /ck-code:build PARALLEL MODE worktree implementers).
#
# Input: a single JSON object on stdin with a `.tasks` array; each task has
# id, name, type, status, description, label, startTime, tokenCount, cwd.
# Output: one formatted line per task, in order:
#
#   ⚡ story-02-01 · Implement 02-01 filter service · 5/8 63% · +214/-18 · 159.5k tok
#
# The two middle fields are what a token count cannot tell you: how far the agent's
# story has got (acceptance criteria ticked, read from that agent's OWN worktree) and
# whether it has written any code at all — the check `build` P5 later re-derives with
# git. An agent that reports success having changed nothing is the failure this row
# makes visible while it is still happening.
#
# Costs zero model tokens: the panel is drawn by the terminal, not by the model.
#
# Safe by design: if `jq` is unavailable it prints nothing and exits 0, so
# Claude Code falls back to its default `name · description · tokens` row. Every
# probe is optional — a row degrades field by field, and never disappears.

command -v jq >/dev/null 2>&1 || exit 0

# US (0x1f) joins the fields: unlike a tab it is not IFS whitespace, so an empty
# description or token count cannot collapse and shift the fields after it.
US=$(printf '\037')

# The story id and the token formatting are done here rather than per row in the
# shell: jq is already parsing every task, and each field pulled into this one pass
# is one fewer process spawned per row (rows re-render while a fan-out runs).
rows=$(jq -r --arg us "$US" '
  def glyph(s):
    if   s=="running" or s=="in_progress" then "⚡"
    elif s=="completed" or s=="done"      then "✓"
    elif s=="failed" or s=="error"        then "✗"
    elif s=="queued" or s=="pending"      then "…"
    else "•" end;
  def ktok(n):
    if   n == null then ""
    elif n >= 1000 then "\((n / 100 | floor) / 10)k tok"
    else                "\(n) tok" end;
  # `story-EE-SS` from the dispatch label, with the description as fallback since it
  # carries the id too — a row must not lose its progress field to a rename.
  def sid: [ ((.label // "") + " " + (.description // "")) | scan("[0-9]+-[0-9]+") ]
           | first // "";
  .tasks[]? |
    [ glyph(.status),
      (.label // .name // .type // "task"),
      (.description // ""),
      ktok(.tokenCount),
      sid,
      (.cwd // "") ] | join($us)
' 2>/dev/null) || exit 0

[ -n "$rows" ] || exit 0

# The branch the fan-out was cut from, resolved once for every row: the worktrees
# share one repository, and the main worktree is the one sitting on $TARGET.
target=""
first_cwd=$(printf '%s\n' "$rows" | awk -F"$US" 'NF >= 6 && $6 != "" { print $6; exit }')
if [ -n "$first_cwd" ] && [ -d "$first_cwd" ]; then
  common=$(git -C "$first_cwd" rev-parse --git-common-dir 2>/dev/null)
  # `${var%/*}` rather than dirname: the row probes must need nothing but awk and git.
  main_dir=""
  case "$common" in
    /*) main_dir="${common%/*}" ;;
    ?*) main_dir=$(cd "$first_cwd" 2>/dev/null && cd "${common%/*}" 2>/dev/null && pwd -P) ;;
  esac
  [ -n "$main_dir" ] && target=$(git -C "$main_dir" branch --show-current 2>/dev/null)
fi

while IFS="$US" read -r glyph label desc tok id cwd; do
  [ -n "$glyph" ] || continue

  # Criteria progress: id → story file through the worktree's OWN index, counted in
  # the worktree's OWN copy — the agent ticks boxes there, so the main checkout reads
  # 0% until the merge lands. One awk does both: the index rows come from ARGV, the
  # story file is pulled in with getline, so a row costs one process here, not two.
  crit=""
  if [ -n "$id" ] && [ -n "$cwd" ] && [ -d "$cwd" ]; then
    # Candidate indexes, nearest first: the worktree's own plan, then every ancestor
    # holding one. A multi-repo project keeps `tasks/` above the code repo, so the
    # worktree may hold no plan at all — or a stale one whose ids collide.
    set --
    d=$cwd
    depth=0
    while [ "$depth" -lt 8 ]; do
      for f in "$d"/tasks/*/STORIES_INDEX.md; do
        [ -f "$f" ] && set -- "$@" "$f"
      done
      [ "$d" = "/" ] && break
      [ "$d" = "$HOME" ] && break
      d=${d%/*}; [ -n "$d" ] || d="/"
      depth=$((depth + 1))
    done
    # `02-01` names a story in EVERY feature; the agent's own branch slug is the only
    # thing that says which one, so it decides between plans that both claim the id.
    bslug=$(git -C "$cwd" branch --show-current 2>/dev/null | awk -F/ '
      NF > 1 { s = $NF; sub(/^[0-9]+-[0-9]+-/, "", s); print s }')
    [ "$#" -gt 0 ] && crit=$(awk -F'|' -v want="$id" -v bslug="$bslug" '
      function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR == 1 || NF < 9 { next }
      trim($3) == want {
        s = 1
        if (bslug != "") {
          hay = tolower($0); n = split(bslug, w, "-")
          for (i = 1; i <= n; i++)
            if (length(w[i]) >= 4 && index(hay, w[i]) > 0) { s = 2; break }
        }
        if (s > best) {
          best = s
          d = FILENAME; sub(/\/[^\/]*$/, "", d); f = d "/" trim($(NF - 1))
        }
        if (best == 2) exit          # slug-confirmed; no nearer plan can beat it
      }
      END {
        if (f == "") exit
        while ((getline line < f) > 0) {
          if      (line ~ /^[[:space:]]*-[[:space:]]*\[[xX]\]/) done_++
          else if (line ~ /^[[:space:]]*-[[:space:]]*\[ \]/)    open_++
        }
        close(f)
        t = done_ + open_
        if (t > 0) printf "%d/%d %d%%", done_, t, (done_ * 100) / t
      }' "$@" 2>/dev/null)
  fi

  # Diff against $TARGET, so committed and uncommitted work both count. No diff means
  # no implementation yet, however many tokens have been spent.
  dstat=""
  if [ -n "$target" ] && [ -n "$cwd" ] && [ -d "$cwd" ]; then
    dstat=$(git -C "$cwd" diff --shortstat "$target" 2>/dev/null | awk '
      { i = 0; d = 0
        if (match($0, /[0-9]+ insertion/)) i = substr($0, RSTART, RLENGTH) + 0
        if (match($0, /[0-9]+ deletion/))  d = substr($0, RSTART, RLENGTH) + 0
        if (i || d) printf "+%d/-%d", i, d }')
  fi

  line="$glyph $label"
  [ -n "$desc" ]  && line="$line · $desc"
  [ -n "$crit" ]  && line="$line · $crit"
  [ -n "$dstat" ] && line="$line · $dstat"
  [ -n "$tok" ]   && line="$line · $tok"
  printf '%s\n' "$line"
done <<EOF
$rows
EOF

exit 0
