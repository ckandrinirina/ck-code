#!/usr/bin/env bash
# PostToolUse(Write|Edit) hook: best-effort auto-format the file just written,
# so implementation lands already-formatted and QA spends fewer cycles on style.
#
# Safe by design: always exits 0, and is a no-op when the matching formatter
# is not installed. Never fails the turn.

input=$(cat)

# Extract the touched file path from the hook event JSON (jq if present, else sed).
file=""
if command -v jq >/dev/null 2>&1; then
  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
fi
if [ -z "$file" ]; then
  file=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi
[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0

have() { command -v "$1" >/dev/null 2>&1; }

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.less|*.html|*.vue|*.md|*.yaml|*.yml)
    if have prettier; then prettier --write "$file" >/dev/null 2>&1
    elif have npx; then npx --no-install prettier --write "$file" >/dev/null 2>&1; fi ;;
  *.rs)
    have rustfmt && rustfmt "$file" >/dev/null 2>&1 ;;
  *.py)
    if have ruff; then ruff format "$file" >/dev/null 2>&1
    elif have black; then black -q "$file" >/dev/null 2>&1; fi ;;
  *.go)
    have gofmt && gofmt -w "$file" >/dev/null 2>&1 ;;
  *.sh)
    have shfmt && shfmt -w "$file" >/dev/null 2>&1 ;;
esac

exit 0
