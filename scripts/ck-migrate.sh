#!/usr/bin/env bash
# ck-migrate.sh — convert a v6 ck-code project to the v7 layout, deterministically.
#
# Everything v6 → v7 changes is mechanical, so it is a script, not prose a model
# re-derives: it runs the same way every time and tests/smoke.sh proves it.
#
# Usage:
#   ck-migrate.sh v7 [--dry-run] [--commit]
#
#   --dry-run  print every change; change nothing
#   --commit   stage and commit the result as one revertable commit
#
# What it does, per v6 project:
#   1. Each plan's PROJECT_OVERVIEW.md / FEATURE_OVERVIEW.md becomes OVERVIEW.md with a
#      frontmatter record: slug, title, integration, branch, issue, pr, delivery.
#      The plan's level is the widest its epics used (feature → plan, then epic, then
#      story). A `feature` PR v6 copied onto every such EPIC.md moves to the record.
#   2. Every EPIC.md loses `integration:`, a plan property now. Its `## Dependencies`
#      prose stays: it records why one epic waits on another, which blocked_by cannot.
#   3. The views leave git: STORIES_INDEX.md files and FEATURE_INDEX.md are untracked,
#      tasks/.gitignore excludes them, and they are regenerated as EPICS_INDEX.md.
#   4. docs/specs/*/pre-spec.md becomes spec.md; `.metadata.json` drops the constant
#      `stage` key.
#   5. The design-system index.md frontmatter moves into manifest.json, its one home.
#   Both JSON edits are line edits that keep the file's own formatting, so the diff
#   shows the keys that moved and nothing else.
#   6. tasks/VERSION.md is rewritten: layout: v7, requires: ck-code >= 7.0.0.
#
# Refuses: a dirty tree, a project that is already v7 (a no-op, exit 0), a newer layout,
# and a pre-v6 or ck-code-lite project (the migrate skill converts those to v6 first).
#
# Idempotent: every step checks before it writes, so a second run finds nothing to do.

set -uo pipefail

CK_HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck source=scripts/lib/ck-common.sh
. "$CK_HERE/lib/ck-common.sh"

TARGET="${1:-}"
[ "$TARGET" = "v7" ] || { sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
shift
DRY=0; COMMIT=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --commit)  COMMIT=1 ;;
    *) echo "ck-migrate: unknown option $a" >&2; exit 1 ;;
  esac
done

die() { echo "ck-migrate: ERROR — $*" >&2; exit 1; }
say() { echo "  $*"; }
do_() { if [ "$DRY" -eq 1 ]; then return 0; fi; "$@"; }

ck_root || die "no tasks/ directory — nothing to migrate"
git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository"

layout="$(ck_stamp layout)"
case "$layout" in
  v7) if [ -z "$(find tasks -mindepth 2 -maxdepth 2 \( -name PROJECT_OVERVIEW.md -o -name FEATURE_OVERVIEW.md \) 2>/dev/null)" ]; then
        echo "ck-migrate: already v7 — nothing to do"; exit 0
      fi ;;
  v6|"") ;;
  v[0-9]*) n=${layout#v}; [ "$n" -gt 7 ] 2>/dev/null && die "layout $layout is newer than this ck-code — update the plugin, never migrate down"
           die "layout $layout is pre-v6 — /ck-code:migrate converts it to v6 first" ;;
  *) die "unreadable layout stamp '$layout' in tasks/VERSION.md" ;;
esac
[ -f tasks/PLAN.md ] && die "tasks/PLAN.md is a ck-code-lite plan — /ck-code:migrate converts it"
find tasks -type f -path 'tasks/*/epics/*/stories/*.md' -exec grep -L '^id: ' {} + 2>/dev/null | grep -q . \
  && die "a story has no frontmatter id — this is a pre-v4 project; /ck-code:migrate converts it first"

# Views a v7 reader regenerated before the migration ran are not user changes.
dirty=$(git status --porcelain | grep -vE '^\?\? (tasks/EPICS_INDEX\.md|tasks/\.gitignore|tasks/.*STORIES_INDEX\.md)$' || true)
if [ "$DRY" -eq 0 ] && [ -n "$dirty" ]; then
  die "the working tree is not clean — commit or stash first, so the migration is one revertable commit"
fi

echo "ck-migrate: v6 → v7$([ "$DRY" -eq 1 ] && echo ' · DRY RUN')"

# strip_key FILE KEY — drop one frontmatter line.
strip_key() {
  local f="$1" k="$2" tmp
  grep -q "^$k:" "$f" || return 0
  tmp="$(mktemp "$f.ck.XXXXXX")"; cp -p "$f" "$tmp"
  awk -v key="$k" '
    NR==1 { inb = ($0=="---"); print; next }
    inb && $0=="---" { inb=0; print; next }
    inb { i=index($0,":"); if (i>0 && substr($0,1,i-1)==key) next }
    { print }' "$f" > "$tmp" && mv -f "$tmp" "$f"
}

