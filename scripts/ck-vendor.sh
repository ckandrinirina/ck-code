#!/usr/bin/env bash
# ck-vendor.sh — vendor ck-code INTO a project so it travels with the repo.
#
# Claude Code adopts any directory under `<project>/.claude/skills/` that contains
# `.claude-plugin/plugin.json` as a full project-scope plugin (id `ck-code@skills-dir`):
# its skills, agents, hooks, workflows and `bin/` all load, `${CLAUDE_PLUGIN_ROOT}`
# resolves to the vendored folder, and it is enabled by default with no install step
# and no settings entry. The one gate is workspace trust — on a fresh clone the scan
# skips project dirs until the trust dialog is accepted, then /reload-plugins.
#
# So a vendored + committed copy means: clone the repo on any machine, accept trust,
# and every /ck-code:* command works with no marketplace, no plugin cache, no network.
#
# Usage:
#   ck-vendor install [--from <dir>] [--force]   vendor the running plugin into this project
#   ck-vendor update [--to vX.Y.Z] [--from <dir>] [--offline]
#                                                 3-way sync the vendored copy to a newer version
#   ck-vendor check [--online] [--quiet]         report vendored vs. available version
#   ck-vendor refresh                            probe GitHub for the latest tag, cache it, print nothing
#   ck-vendor status                             full report: version, duplicates, git, local edits
#   ck-vendor dedupe                             write only the enabledPlugins keys (fix duplicates)
#   ck-vendor gitignore [--fix]                  show (or apply) the .gitignore change
#   ck-vendor remove                             un-vendor: drop the folder and the settings keys
#
# Exit status: 0 success / nothing to do, 1 a problem the user must act on, 2 usage error.
#
# Writes nothing outside `<project>/.claude/` and `<project>/.gitignore`, and never
# touches `tasks/` or `docs/` — this is the delivery layer, not project state. It is
# therefore exempt from the version gate: a pre-v6 project on a machine with no plugin
# must be able to vendor first and run /ck-code:migrate second.

set -uo pipefail

PLUGIN="ck-code"
REPO="ckandrinirina/ck-code"
VENDOR_REL=".claude/skills/${PLUGIN}"
SETTINGS_REL=".claude/settings.json"
META_NAME=".ck-vendor.json"
SUMS_NAME=".ck-vendor.sums"
LATEST_NAME=".ck-vendor-latest"
# Re-probe GitHub at most once a day. The SessionStart notice reads the cache, so a
# fresh release surfaces at most one session late — never at the cost of a slow start.
REFRESH_TTL=86400

# What a runtime copy consists of. Deliberately not the whole repo: README.md (36K)
# and CHANGELOG.md (132K) are never loaded by anything and would be the bulk of the
# bytes committed into every project.
VDIRS=(.claude-plugin agents bin hooks references scripts skills workflows)
VFILES=(settings.json LICENSE)
# marketplace.json describes the marketplace, not the plugin; a copy inside a vendored
# plugin is dead weight that reads like a second marketplace to register.
VSKIP=(".claude-plugin/marketplace.json")

# ---- plumbing ----------------------------------------------------------------

PLUGIN_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || ROOT="$PWD"

VENDOR="$ROOT/$VENDOR_REL"
SETTINGS="$ROOT/$SETTINGS_REL"
META="$VENDOR/$META_NAME"
SUMS="$VENDOR/$SUMS_NAME"
LATEST="$VENDOR/$LATEST_NAME"

die()  { printf 'ck-vendor: %s\n' "$1" >&2; exit "${2:-1}"; }
say()  { printf '%s\n' "$1"; }
warn() { printf '  ! %s\n' "$1"; }

TMP=""
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP"; }
trap cleanup EXIT

mktmp() { TMP="$(mktemp -d)" || die "cannot create a temp directory"; }

# sha256 of one file. An "intelligent" update is exactly the ability to tell an
# untouched file from an edited one, so a missing digest tool is fatal rather than
# silently degraded into a blind overwrite.
SHA_CMD=""
if command -v shasum >/dev/null 2>&1;      then SHA_CMD="shasum"
elif command -v sha256sum >/dev/null 2>&1; then SHA_CMD="sha256sum"
elif command -v openssl >/dev/null 2>&1;   then SHA_CMD="openssl"
fi
sha_of() {
  case "$SHA_CMD" in
    shasum)    shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' ;;
    sha256sum) sha256sum "$1"    2>/dev/null | awk '{print $1}' ;;
    openssl)   openssl dgst -sha256 "$1" 2>/dev/null | awk '{print $NF}' ;;
    *)         printf '' ;;
  esac
}
need_sha() {
  [ -n "$SHA_CMD" ] || die "no sha256 tool found (shasum, sha256sum or openssl) — cannot compare files safely"
}

