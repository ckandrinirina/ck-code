# Sync Report Templates

Use these verbatim (or with minor wording changes) for the user-facing diff
report and final summary.

---

## Phase 4 — Diff Report (drift found)

```
## Sync Report — tasks/<slug>

### Index drift ([count])
| # | Story | Field | Index value | Story-file value |
|---|-------|-------|-------------|------------------|
| 1 | 02-01 Login form | Status | TODO | IN PROGRESS |
| 2 | 03-04 Show IP | Size | M | S |

### Index orphans ([count] — story file exists, no index row)
| # | Story | File |
|---|-------|------|
| 3 | 04-02 Write IP | epics/04_desktop/stories/02_write-ip.md |

### Index stale ([count] — index row exists, no story file)
| # | Row ID | Title | File (missing) |
|---|--------|-------|----------------|
| 4 | 02-09 | Old draft | epics/02_auth/stories/09_old-draft.md |

### Epic drift ([count])
| # | Epic | Story | Issue |
|---|------|-------|-------|
| 5 | 03 · Mobile | 03-04 | Listed as TODO in EPIC.md, but story file is IN PROGRESS |

### Epic orphans ([count] — story file in epic folder, missing from EPIC.md)
| # | Epic | Story file |
|---|------|------------|
| 6 | 04 · Desktop | epics/04_desktop/stories/02_write-ip.md (story 04-02) |

### Epic stale ([count] — EPIC.md lists a story that has no file)
| # | Epic | Listed story |
|---|------|--------------|
| 7 | 02 · Auth | 02-09 Old draft |

---

**Apply all repairs?** YES / ABORT / SELECT (specify diff numbers, e.g., `1,3,6`)
```

---

## Phase 4 — In Sync (no drift found)

```
## Sync Report — tasks/<slug>

✓ STORIES_INDEX.md matches every story file.
✓ Every EPIC.md story list matches its epic folder.

Nothing to repair.
```

---

## Phase 4 — Errors (malformed input)

```
## Sync Report — tasks/<slug>

✗ Cannot reconcile — the following files have parse errors:

| # | File | Problem |
|---|------|---------|
| 1 | epics/02_auth/stories/01_login-form.md | Missing `# Story EE-SS:` header |
| 2 | STORIES_INDEX.md | Schema header missing — bootstrap required |

Fix these files (or pass the parent path to allow bootstrap), then re-run /ck-code:sync.
```

---

## Phase 6 — Final Summary

```
## Sync Complete — tasks/<slug>

- Repairs applied:  [count]
- Repairs skipped:  [count]   (user SELECT subset)
- Repairs failed:   [count]   (file write errors — see below)

### Files now in sync
- tasks/<slug>/STORIES_INDEX.md
- tasks/<slug>/epics/03_mobile/EPIC.md
- tasks/<slug>/epics/04_desktop/EPIC.md

### Failed repairs (manual fix required)
[Only present if any repairs failed]
| # | File | Error |
|---|------|-------|
| 7 | epics/02_auth/EPIC.md | `old_string` did not match — story list section was hand-edited |
```

---

## --all summary (multiple plans)

```
## Sync Complete — All Plans

| Plan | Status | Repairs | Failed |
|------|--------|---------|--------|
| tasks/2026-04-01_my-project | IN SYNC | 0 | 0 |
| tasks/2026-04-15_feature-auth | DRIFT FIXED | 4 | 0 |
| tasks/2026-05-02_feature-mobile | ERRORS | - | - |

See per-plan reports above for details.
```