# ---- 1 + 2: plan records and epic cleanup -------------------------------------
while IFS= read -r plan; do
  [ -n "$plan" ] || continue
  old=""
  for n in PROJECT_OVERVIEW.md FEATURE_OVERVIEW.md; do [ -f "$plan/$n" ] && { old="$plan/$n"; break; }; done
  [ -n "$old" ] || continue

  level=story; plan_pr=""; plan_dv=""; mixed=""
  while IFS= read -r dir; do
    [ -f "$dir/EPIC.md" ] || continue
    lv="$(ck_fm "$dir/EPIC.md" integration)"
    case "$lv" in
      feature) level=plan
               [ -n "$(ck_fm "$dir/EPIC.md" pr)" ] && { plan_pr="$(ck_fm "$dir/EPIC.md" pr)"; plan_dv="$(ck_fm "$dir/EPIC.md" delivery)"; } ;;
      epic)    [ "$level" = story ] && level=epic ;;
    esac
    # An empty level is an epic v6 never asked about yet, not a choice of `story`.
    [ -n "$lv" ] && case "$mixed" in *"$lv"*) ;; *) mixed="$mixed${mixed:+,}$lv" ;; esac
  done < <(ck_epic_dirs "$plan")

  base="$(basename "$plan")"
  slug="${base#[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_}"
  slug="${slug#feature-}"
  # The v6 templates headed the file "Project Overview: <name>"; the name is the title.
  title="$(awk '/^# /{sub(/^# +/,""); sub(/^(Project|Feature) Overview: */,""); print; exit}' "$old")"
  [ -n "$title" ] || title="$slug"
  # A ": " inside an unquoted scalar makes YAML read a nested mapping.
  case "$title" in *": "*|\"*|\'*|"#"*) title="\"$(printf '%s' "$title" | sed 's/"/\\"/g')\"" ;; esac
  branch=""
  if [ "$level" = plan ]; then
    if git rev-parse --verify -q "refs/heads/feat/$base" >/dev/null || \
       git rev-parse --verify -q "refs/remotes/origin/feat/$base" >/dev/null; then
      branch="feat/$base"
    else
      branch="plan/$slug"
    fi
  fi

  say "plan     $plan: $(basename "$old") → OVERVIEW.md  (integration: $level${branch:+, branch: $branch}${plan_pr:+, pr: $plan_pr})"
  case "$mixed" in *,*) say "note     $plan epics used mixed levels ($mixed); the plan takes the widest, $level" ;; esac

  if [ "$DRY" -eq 0 ]; then
    git mv "$old" "$plan/OVERVIEW.md" || die "git mv $old failed"
    tmp="$(mktemp)"
    {
      printf -- '---\nslug: %s\ntitle: %s\nintegration: %s\nbranch: %s\nissue:\npr: %s\ndelivery: %s\n---\n\n' \
        "$slug" "$title" "$level" "$branch" "$plan_pr" "$plan_dv" | sed 's/: $/:/'
      cat "$plan/OVERVIEW.md"
    } > "$tmp" && cat "$tmp" > "$plan/OVERVIEW.md"
    rm -f "$tmp"
  fi

  while IFS= read -r dir; do
    ef="$dir/EPIC.md"
    [ -f "$ef" ] || continue
    if [ -n "$plan_pr" ] && [ "$(ck_fm "$ef" pr)" = "$plan_pr" ]; then
      say "epic     $ef: plan PR #$plan_pr moves to the plan record"
      do_ ck_fm_set "$ef" pr ""
      do_ ck_fm_set "$ef" delivery ""
    fi
    if grep -q '^integration:' "$ef"; then say "epic     $ef: drop integration:"; do_ strip_key "$ef" integration; fi
  done < <(ck_epic_dirs "$plan")
done < <(ck_plans)

# ---- 3: views out of git -----------------------------------------------------------
tracked=$(git ls-files -- 'tasks/*/STORIES_INDEX.md' tasks/FEATURE_INDEX.md 2>/dev/null)
if [ -n "$tracked" ]; then
  say "views    untrack $(printf '%s\n' "$tracked" | grep -c .) generated file(s)"
  # shellcheck disable=SC2086  # generated paths carry no spaces
  do_ git rm -q --cached $tracked
