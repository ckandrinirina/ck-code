# shellcheck shell=bash
# ck-stack.sh — the code-side half of the team refresh contract. Sourced after ck-common.sh.
#
# The SOURCES digest (ck_team_digest) only moves when design edits tech-stack.md or
# folder-structure.md. A package migration or a new top-level folder changes the code
# and leaves those docs alone, so it never staled a skill. This file closes that gap: it
# fingerprints the stack from the code itself, and `/ck-code:team` snapshots it beside the
# skills it writes, so a drift between the two names exactly what moved.
#
# Fingerprint lines (sorted, LC_ALL=C):
#   dep <ecosystem> <name> <major>   — 0.x keeps the minor (0.110), unparsable versions are *
#   dir <path>                       — top-level source folders and every manifest's folder
# Only the major is kept so a routine minor or patch bump never reads as drift.

CK_TEAM_SNAPSHOT=".claude/skills/.ck-team-stack"

# ck_stack — print the current fingerprint. Empty outside a git work tree.
ck_stack() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local files f eco
  files="$(git ls-files --cached --others --exclude-standard 2>/dev/null \
    | grep -Ev '(^|/)(node_modules|vendor|third_party|\.venv|venv|target|dist|build)/' )"
  {
    printf '%s\n' "$files" | awk -F/ 'NF>1 && $1 !~ /^\./ && $1 != "docs" && $1 != "tasks" { print "dir " $1 }'
    printf '%s\n' "$files" | while IFS= read -r f; do
      case "${f##*/}" in
        package.json) eco=npm ;;
        composer.json) eco=composer ;;
        Cargo.toml) eco=cargo ;;
        pyproject.toml) eco=pypi ;;
        requirements*.txt) eco=pypi-req ;;
        go.mod) eco=go ;;
        pubspec.yaml) eco=pub ;;
        Gemfile) eco=gem ;;
        *) continue ;;
      esac
      [ -f "$f" ] || continue
      case "$f" in */*) printf 'dir %s\n' "${f%/*}" ;; esac
      ck_stack_parse "$eco" "$f"
    done
  } | LC_ALL=C sort -u
}

# ck_stack_parse ECO FILE — one `dep` line per declared dependency (dev ones included: a
# test framework or linter swap changes a guide as surely as a runtime library does).
ck_stack_parse() {
  awk -v eco="$1" '
    function major(v,  p) {
      sub(/^[^0-9]*/, "", v)
      if (v !~ /^[0-9]/) return "*"
      split(v, p, /[^0-9]+/)
      return (p[1] == "0" && p[2] != "") ? "0." p[2] : p[1]
    }
    function emit(e, n, v) {
      if (n == "" || n == "python" || n == "php" || n ~ /^ext-/) return
      print "dep " e " " n " " major(v)
    }
    function pyreq(s,  n, v) {          # "fastapi[all]>=0.110 ; python_version>\"3\""
      gsub(/^[ \t"\x27]+|[ \t",\x27]+$/, "", s)
      if (s == "" || s ~ /^[#-]/) return
      n = s; sub(/[ \t\[<>=!~;@].*$/, "", n)
      n = tolower(n); gsub(/_/, "-", n)
      v = s; sub(/^[^<>=!~@]*/, "", v)
      emit("pypi", n, v)
    }
    eco == "npm" || eco == "composer" {
      line = $0
      if (line ~ /"(dependencies|devDependencies|peerDependencies|optionalDependencies|require|require-dev)"[ \t]*:[ \t]*\{/) {
        blk = 1; sub(/^.*"(dependencies|devDependencies|peerDependencies|optionalDependencies|require|require-dev)"[ \t]*:[ \t]*\{/, "", line)
      } else if (blk && line ~ /^[ \t]*\}/) { blk = 0; next }
      if (blk) {
        while (match(line, /"[^"]+"[ \t]*:[ \t]*"[^"]*"/)) {
          s = substr(line, RSTART, RLENGTH); split(s, q, "\""); emit(eco, q[2], q[4])
          line = substr(line, RSTART + RLENGTH) }
        if (line ~ /\}/) blk = 0
      }
      next
    }
    eco == "cargo" {
      if ($0 ~ /^[ \t]*\[/) {
        sec = $0; gsub(/[ \t]/, "", sec); tab = ""
        if (sec ~ /dependencies\.[A-Za-z0-9_-]+\]$/) { tab = sec; sub(/^.*dependencies\./, "", tab); sub(/\]$/, "", tab); emit("cargo", tab, "") ; tabpending = 1 }
        else tabpending = 0
        indep = (sec ~ /dependencies\]$/); next
      }
      if (tabpending && $0 ~ /^[ \t]*version[ \t]*=/) { v = $0; sub(/^[^"]*"/, "", v); print "dep cargo " tab " " major(v) " @fix"; tabpending = 0; next }
      if (indep && $0 ~ /^[ \t]*[A-Za-z0-9_-]+(\.workspace)?[ \t]*=/) {
        n = $0; sub(/^[ \t]*/, "", n); sub(/[ \t.=].*$/, "", n)
        v = $0; sub(/^[^=]*=[ \t]*/, "", v)
        if (v ~ /^\{/) { if (match(v, /version[ \t]*=[ \t]*"[^"]*"/)) v = substr(v, RSTART, RLENGTH); else v = "" }
        emit("cargo", n, v)
      }
      next
    }
    eco == "pypi" {
      if ($0 ~ /^[ \t]*\[/) {
        sec = $0; gsub(/[ \t]/, "", sec); inlist = 0
        poetry = (sec ~ /^\[tool\.poetry\.(.*\.)?(dev-)?dependencies\]$/)
        lists = (sec == "[project]" || sec == "[project.optional-dependencies]" || sec == "[dependency-groups]")
        next
      }
      if (poetry && $0 ~ /^[ \t]*[A-Za-z0-9_.-]+[ \t]*=/) {
        n = $0; sub(/^[ \t]*/, "", n); sub(/[ \t=].*$/, "", n); n = tolower(n); gsub(/_/, "-", n)
        v = $0; sub(/^[^=]*=[ \t]*/, "", v)
        if (v ~ /^\{/) { if (match(v, /version[ \t]*=[ \t]*"[^"]*"/)) v = substr(v, RSTART, RLENGTH); else v = "" }
        emit("pypi", n, v); next
      }
      if (lists && !inlist && $0 ~ /^[ \t]*[A-Za-z0-9_-]+[ \t]*=[ \t]*\[/) {
        if (sec == "[project]" && $0 !~ /^[ \t]*dependencies[ \t]*=/) next
        inlist = 1; sub(/^[^\[]*\[/, "")
      }
      if (inlist) {
        line = $0; bare = line; gsub(/"[^"]*"|\x27[^\x27]*\x27/, "", bare); closing = (bare ~ /\]/)
        while (match(line, /"[^"]*"|\x27[^\x27]*\x27/)) { pyreq(substr(line, RSTART, RLENGTH)); line = substr(line, RSTART + RLENGTH) }
        if (closing) inlist = 0
      }
      next
    }
    eco == "pypi-req" { pyreq($0); next }
    eco == "go" {
      if ($0 ~ /^require[ \t]*\(/) { req = 1; next }
      if (req && $0 ~ /^\)/) { req = 0; next }
      if ($0 ~ /\/\/ indirect/) next
      if (req && NF >= 2) emit("go", $1, $2)
      else if ($1 == "require" && NF >= 3) emit("go", $2, $3)
      next
    }
    eco == "pub" {
      if ($0 ~ /^(dev_)?dependencies:/) { dep = 1; next }
      if ($0 ~ /^[^ \t#]/) { dep = 0; next }
      if (dep && $0 ~ /^  [A-Za-z0-9_]+:/) { n = $1; sub(/:$/, "", n); v = $0; sub(/^[^:]*:[ \t]*/, "", v); emit("pub", n, v) }
      next
    }
    eco == "gem" {
      if ($0 ~ /^[ \t]*gem[ \t]+["\x27]/) {
        line = $0; sub(/^[ \t]*gem[ \t]+["\x27]/, "", line)
        n = line; sub(/["\x27].*$/, "", n)
        v = line; sub(/^[^,]*/, "", v)
        if (v !~ /^,[ \t]*["\x27][~<>= ]*[0-9]/) v = ""
        emit("gem", n, v)
      }
      next
    }
  ' "$2" | awk '
    # a [dependencies.serde] table emits "*" first and its real version later as "@fix"
    $NF == "@fix" { fix[$3] = $4; next }
    { line[NR] = $0; key[NR] = $3; eco[NR] = $2 }
    END { for (i = 1; i <= NR; i++) if (i in line) {
            if (eco[i] == "cargo" && (key[i] in fix) && line[i] ~ / \*$/) print "dep cargo " key[i] " " fix[key[i]]
            else print line[i] } }'
}

# ck_team_drift — what moved in the code since `/ck-code:team` last snapshotted it, one
# change per line: `+ dep npm zustand 4`, `- dir legacy`, `~ dep npm react 18 -> 19`.
# Empty when nothing moved, and when there is no snapshot to compare against.
ck_team_drift() {
  [ -f "$CK_TEAM_SNAPSHOT" ] || return 0
  local old new
  old="$(grep -v '^#' "$CK_TEAM_SNAPSHOT" | LC_ALL=C sort -u)"
  new="$(ck_stack)"
  { LC_ALL=C comm -23 <(printf '%s\n' "$old") <(printf '%s\n' "$new") | sed '/^$/d;s/^/- /'
    LC_ALL=C comm -13 <(printf '%s\n' "$old") <(printf '%s\n' "$new") | sed '/^$/d;s/^/+ /'
  } | awk '
    { k = ($2 == "dep") ? $2 " " $3 " " $4 : $2 " " $3
      v = ($2 == "dep") ? $5 : ""
      if ($1 == "-") { if (k in rm) dup[k] = 1; rm[k] = v } else { if (k in ad) dup[k] = 1; ad[k] = v }
      order[++n] = $1 " " k; val[n] = v }
    END {
      for (i = 1; i <= n; i++) {
        s = substr(order[i], 1, 1); k = substr(order[i], 3)
        if ((k in rm) && (k in ad) && !(k in dup)) { if (s == "+") print "~ " k " " rm[k] " -> " ad[k]; continue }
        print order[i] (val[i] != "" ? " " val[i] : "")
      }
    }' | LC_ALL=C sort -k2
}

# ck_team_drift_relevant — the drift lines worth a question: a `dep` that was removed or
# changed major AND that the project already documents — an existing guide-<slug> names
# it, or tech-stack.md / guide-conventions mentions it. A new dependency, a new folder, or
# a bump of something nobody documented never costs the user a prompt or a refresh.
ck_team_drift_relevant() {
  local slugs docs
  slugs="$(ls -d .claude/skills/guide-*/ 2>/dev/null | sed 's|.*/guide-||;s|/$||' | grep -Ev '^(conventions|design-system)$')"
  docs="$(cat docs/architecture/tech-stack.md .claude/skills/guide-conventions/SKILL.md 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  ck_team_drift | CK_SLUGS="$slugs" CK_DOCS="$docs" awk '
    BEGIN { ns = split(ENVIRON["CK_SLUGS"], s, "\n"); docs = ENVIRON["CK_DOCS"]; gsub(/\n/, " ", docs) }
    $1 == "+" || $2 != "dep" { next }
    { n = tolower($4); sub(/^@[^\/]*\//, "", n); sub(/^.*\//, "", n); sub(/\/v[0-9]+$/, "", n)
      for (i = 1; i <= ns; i++) if (s[i] != "" && index(n, s[i]) == 1) { print; next }
      if (length(n) > 2 && match(" " docs " ", "[^a-z0-9_-]" n "[^a-z0-9_-]")) print }'
}

# ck_team_snapshot — record the current fingerprint as the stack the team skills describe.
ck_team_snapshot() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  mkdir -p "$(dirname "$CK_TEAM_SNAPSHOT")"
  { printf '# ck-code:team stack snapshot — written by `ck-team snapshot`, compared by `ck-team drift`. Do not edit.\n'
    ck_stack
  } > "$CK_TEAM_SNAPSHOT"
}

# ck_team_owned — 0 when at least one team-owned (GENERATED) skill exists.
ck_team_owned() {
  local f
  for f in .claude/skills/expert-*/SKILL.md .claude/skills/guide-*/SKILL.md; do
    [ -f "$f" ] && grep -q 'ck-code:team GENERATED' "$f" 2>/dev/null && return 0
  done
  return 1
}

# ck_team_restamp FILE… — move owned skills onto the current digest without regenerating
# them: for a skill the latest doc edit does not concern. Protected files are skipped.
ck_team_restamp() {
  local want f tmp
  want="$(ck_team_digest)"
  [ -n "$want" ] || return 0
  for f in "$@"; do
    [ -f "$f" ] && grep -q 'ck-code:team GENERATED' "$f" 2>/dev/null || { printf 'skipped (not team-owned): %s\n' "$f" >&2; continue; }
    tmp="$f.tmp.$$"
    awk -v d="$want" '
      /ck-code:team SOURCES/ { if (!done) print "<!-- ck-code:team SOURCES " d " -->"; done = 1; next }
      { print }
      /ck-code:team GENERATED/ && !done && !seen { seen = 1; getline nx
        if (nx ~ /ck-code:team SOURCES/) print "<!-- ck-code:team SOURCES " d " -->"
        else { print "<!-- ck-code:team SOURCES " d " -->"; print nx }
        done = 1 }
    ' "$f" > "$tmp" && mv "$tmp" "$f"
  done
}
