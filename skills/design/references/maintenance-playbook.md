# Maintenance Playbook — `design optimize` / `design sync`

Heuristics and report formats for the `design` skill's maintenance modes (PHASE O /
PHASE S). The feature-doc and `_shared.md` templates themselves live in
[architecture-templates.md](architecture-templates.md). Layout migration
(flat→subfolder, legacy layer docs) is **not** here — that is `/ck-code:migrate`.

---

## Dedup rules (`optimize`)

Content is a duplicate-to-hoist when the same component, table, endpoint, or paragraph
appears in **2+ feature docs** with the same meaning.

1. Write one canonical copy in `_shared.md` under the right heading
   (`## Auth & middleware`, `## Base entities / core schema`, etc.).
2. In each feature doc, replace the copy with a one-line link under
   `## Shared dependencies` (e.g. `- [Base User entity](../../_shared.md#base-entities--core-schema)`).
   Feature docs sit two levels under `docs/architecture/`, so the link uses `../../`.
3. Keep feature-specific extensions in the feature doc (e.g. "roles adds a `role_id` FK to
   User") — hoist only the shared core, not the feature's own additions.

Do **not** hoist something used by a single feature, even if it sounds generic —
single-consumer content stays in that feature's doc to keep it self-contained.

---

## Token report format

Estimate tokens as `ceil(chars / 4)` per file. Show before/after for any change; for
`optimize` always show the saving.

```
## Design — optimize report

| Doc                          | Before | After | Δ      |
| ---------------------------- | ------ | ----- | ------ |
| features/roles/index.md      | 3,200  | 1,900 | −1,300 |
| features/customer/index.md   | 2,800  | 2,100 | −700   |
| _shared.md                   | 400    | 1,250 | +850   |
| **Total**                    | 6,400  | 5,250 | −1,150 |

Per-story read budget (folder-structure.md + one feature doc + _shared.md):
  roles story  ≈ <n> tokens  (was: all of docs/architecture ≈ <N> tokens)

Actions:
- hoisted to _shared.md: <items>
- pruned: <sections>
- scaffolded (sync): <feature docs>
- renamed (sync slug drift): <old → new>
- left needing a design pass: <stub features>
```

The "per-story read budget" line is the headline number — it shows what a `build`/`fix`
run now reads versus reading the whole architecture before. Always include it in an
`optimize` report.

---

## Reporting (both modes)

Always report what was left unresolved — scaffolded stubs, features still needing a real
`design` pass, and any split/rename the user must wire into `plan` — so the user knows what
still needs attention. The skill's `## RULES` block owns the safety constraints
(confirm-before-destructive, never hand-edit a generated index, regenerate with `ck-index.sh`).
