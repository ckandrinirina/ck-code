#!/usr/bin/env bash
# ck-code agent-progress: what a token count cannot tell you about a running builder.
# The mod's agents pane (/ck-agents) runs it while builders are live.
#
# Input, one line per agent, fields joined by US (0x1f): agent id, story id, cwd.
# Output, one line per agent that has something to show:
#
#   <agent id><US>5/8 63% · +214/-18
#
# The first field is how far the agent's story has got (acceptance criteria ticked, read
# from that agent's OWN worktree). The second is whether it has written any code at all —
# the check `build` P5 later re-derives with git. An agent that reports success having
# changed nothing is the failure this makes visible while it is still happening.
#
# Costs zero model tokens: the pane is drawn by Claude Code, not by the model.
# Safe by design: needs only awk and git, every probe is optional, always exits 0.

# US is not IFS whitespace, so an empty field cannot collapse and shift the ones after it.
US=$(printf '\037')
rows=$(cat 2>/dev/null) || exit 0
[ -n "$rows" ] || exit 0

# A cloned repository's git config must not run a program just to draw a pane.
pgit() { git -c core.fsmonitor=false -c core.hooksPath=/dev/null "$@"; }

# The branch the fan-out was cut from, resolved once for every row: the worktrees
# share one repository, and the main worktree is the one sitting on $TARGET.
target=""
first_cwd=$(printf '%s\n' "$rows" | awk -F"$US" 'NF >= 3 && $3 != "" { print $3; exit }')
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

while IFS="$US" read -r agent id cwd; do
  [ -n "$agent" ] || continue

  # Criteria progress, counted in the worktree's OWN copy of the story — the agent ticks
  # boxes there, so the main checkout reads 0% until the merge lands. The views are not
  # committed, so a worktree has none: the story is found by its `id:` among the
  # worktree's own story files. Only `## Acceptance Criteria` boxes count.
  crit=""
  own=""
  if [ -n "$id" ] && [ -n "$cwd" ] && [ -d "$cwd/tasks" ]; then
    own=$(find "$cwd/tasks" -path '*/epics/*/stories/*.md' -type f \
            -exec grep -lE "^id:[[:space:]]*[\"']?${id}[\"']?[[:space:]]*\$" {} + 2>/dev/null | head -1)
  fi
  if [ -n "$own" ]; then
    crit=$(awk '
      /^## / { inac = ($0 ~ /^## +Acceptance Criteria/); next }
      !inac { next }
      /^[[:space:]]*-[[:space:]]*\[[xX]\]/ { d++ }
      /^[[:space:]]*-[[:space:]]*\[ \]/    { o++ }
      END { t = d + o; if (t > 0) printf "%d/%d %d%%", d, t, (d * 100) / t }' "$own" 2>/dev/null)
  elif [ -n "$id" ] && [ -n "$cwd" ] && [ -d "$cwd" ]; then
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
    # A multi-repo project keeps `tasks/` above the code repo, so an ancestor's view is
    # the fallback; the agent's branch slug decides between plans claiming the id.
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
          if (line ~ /^## /) { inac = (line ~ /^## +Acceptance Criteria/); continue }
          if (!inac) continue
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
    dstat=$(pgit -C "$cwd" diff --no-ext-diff --no-textconv --shortstat "$target" 2>/dev/null | awk '
      { i = 0; d = 0
        if (match($0, /[0-9]+ insertion/)) i = substr($0, RSTART, RLENGTH) + 0
        if (match($0, /[0-9]+ deletion/))  d = substr($0, RSTART, RLENGTH) + 0
        if (i || d) printf "+%d/-%d", i, d }')
  fi

  line=$crit
  [ -n "$dstat" ] && line="${line:+$line · }$dstat"
  [ -n "$line" ] && printf '%s%s%s\n' "$agent" "$US" "$line"
done <<EOF
$rows
EOF

exit 0