# List a source tree's vendorable files, relative and sorted. Doubles as the copy
# plan and the hash plan, so the two can never disagree.
src_files() {
  local src="$1" c skip hit rel
  {
    for c in "${VDIRS[@]}"; do
      [ -d "$src/$c" ] || continue
      ( cd "$src" && find "$c" -type f \
          ! -name '.DS_Store' ! -name '*.swp' ! -name '*~' -print )
    done
    for c in "${VFILES[@]}"; do
      [ -f "$src/$c" ] && printf '%s\n' "$c"
    done
  } | while IFS= read -r rel; do
        hit=0
        for skip in "${VSKIP[@]}"; do [ "$rel" = "$skip" ] && hit=1 && break; done
        [ "$hit" -eq 0 ] && printf '%s\n' "$rel"
      done | LC_ALL=C sort
}

plugin_version_of() { # plugin_version_of DIR
  awk -F'"' '/"version"[[:space:]]*:/{print $4; exit}' "$1/.claude-plugin/plugin.json" 2>/dev/null
}

# Numeric-aware semver compare: prints "gt", "lt" or "eq" for $1 against $2.
vercmp() {
  local a="${1#v}" b="${2#v}"
  [ "$a" = "$b" ] && { printf 'eq\n'; return; }
  if [ "$(printf '%s\n%s\n' "$a" "$b" | LC_ALL=C sort -t. -k1,1n -k2,2n -k3,3n | head -1)" = "$a" ]
  then printf 'lt\n'; else printf 'gt\n'; fi
}

meta_get() { # meta_get KEY — read one scalar from .ck-vendor.json
  [ -f "$META" ] || return 0
  awk -v k="\"$1\"" '
    { line=$0
      i=index(line,k); if(i==0) next
      rest=substr(line,i+length(k)); sub(/^[ \t]*:[ \t]*/,"",rest)
      sub(/,[ \t]*$/,"",rest); gsub(/^"|"$/,"",rest)
      print rest; exit }' "$META"
}

write_meta() { # write_meta VERSION SOURCE REF SKIPPED
  # Every value here is an enum, a dotted version, an ISO date or an integer, so the
  # hand-rolled JSON cannot be broken by an unescaped character.
  local auto; auto="$(meta_get autoCheck)"; [ -n "$auto" ] || auto="true"
  cat > "$META" <<EOF
{
  "plugin": "${PLUGIN}",
  "version": "$1",
  "source": "$2",
  "ref": "$3",
  "vendoredAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "localEdits": $4,
  "autoCheck": ${auto}
}
EOF
}

sums_get() { # sums_get RELPATH — the upstream digest of the version last installed
  [ -f "$SUMS" ] || return 0
  awk -F'\t' -v p="$1" '$2==p{print $1; exit}' "$SUMS"
}

# ---- version discovery -------------------------------------------------------

# Newest ck-code in the local plugin cache, if the marketplace was ever installed
# here. Lets `update` run fully offline on the machine that vendored the project.
#
# Prints "VERSION<TAB>DIR" rather than setting a global: every caller reads it through
# $(...), which runs in a subshell, so an assignment made here would never be visible.
cache_newest() {
  local best="" bestdir="" d v
  for d in "$HOME"/.claude/plugins/cache/*/"$PLUGIN"/*/; do
    [ -f "$d/.claude-plugin/plugin.json" ] || continue
    v="$(plugin_version_of "${d%/}")"
    [ -n "$v" ] || continue
    if [ -z "$best" ] || [ "$(vercmp "$v" "$best")" = "gt" ]; then best="$v"; bestdir="${d%/}"; fi
  done
  [ -n "$best" ] && printf '%s\t%s\n' "$best" "$bestdir"
}

# Latest published tag, via the releases API.
#
# curl ONLY, and always with --max-time. This probe is fired detached from a
# SessionStart hook with nobody watching it, so every second of it must be bounded.
# `git ls-remote` was the obvious fallback and is the wrong tool here: its
# low-speed knobs bound a slow transfer but not the TCP connect, so against a
# black-holed network it hangs indefinitely and leaves a process behind on every
# session start. A machine with no curl simply gets no probe — `check --online`
# and `update` say so in one line, which is a better failure than a leak.
#
# GIT_TERMINAL_PROMPT is exported for `fetch_version`'s clone fallback for the same
# reason: a download that stops to ask for credentials would wait forever.
export GIT_TERMINAL_PROMPT=0
probe_latest() {
  command -v curl >/dev/null 2>&1 || return 1
  local tag
  tag="$(curl -fsS --max-time 8 "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
         | awk -F'"' '/"tag_name"/{print $4; exit}')"
  case "$tag" in v[0-9]*) printf '%s\n' "$tag"; return 0 ;; esac
  return 1
}

