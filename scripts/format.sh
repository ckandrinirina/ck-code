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

# Only format files inside the project — never scratch/temp files elsewhere.
case "$file" in
  /*) case "$file" in "$PWD"/*) ;; *) exit 0 ;; esac ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }

# Prettier runs ONLY when the project opts into it (a config is present). Otherwise
# skip — never impose prettier's defaults on a repo that didn't ask, and never reflow
# hand-aligned Markdown/YAML tables the author maintains deliberately.
# Probes from the file's own directory up to the repo root, so a monorepo package
# config (or a root config seen from a package edit) both count.
prettier_opted_in() {
  local dir d
  case "$file" in
    /*) dir=$(dirname "$file") ;;
    *)  dir=$PWD/$(dirname "$file") ;;
  esac
  while :; do
    for d in .prettierrc .prettierrc.json .prettierrc.yml .prettierrc.yaml \
             .prettierrc.json5 .prettierrc.js .prettierrc.cjs .prettierrc.mjs \
             .prettierrc.toml prettier.config.js prettier.config.cjs prettier.config.mjs; do
      [ -f "$dir/$d" ] && return 0
    done
    [ -f "$dir/package.json" ] && grep -q '"prettier"[[:space:]]*:' "$dir/package.json" 2>/dev/null && return 0
    [ "$dir" = "$PWD" ] || [ "$dir" = "/" ] && break
    dir=$(dirname "$dir")
  done
  return 1
}

# ruff/black run ONLY when the project opts into one of them, same rationale as
# prettier above (never impose formatting a repo did not ask for). Unlike prettier,
# ruff.toml/.ruff.toml are single-purpose files — their mere presence is the opt-in —
# while pyproject.toml/setup.cfg/tox.ini are shared files, so those require the actual
# [tool.ruff]/[tool.black] (or bare [ruff]/[black]) table to be present.
python_opted_in() {
  local dir d
  case "$file" in
    /*) dir=$(dirname "$file") ;;
    *)  dir=$PWD/$(dirname "$file") ;;
  esac
  while :; do
    { [ -f "$dir/ruff.toml" ] || [ -f "$dir/.ruff.toml" ]; } && return 0
    [ -f "$dir/pyproject.toml" ] && grep -Eq '^\[(tool\.ruff|tool\.black)\]' "$dir/pyproject.toml" 2>/dev/null && return 0
    [ -f "$dir/setup.cfg" ] && grep -Eq '^\[(ruff|black)\]' "$dir/setup.cfg" 2>/dev/null && return 0
    [ -f "$dir/tox.ini" ] && grep -Eq '^\[(ruff|black)\]' "$dir/tox.ini" 2>/dev/null && return 0
    [ "$dir" = "$PWD" ] || [ "$dir" = "/" ] && break
    dir=$(dirname "$dir")
  done
  return 1
}

# shfmt runs ONLY when the project opts in via an .editorconfig section for shell
# files, or a bare .shfmt marker file — many shell scripts are deliberately
# hand-formatted and shfmt's defaults would reflow them uninvited.
shfmt_opted_in() {
  local dir d
  case "$file" in
    /*) dir=$(dirname "$file") ;;
    *)  dir=$PWD/$(dirname "$file") ;;
  esac
  while :; do
    [ -f "$dir/.shfmt" ] && return 0
    [ -f "$dir/.editorconfig" ] && grep -Eq '\[\*\.sh\]|shell' "$dir/.editorconfig" 2>/dev/null && return 0
    [ "$dir" = "$PWD" ] || [ "$dir" = "/" ] && break
    dir=$(dirname "$dir")
  done
  return 1
}

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.less|*.html|*.vue|*.md|*.yaml|*.yml)
    if prettier_opted_in; then
      if have prettier; then prettier --write "$file" >/dev/null 2>&1
      elif have npx; then npx --no-install prettier --write "$file" >/dev/null 2>&1; fi
    fi ;;
  *.rs)
    # Bare rustfmt assumes edition 2015 and chokes on modern syntax; try newest first.
    # Language-standard formatter — always runs, no opt-in config to gate on.
    if have rustfmt; then
      rustfmt --edition 2024 "$file" >/dev/null 2>&1 \
        || rustfmt --edition 2021 "$file" >/dev/null 2>&1 \
        || rustfmt "$file" >/dev/null 2>&1
    fi ;;
  *.py)
    if python_opted_in; then
      if have ruff; then ruff format "$file" >/dev/null 2>&1
      elif have black; then black -q "$file" >/dev/null 2>&1; fi
    fi ;;
  *.go)
    # Language-standard formatter — always runs, no opt-in config to gate on.
    have gofmt && gofmt -w "$file" >/dev/null 2>&1 ;;
  *.sh)
    shfmt_opted_in && have shfmt && shfmt -w "$file" >/dev/null 2>&1 ;;
esac

exit 0
