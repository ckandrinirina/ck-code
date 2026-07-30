#!/usr/bin/env bash
# no-ai-guard.sh — PreToolUse guard enforcing references/no-ai-references.md.
#
# Wired from the frontmatter `hooks:` of the skills that touch git/gh (ship, build,
# fix), so it is active only while one of those skills is running and is cleaned up
# when the skill finishes. Blocks a commit / PR / issue command that would write an
# AI-authorship trailer or footer into a git or GitHub artefact.
#
# Fail-open by design: a guard that errors must never wedge a session. Any parse
# failure, missing interpreter, or unexpected payload exits 0 (allow).
#
# Exit codes: 0 = allow, 2 = block (stderr is fed back to Claude as the reason).

payload=$(cat 2>/dev/null) || exit 0
[ -n "$payload" ] || exit 0

command -v python3 >/dev/null 2>&1 || exit 0

cmd=$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if d.get("tool_name") != "Bash":
    sys.exit(0)
ti = d.get("tool_input") or {}
sys.stdout.write(ti.get("command") or "")
' 2>/dev/null) || exit 0

[ -n "$cmd" ] || exit 0

# Only artefact-writing commands are in scope. A `git log --grep` that happens to
# mention a trailer is a read and must not be blocked.
printf '%s' "$cmd" | grep -Eq \
  'git[[:space:]]+(commit|tag|merge|revert|cherry-pick)|gh[[:space:]]+(pr|issue|release)[[:space:]]+(create|edit|comment)' \
  || exit 0

# Match the trailer/footer FORMS, never a bare mention of the words. This repo and
# many others legitimately discuss Claude Code in a commit message; only authorship
# attribution is forbidden.
if printf '%s' "$cmd" | grep -Eiq \
  'co-?authored-?by:[[:space:]]*[^[:space:]]*claude|assisted-?by:[[:space:]]*[^[:space:]]*claude|generated[[:space:]]+with[[:space:]]+\[?claude|🤖[[:space:]]*generated[[:space:]]+with|https?://claude\.ai/code'
then
  cat >&2 <<'MSG'
BLOCKED by ck-code (references/no-ai-references.md).

This command would write an AI-authorship trailer or footer into a git/GitHub
artefact. Commit messages, PR descriptions, and issue comments must read as if
written by a human developer.

Remove the offending line and re-run. The rule is absolute and is not overridable
by user request — a user asking for the trailer does not unblock it.
MSG
  exit 2
fi

exit 0