fi
if [ -f tasks/FEATURE_INDEX.md ]; then say "views    remove tasks/FEATURE_INDEX.md (now EPICS_INDEX.md)"; do_ rm -f tasks/FEATURE_INDEX.md; fi
if [ ! -f tasks/.gitignore ] || ! grep -qx 'STORIES_INDEX.md' tasks/.gitignore; then
  say "views    write tasks/.gitignore"
  if [ "$DRY" -eq 0 ]; then
    printf '%s\n' "# Generated by ck-code. The views regenerate from story frontmatter; never commit them." \
      "STORIES_INDEX.md" "EPICS_INDEX.md" >> tasks/.gitignore
  fi
fi

# ---- 4: specs ---------------------------------------------------------------------
while IFS= read -r ps; do
  [ -n "$ps" ] || continue
  say "spec     $ps → $(dirname "$ps")/spec.md"
  do_ git mv "$ps" "$(dirname "$ps")/spec.md"
done < <(find docs/specs -mindepth 2 -maxdepth 2 -name pre-spec.md 2>/dev/null | sort)
while IFS= read -r mj; do
  [ -n "$mj" ] || continue
  grep -q '"stage"' "$mj" || continue
  say "spec     $mj: drop stage"
  if [ "$DRY" -eq 0 ]; then
    python3 - "$mj" <<'PY' || die "could not rewrite $mj"
import re, sys
p = sys.argv[1]
lines = open(p).read().split("\n")
out = []
for i, l in enumerate(lines):
    if re.match(r'^\s*"stage"\s*:', l):
        # The dropped key was the last one: the line before it loses its comma.
        if not l.rstrip().endswith(",") and out and out[-1].rstrip().endswith(","):
            out[-1] = out[-1].rstrip()[:-1]
        continue
    out.append(l)
open(p, "w").write("\n".join(out))
PY
  fi
done < <(find docs/specs -mindepth 2 -maxdepth 2 -name .metadata.json 2>/dev/null | sort)

# ---- 5: design-system metadata --------------------------------------------------------
dsi=docs/architecture/design-system/index.md
dsm=docs/architecture/design-system/manifest.json
if [ -f "$dsi" ] && [ "$(head -1 "$dsi")" = "---" ]; then
  say "design   $dsi frontmatter → $dsm"
  if [ "$DRY" -eq 0 ]; then
    python3 - "$dsi" "$dsm" <<'PY' || die "could not move the design-system metadata"
import json, os, re, sys
idx, man = sys.argv[1], sys.argv[2]
text = open(idx).read()
m = re.match(r'---\n(.*?)\n---\n\n?', text, re.S)
fm = dict(re.findall(r'^([a-z_]+):\s*(.*)$', m.group(1), re.M)) if m else {}
keys = [("project_id", "projectId"), ("project_name", "projectName"),
        ("project_updated_at", "projectUpdatedAt"), ("synced_at", "syncedAt"),
        ("tokens_path", "tokensPath")]
if os.path.exists(man):
    body = open(man).read()
    have = json.loads(body)
    add = [(v, fm[k].strip().strip('"\'')) for k, v in keys if k in fm and v not in have]
    if add:
        # Insert right after the opening brace, in the manifest's own indentation.
        ind = re.search(r'\n(\s+)"', body)
        ind = ind.group(1) if ind else "  "
        ins = "".join('\n%s%s: %s,' % (ind, json.dumps(k), json.dumps(v)) for k, v in add)
        body = body.replace("{", "{" + ins, 1)
        json.loads(body)
        open(man, "w").write(body)
else:
    d = {v: fm[k].strip().strip('"\'') for k, v in keys if k in fm}
    d["cards"] = []
    open(man, "w").write(json.dumps(d, indent=2) + "\n")
if m:
    open(idx, "w").write(text[m.end():])
PY
  fi
fi

# ---- 6: stamp ------------------------------------------------------------------------
say "stamp    tasks/VERSION.md → layout: v7, requires: ck-code >= 7.0.0"
if [ "$DRY" -eq 0 ]; then
  printf '%s\n' '<!-- AUTO-GENERATED by ck-code. DO NOT EDIT BY HAND. -->' '' 'layout: v7' \
    'requires: ck-code >= 7.0.0' > tasks/VERSION.md
  ck_run ck-index >/dev/null || echo "ck-migrate: WARN — ck-index failed; the views regenerate at the next session start" >&2
fi

[ "$DRY" -eq 1 ] && { echo "ck-migrate: dry run — nothing changed"; exit 0; }

git add -A tasks docs 2>/dev/null
if [ "$COMMIT" -eq 1 ]; then
  git commit -q -m "chore(ck-code): migrate the project to layout v7" \
    -m "Plan records in OVERVIEW.md, views out of git, a stable version stamp." \
    || die "the commit failed — the conversion is staged; commit it by hand"
  echo "ck-migrate: done — committed as $(git rev-parse --short HEAD)"
else
  echo "ck-migrate: done — changes staged, not committed"
fi
