#!/usr/bin/env bash
# ck-code subagentStatusLine: renders one compact row body per visible subagent
# in the agent panel (used by /ck-code:build PARALLEL MODE worktree implementers).
#
# Input: a single JSON object on stdin with a `.tasks` array; each task has
# id, name, type, status, description, label, startTime, tokenCount, cwd.
# Output: one formatted line per task, in order.
#
# Safe by design: if `jq` is unavailable it prints nothing and exits 0, so
# Claude Code falls back to its default `name · description · tokens` row.

command -v jq >/dev/null 2>&1 || exit 0

jq -r '
  def glyph(s):
    if   s=="running" or s=="in_progress" then "⚡"
    elif s=="completed" or s=="done"      then "✓"
    elif s=="failed" or s=="error"        then "✗"
    elif s=="queued" or s=="pending"      then "…"
    else "•" end;
  def ktok(n):
    if   n==null    then ""
    elif n>=1000    then " · \((n/100|floor)/10)k tok"
    else                 " · \(n) tok" end;
  .tasks[]? |
    "\(glyph(.status)) \(.label // .name // .type // "task")"
    + (if (.description // "") != "" then " · \(.description)" else "" end)
    + ktok(.tokenCount)
' 2>/dev/null

exit 0