cache_latest_read() { # prints "TAG EPOCH" or nothing
  [ -f "$LATEST" ] || return 0
  awk 'NR==1{print $1, $2}' "$LATEST" 2>/dev/null
}

# ---- copy / diff engine ------------------------------------------------------

copy_one() { # copy_one SRCDIR RELPATH
  local src="$1" rel="$2" dst="$VENDOR/$2"
  mkdir -p "$(dirname "$dst")" || return 1
  cp -p "$src/$rel" "$dst" || return 1
  case "$rel" in bin/*|scripts/*) chmod +x "$dst" 2>/dev/null ;; esac
  return 0
}

# Fetch a released version into a temp dir and print its path.
fetch_version() { # fetch_version TAG
  local tag="$1" url d
  mktmp
  url="https://codeload.github.com/$REPO/tar.gz/refs/tags/$tag"
  if command -v curl >/dev/null 2>&1 &&
     curl -fsSL --max-time 180 "$url" 2>/dev/null | tar -xzf - -C "$TMP" 2>/dev/null; then
    d="$(find "$TMP" -maxdepth 1 -mindepth 1 -type d | head -1)"
    [ -n "$d" ] && [ -f "$d/.claude-plugin/plugin.json" ] && { printf '%s\n' "$d"; return 0; }
  fi
  # A shallow clone is the fallback: slower, but it works where the tarball host is
  # blocked and it fails loudly rather than leaving a half-extracted tree behind.
  if git clone --quiet --depth 1 --branch "$tag" "https://github.com/$REPO" "$TMP/clone" 2>/dev/null &&
     [ -f "$TMP/clone/.claude-plugin/plugin.json" ]; then
    printf '%s\n' "$TMP/clone"; return 0
  fi
  return 1
}

# ---- settings (the anti-duplication guarantee) -------------------------------

# Two enabled copies of the same plugin id in one workspace list every /ck-code:*
# command twice — and that is the normal state once a project is vendored, because
# `ck-code@skills-dir` and `ck-code@ck-marketplace` are different ids that do not
# shadow one another. Project settings override user settings, so pinning both keys
# in the committed `.claude/settings.json` leaves exactly one copy live, on every
# machine that clones the repo.
settings_write() { # settings_write true|false  (value for the marketplace key)
  local want="$1"
  mkdir -p "$(dirname "$SETTINGS")"
  if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 not found — merge this into $SETTINGS_REL by hand:"
    printf '        "enabledPlugins": { "%s@skills-dir": true, "%s@ck-marketplace": %s }\n' \
      "$PLUGIN" "$PLUGIN" "$want"
    return 1
  fi
  PLUGIN="$PLUGIN" WANT="$want" SETTINGS="$SETTINGS" python3 - <<'PY'
import json, os, sys
path, plugin, want = os.environ['SETTINGS'], os.environ['PLUGIN'], os.environ['WANT']
data = {}
if os.path.exists(path):
    try:
        with open(path, encoding='utf-8') as fh:
            data = json.load(fh)
    except Exception as exc:
        print('  ! %s is not valid JSON (%s) — left untouched' % (path, exc))
        sys.exit(1)
    if not isinstance(data, dict):
        print('  ! %s is not a JSON object — left untouched' % path)
        sys.exit(1)
ep = data.get('enabledPlugins')
if not isinstance(ep, dict):
    ep = {}
before = dict(ep)
ep['%s@skills-dir' % plugin] = True
ep['%s@ck-marketplace' % plugin] = (want == 'true')
data['enabledPlugins'] = ep
with open(path, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write('\n')
print('  = enabledPlugins already pinned' if before == ep
      else '  ~ %s — enabledPlugins pinned' % os.path.relpath(path, os.getcwd()))
PY
}

settings_drop() {
  [ -f "$SETTINGS" ] || return 0
  command -v python3 >/dev/null 2>&1 || {
    warn "python3 not found — remove the ${PLUGIN}@* keys from $SETTINGS_REL by hand"; return 1; }
  PLUGIN="$PLUGIN" SETTINGS="$SETTINGS" python3 - <<'PY'
import json, os, sys
path, plugin = os.environ['SETTINGS'], os.environ['PLUGIN']
try:
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)
except Exception:
    sys.exit(0)
if not isinstance(data, dict):
    sys.exit(0)
ep = data.get('enabledPlugins')
if isinstance(ep, dict):
    for key in ('%s@skills-dir' % plugin, '%s@ck-marketplace' % plugin):
        ep.pop(key, None)
    if not ep:
        data.pop('enabledPlugins', None)
if data:
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write('\n')
    print('  ~ %s — %s keys removed' % (os.path.relpath(path, os.getcwd()), plugin))
else:
    os.remove(path)
    print('  - %s (now empty)' % os.path.relpath(path, os.getcwd()))
PY
}

# Reads the committed settings back: is the marketplace copy actually pinned off?
settings_state() {
  [ -f "$SETTINGS" ] || { printf 'absent\n'; return; }
  if grep -q "\"${PLUGIN}@ck-marketplace\"[[:space:]]*:[[:space:]]*false" "$SETTINGS" 2>/dev/null
  then printf 'pinned\n'; else printf 'unpinned\n'; fi
}

# ---- .gitignore --------------------------------------------------------------

GITIGNORE_BLOCK="# ck-code: the vendored plugin and its settings must be committed to travel with the repo.
.claude/*
!.claude/settings.json
!.claude/skills/
.claude/skills/*
!.claude/skills/${PLUGIN}/"

# Which file:line ignores the vendored copy, if any. `git check-ignore -v` names the
# source, which matters: a rule in a global excludesfile or .git/info/exclude is not
# ours to rewrite, and a project that ignores .claude/ from somewhere else needs a
# report, not a surprise edit.
gitignore_rule() {
  git -C "$ROOT" check-ignore -v --no-index "$VENDOR_REL/.claude-plugin/plugin.json" 2>/dev/null | head -1
}

gitignore_fix() {
  local rule file pat
  rule="$(gitignore_rule)"
  [ -n "$rule" ] || { say "  = .gitignore already allows $VENDOR_REL/"; return 0; }
  file="${rule%%:*}"; rule="${rule#*:}"; rule="${rule#*:}"; pat="${rule%%$'\t'*}"

  if [ "$file" != ".gitignore" ]; then
    warn "$VENDOR_REL/ is ignored by '$pat' in $file — not this project's .gitignore"
    say  "        add these rules there yourself, or drop the pattern:"
    printf '%s\n' "$GITIGNORE_BLOCK" | sed 's/^/        /'
    return 1
  fi

  # A bare `.claude/` excludes the directory itself, and git cannot re-include a path
  # below an excluded directory — negations under it are dead. So the rule is rewritten
  # into the per-child form that keeps the original intent for everything except the
  # vendored plugin and the settings file that pins it.
  #
  # The block reaches awk as a FILE, not as -v: a multi-line -v assignment is a syntax
  # error in awk, which silently left .gitignore untouched while the caller reported
  # success.
  local gi="$ROOT/.gitignore" tmpf blockf
  tmpf="$(mktemp)" || return 1
  blockf="$(mktemp)" || { rm -f "$tmpf"; return 1; }
  printf '%s\n' "$GITIGNORE_BLOCK" > "$blockf"
  if awk -v pat="$pat" -v bf="$blockf" '
       function emit_block(  l) { while ((getline l < bf) > 0) print l; close(bf) }
       { line=$0; sub(/\r$/,"",line)
         if (!done && line==pat) { emit_block(); done=1; next }
         print }
       END { if (!done) { print ""; emit_block() } }
     ' "$gi" > "$tmpf" && [ -s "$tmpf" ]; then
    cat "$tmpf" > "$gi"
    say "  ~ .gitignore — '$pat' replaced with the per-child form"
  else
    rm -f "$tmpf" "$blockf"
    warn ".gitignore could not be rewritten — add these rules by hand:"
    printf '%s\n' "$GITIGNORE_BLOCK" | sed 's/^/          /'
    return 1
  fi
  rm -f "$tmpf" "$blockf"
  [ -n "$(gitignore_rule)" ] && { warn "$VENDOR_REL/ is STILL ignored — check .gitignore by hand"; return 1; }
  return 0
}

vendor_gitignore_self() {
  # `.ck-vendor-latest` is this machine's update-probe cache, not project content.
  mkdir -p "$VENDOR"
  printf '# machine-local update-probe cache — never committed\n/%s\n' "$LATEST_NAME" \
    > "$VENDOR/.gitignore"
}

# ---- local-edit detection ----------------------------------------------------

# Prints one relpath per vendored file whose content no longer matches the digest
# recorded when it was installed.
#
# Verification is BATCHED through one `shasum -c` / `sha256sum -c` process. The
# per-file loop it replaces forked ~90 times and took >2s, which is fine for a
# user-typed command and far too slow for the SessionStart hook that also calls it.
modified_files() {
  [ -f "$SUMS" ] || return 0
  local ck sum rel cur
  case "$SHA_CMD" in
    shasum|sha256sum)
      ck="$(mktemp)" || return 0
      # `sha<TAB>path` is our on-disk format; `sha  path` is what -c consumes.
      awk -F'\t' 'NF>=2{printf "%s  %s\n", $1, $2}' "$SUMS" > "$ck"
      ( cd "$VENDOR" 2>/dev/null || exit 0
        case "$SHA_CMD" in
          shasum)    shasum -a 256 -c "$ck" 2>/dev/null ;;
          sha256sum) sha256sum -c "$ck" 2>/dev/null ;;
        esac ) | sed -n 's/: FAILED.*$//p'
      rm -f "$ck"
      ;;
    *)
      while IFS=$'\t' read -r sum rel; do
        [ -n "$rel" ] || continue
        if [ ! -f "$VENDOR/$rel" ]; then printf '%s\n' "$rel"; continue; fi
        cur="$(sha_of "$VENDOR/$rel")"
        [ "$cur" = "$sum" ] || printf '%s\n' "$rel"
      done < "$SUMS"
      ;;
  esac
}

# ---- commands ----------------------------------------------------------------

cmd_install() {
  local from="" force=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --from) from="${2:-}"; shift 2 || die "--from needs a directory" 2 ;;
      --force) force=1; shift ;;
      *) die "install: unknown flag $1" 2 ;;
    esac
  done
  need_sha

  local src="${from:-$PLUGIN_ROOT}"
  src="$(CDPATH= cd -- "$src" 2>/dev/null && pwd -P)" || die "no such source directory: ${from:-$PLUGIN_ROOT}"
  [ -f "$src/.claude-plugin/plugin.json" ] || die "$src is not a $PLUGIN plugin root"
  [ "$src" = "$(CDPATH= cd -- "$VENDOR" 2>/dev/null && pwd -P || echo /nonexistent)" ] &&
    die "the running plugin IS the vendored copy — use 'ck-vendor update' instead"

  local ver; ver="$(plugin_version_of "$src")"
  [ -n "$ver" ] || die "cannot read a version from $src/.claude-plugin/plugin.json"

  if [ -d "$VENDOR" ] && [ "$force" -eq 0 ]; then
    die "$VENDOR_REL/ already exists (version $(meta_get version)) — use 'ck-vendor update', or 'install --force' to overwrite"
  fi

  say "Vendoring $PLUGIN $ver into $VENDOR_REL/"
  local rel n=0
  while IFS= read -r rel; do
    copy_one "$src" "$rel" || die "failed to copy $rel"
    n=$((n+1))
  done < <(src_files "$src")
  [ "$n" -gt 0 ] || die "copied nothing — $src has no plugin component directories"

  : > "$SUMS"
  while IFS= read -r rel; do
    printf '%s\t%s\n' "$(sha_of "$VENDOR/$rel")" "$rel" >> "$SUMS"
  done < <(src_files "$src")

  local source_kind="plugin-root"; [ -n "$from" ] && source_kind="dir"
  write_meta "$ver" "$source_kind" "v$ver" 0
  vendor_gitignore_self
  say "  + $n files"

  settings_write false
  say ""
  cmd_gitignore
  say ""
  say "Vendored. Commit $VENDOR_REL/, $SETTINGS_REL and .gitignore, and the next clone"
  say "of this repo runs /ck-code:* with no plugin install — accept the workspace trust"
  say "dialog once, then run /reload-plugins in this session to load the vendored copy."
}

cmd_update() {
  local to="" from="" offline=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --to) to="${2:-}"; shift 2 || die "--to needs a version" 2 ;;
      --from) from="${2:-}"; shift 2 || die "--from needs a directory" 2 ;;
      --offline) offline=1; shift ;;
      *) die "update: unknown flag $1" 2 ;;
    esac
  done
  need_sha
  [ -d "$VENDOR" ] || die "no vendored copy at $VENDOR_REL/ — run 'ck-vendor install' first"
  [ -f "$SUMS" ] || die "$VENDOR_REL/$SUMS_NAME is missing — re-run 'ck-vendor install --force' to re-baseline"

  local have; have="$(meta_get version)"
  [ -n "$have" ] || have="$(plugin_version_of "$VENDOR")"

  # Resolve a source: an explicit directory, an explicit tag, the local plugin cache,
  # then the newest published tag.
  local src="" tag="" kind=""
  if [ -n "$from" ]; then
    src="$(CDPATH= cd -- "$from" 2>/dev/null && pwd -P)" || die "no such source directory: $from"
    kind="dir"; tag="v$(plugin_version_of "$src")"
  elif [ -n "$to" ]; then
    case "$to" in v*) tag="$to" ;; *) tag="v$to" ;; esac
    say "Fetching $PLUGIN ${tag}…"
    src="$(fetch_version "$tag")" || die "could not fetch $tag from $REPO"
    kind="github"
  else
    local cached cachedver cacheddir
    cached="$(cache_newest)"
    cachedver="${cached%%$'\t'*}"; cacheddir="${cached#*$'\t'}"
    if [ -n "$cachedver" ] && [ "$(vercmp "$cachedver" "$have")" = "gt" ]; then
      src="$cacheddir"; kind="cache"; tag="v$cachedver"
    elif [ "$offline" -eq 1 ]; then
      say "$PLUGIN $have is the newest copy available offline — nothing to do."
      return 0
    else
      tag="$(probe_latest)" || die "could not reach GitHub to find the latest version — pass --to vX.Y.Z or --from <dir>"
      if [ "$(vercmp "$tag" "$have")" != "gt" ]; then
        say "$PLUGIN $have is already the latest ($tag) — nothing to do."
        printf '%s %s\n' "$tag" "$(date +%s)" > "$LATEST" 2>/dev/null
        return 0
      fi
      say "Fetching $PLUGIN ${tag}…"
      src="$(fetch_version "$tag")" || die "could not fetch $tag from $REPO"
      kind="github"
    fi
  fi
  [ -f "$src/.claude-plugin/plugin.json" ] || die "$src is not a $PLUGIN plugin root"

  local ver; ver="$(plugin_version_of "$src")"
  [ -n "$ver" ] || die "cannot read a version from the source"
  say "updating $have -> $ver ($kind${tag:+ $tag})"

  # 3-way apply. `old` is the digest of the version last installed for that path,
  # `cur` what is on disk now, `new` what the source ships. A file the user edited
  # (cur != old) is never overwritten — it is reported and left alone, and its `old`
  # digest is preserved so the next update still recognises it as edited.
  local plan; plan="$(mktemp)" || die "cannot create a temp file"
  { src_files "$src"; awk -F'\t' '{print $2}' "$SUMS"; } | LC_ALL=C sort -u > "$plan"

  local added=0 changed=0 removed=0 kept=0 restored=0
  local rel old cur new
  local newsums; newsums="$(mktemp)" || die "cannot create a temp file"

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    old="$(sums_get "$rel")"
    cur=""; [ -f "$VENDOR/$rel" ] && cur="$(sha_of "$VENDOR/$rel")"
    new=""; [ -f "$src/$rel" ] && new="$(sha_of "$src/$rel")"

    if [ -n "$cur" ] && [ -n "$old" ] && [ "$cur" != "$old" ]; then
      # Locally modified. Keep it, keep its baseline.
      if [ "$cur" = "$new" ]; then
        printf '%s\t%s\n' "$new" "$rel" >> "$newsums"
      else
        say "   ! $rel  locally modified, kept"
        kept=$((kept+1))
        printf '%s\t%s\n' "$old" "$rel" >> "$newsums"
      fi
      continue
    fi

    if [ -z "$new" ]; then
      if [ -n "$cur" ]; then
        rm -f "$VENDOR/$rel"; say "   - $rel"; removed=$((removed+1))
      fi
      continue
    fi

    if [ -z "$cur" ]; then
      copy_one "$src" "$rel" || die "failed to copy $rel"
      if [ -n "$old" ]; then say "   + $rel  (restored)"; restored=$((restored+1))
      else say "   + $rel"; added=$((added+1)); fi
    elif [ "$cur" != "$new" ]; then
      copy_one "$src" "$rel" || die "failed to copy $rel"
      say "   ~ $rel"; changed=$((changed+1))
    fi
    printf '%s\t%s\n' "$new" "$rel" >> "$newsums"
  done < "$plan"

  LC_ALL=C sort -k2 "$newsums" > "$SUMS"
  rm -f "$plan" "$newsums"

  # Prune directories the new version no longer ships.
  find "$VENDOR" -type d -empty -delete 2>/dev/null

  write_meta "$ver" "$kind" "${tag:-v$ver}" "$kept"
  vendor_gitignore_self
  # Only a real published tag updates the latest-tag cache. A `--from <dir>` source is
  # a local tree that says nothing about what is published, and stamping it there made
  # the session-start notice advertise a version nobody can download.
  [ "$kind" = "github" ] && [ -n "$tag" ] && printf '%s %s\n' "$tag" "$(date +%s)" > "$LATEST" 2>/dev/null

  say ""
  say "$added added, $changed updated, $removed removed, $restored restored, $kept kept"
  if [ "$kept" -gt 0 ]; then
    say "$kept file(s) you had edited were left as-is — review with:"
    say "  git diff -- $VENDOR_REL"
    say "Re-run 'ck-vendor install --force' to discard your edits and take the release verbatim."
  fi
  say "Run /reload-plugins to pick up the new version in this session."
}

cmd_refresh() {
  # Called detached from the SessionStart hook: prints nothing, never fails, and
  # owns the once-a-day throttle so the hook stays a single unconditional fork.
  # A failed probe still stamps the cache, so an offline machine retries daily
  # rather than on every session start.
  [ -d "$VENDOR" ] || exit 0
  [ "$(meta_get autoCheck)" = "false" ] && exit 0
  local force=0 last now tag
  [ "${1:-}" = "--force" ] && force=1
  now="$(date +%s)"
  last="$(cache_latest_read | awk '{print $2}')"
  if [ "$force" -eq 0 ] && [ -n "$last" ] && [ $((now - last)) -lt "$REFRESH_TTL" ]; then exit 0; fi

  # Stamp the throttle BEFORE probing, keeping whatever tag was last known. A probe
  # that hangs (or is killed with the session) would otherwise never write a stamp,
  # so every subsequent session start would spawn another one behind it.
  local known; known="$(cache_latest_read | awk '{print $1}')"
  printf '%s %s\n' "${known:-unknown}" "$now" > "$LATEST" 2>/dev/null

  tag="$(probe_latest)" || exit 0
  printf '%s %s\n' "$tag" "$now" > "$LATEST" 2>/dev/null
  exit 0
}

cmd_check() {
  local online=0 quiet=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --online) online=1; shift ;;
      --quiet|-q) quiet=1; shift ;;
      *) die "check: unknown flag $1" 2 ;;
    esac
  done
  if [ ! -d "$VENDOR" ]; then
    [ "$quiet" -eq 1 ] && return 0
    say "$PLUGIN is not vendored in this project — run 'ck-vendor install' to make it travel with the repo."
    return 0
  fi

  local have latest="" src="cache"
  have="$(meta_get version)"; [ -n "$have" ] || have="$(plugin_version_of "$VENDOR")"

  if [ "$online" -eq 1 ]; then
    latest="$(probe_latest)" || latest=""
    [ -n "$latest" ] && printf '%s %s\n' "$latest" "$(date +%s)" > "$LATEST" 2>/dev/null
    src="github"
  else
    latest="$(cache_latest_read | awk '{print $1}')"
    [ "$latest" = "unknown" ] && latest=""
    if [ -z "$latest" ]; then
      local c; c="$(cache_newest)"; [ -n "$c" ] && latest="v${c%%$'\t'*}"
    fi
  fi

  # The local-edit scan is deliberately AFTER every `--quiet` exit: it is the only
  # expensive part of this command, and the SessionStart hook — the one caller that
  # passes --quiet — needs the version line and nothing else.
  if [ -n "$latest" ] && [ "$(vercmp "$latest" "$have")" = "gt" ]; then
    say "ck-code vendored copy is $have — $latest is available. Run \`ck-vendor update\`."
    [ "$quiet" -eq 1 ] && return 0
  elif [ "$quiet" -eq 1 ]; then
    return 0
  else
    if [ -n "$latest" ]; then say "vendored $have · latest $latest ($src) · up to date"
    else say "vendored $have · latest unknown (no network probe cached — try 'ck-vendor check --online')"; fi
  fi
  local mods n
  mods="$(modified_files)"; n="$(printf '%s' "$mods" | grep -c . 2>/dev/null || true)"
  if [ "${n:-0}" -gt 0 ]; then
    say "$n vendored file(s) differ from the release:"
    printf '%s\n' "$mods" | sed 's/^/  ! /'
  fi
  return 0
}

cmd_status() {
  say ""
  say "ck-code delivery — $(basename "$ROOT")"
  if [ -d "$VENDOR" ]; then
    say "  vendored      $(meta_get version)  ($VENDOR_REL/, source $(meta_get source) $(meta_get ref))"
  else
    say "  vendored      no  (running from the plugin cache: $(plugin_version_of "$PLUGIN_ROOT"))"
  fi

  case "$(settings_state)" in
    pinned)   say "  duplicates    none — ${PLUGIN}@ck-marketplace pinned off in $SETTINGS_REL" ;;
    unpinned) say "  duplicates    RISK — $SETTINGS_REL does not pin ${PLUGIN}@ck-marketplace off" ;;
    absent)   [ -d "$VENDOR" ] && say "  duplicates    RISK — no $SETTINGS_REL, so a marketplace copy loads alongside the vendored one" \
                               || say "  duplicates    n/a  (nothing vendored)" ;;
  esac

  # Other scopes the marketplace copy is installed at. Two enabled copies in one
  # workspace is the duplicate-slash-command bug, and a stale per-project pin is why
  # a project can sit on an old version through every release.
  local inst="$HOME/.claude/plugins/installed_plugins.json"
  if [ -f "$inst" ] && command -v python3 >/dev/null 2>&1; then
    ROOTDIR="$ROOT" PLUGIN="$PLUGIN" INST="$inst" python3 - <<'PY'
import json, os
root, plugin = os.environ['ROOTDIR'], os.environ['PLUGIN']
try:
    with open(os.environ['INST'], encoding='utf-8') as fh:
        data = json.load(fh)
except Exception:
    raise SystemExit(0)
rows = []
for key, entries in (data.get('plugins') or {}).items():
    if not key.startswith(plugin + '@'):
        continue
    for e in entries or []:
        p = e.get('projectPath')
        if e.get('scope') == 'user' or (p and (root == p or root.startswith(p + os.sep))):
            rows.append((e.get('scope'), e.get('version'), p or '-'))
if rows:
    print('  installed     ' + '; '.join('%s %s' % (s, v) for s, v, _ in sorted(rows)))
PY
  fi

  if [ -d "$VENDOR" ]; then
    local rule mods n
    rule="$(gitignore_rule)"
    if [ -n "$rule" ]; then
      say "  git           IGNORED — ${rule%%$'\t'*}"
    elif git -C "$ROOT" ls-files --error-unmatch "$VENDOR_REL/.claude-plugin/plugin.json" >/dev/null 2>&1; then
      say "  git           committed"
    else
      say "  git           not committed yet — run: git add $VENDOR_REL $SETTINGS_REL .gitignore"
    fi
    mods="$(modified_files)"; n="$(printf '%s' "$mods" | grep -c . 2>/dev/null || true)"
    if [ "${n:-0}" -gt 0 ]; then
      say "  local edits   $n file(s) differ from the release:"
      printf '%s\n' "$mods" | sed 's/^/                  ! /'
    else
      say "  local edits   none"
    fi
    local probe; probe="$(cache_latest_read)"
    say "  auto-check    $(meta_get autoCheck)  (cached probe: ${probe:-none yet})"
  fi
  say ""
}

cmd_dedupe() {
  [ -d "$VENDOR" ] || die "nothing vendored — 'ck-vendor dedupe' only makes sense once $VENDOR_REL/ exists"
  say "Pinning plugin scopes in $SETTINGS_REL"
  settings_write false
}

cmd_gitignore() {
  local fix=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --fix) fix=1; shift ;;
      *) die "gitignore: unknown flag $1" 2 ;;
    esac
  done
  local rule
  rule="$(gitignore_rule)"
  if [ -z "$rule" ]; then
    say "  = .gitignore allows $VENDOR_REL/ — nothing to change"
    return 0
  fi
  if [ "$fix" -eq 1 ]; then gitignore_fix; return $?; fi
  local file pat
  file="${rule%%:*}"; rule="${rule#*:}"; rule="${rule#*:}"; pat="${rule%%$'\t'*}"
  warn "$VENDOR_REL/ is ignored by '$pat' in $file — it will NOT be committed,"
  say  "        so the vendored copy will not travel with the repo."
  if [ "$file" = ".gitignore" ]; then
    say "        Proposed change — replace '$pat' with:"
    printf '%s\n' "$GITIGNORE_BLOCK" | sed 's/^/          /'
    say "        Apply with: ck-vendor gitignore --fix"
  else
    say "        $file is not this project's .gitignore — add these rules there yourself:"
    printf '%s\n' "$GITIGNORE_BLOCK" | sed 's/^/          /'
  fi
  return 1
}

cmd_remove() {
  [ -d "$VENDOR" ] || die "nothing vendored at $VENDOR_REL/"
  local mods n
  mods="$(modified_files)"; n="$(printf '%s' "$mods" | grep -c . 2>/dev/null || true)"
  if [ "${n:-0}" -gt 0 ]; then
    warn "$n vendored file(s) differ from the release and will be deleted:"
    printf '%s\n' "$mods" | sed 's/^/        ! /'
  fi
  rm -rf "$VENDOR"
  say "  - $VENDOR_REL/"
  settings_drop
  say ""
  say "Un-vendored. $PLUGIN now loads from the marketplace again — if it is not installed"
  say "on this machine, run: /plugin marketplace add $REPO"
  say "The .gitignore rules added for the vendored copy are left in place; they are inert."
}

# ---- dispatch ----------------------------------------------------------------

usage() {
  sed -n '14,25p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-status}" in
  install)   shift; cmd_install "$@" ;;
  update)    shift; cmd_update "$@" ;;
  check)     shift; cmd_check "$@" ;;
  refresh)   shift; cmd_refresh "$@" ;;
  status)    shift; cmd_status "$@" ;;
  dedupe)    shift; cmd_dedupe "$@" ;;
  gitignore) shift; cmd_gitignore "$@" ;;
  remove)    shift; cmd_remove "$@" ;;
  -h|--help|help) usage ;;
  *) printf 'ck-vendor: unknown command %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
esac
