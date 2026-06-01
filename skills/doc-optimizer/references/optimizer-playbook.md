# Doc Optimizer Playbook

Heuristics and formats for the `doc-optimizer` skill. The feature-doc and `_shared.md`
templates themselves live in
[../../design/references/architecture-templates.md](../../design/references/architecture-templates.md).

---

## Migration mapping (legacy layer docs → feature docs)

When `migrate` splits the four legacy layer docs, route each unit to the feature that
owns it. "Owns" = the feature whose stories create or primarily change it.

| Legacy doc           | Unit                 | Goes to                                                                                                                         |
| -------------------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `components.md`      | A component/service  | the feature doc whose stories build it; `_shared.md` if 2+ features depend on it                                                |
| `api-contracts.md`   | An endpoint / action | the feature doc that exposes it; `_shared.md` for cross-cutting gateways/middleware                                             |
| `database-schema.md` | A table / entity     | the feature doc that owns its lifecycle; `_shared.md` for base/shared tables (User, audit, joins spanning features)             |
| `data-flow.md`       | A flow               | the feature doc whose boundary the flow lives in; split a cross-feature flow at the boundary and link both docs to `_shared.md` |

**Ownership tie-breakers**

- A component used by exactly one feature → that feature's doc.
- Used by two or more features → `_shared.md`, linked from each consumer's
  `## Shared dependencies`.
- Unclear ownership → ask the user; do not guess silently.

**Diagrams** — architecture/ER/flow diagrams that span the whole system stay as a
high-level diagram in the relevant global doc or `_shared.md`; per-feature detail is
redrawn (or trimmed) inside each feature doc. Do not copy a whole system diagram into
every feature doc.

**Never drop content.** Every section of a legacy doc must land somewhere (a feature
doc or `_shared.md`) before the original is archived. If a unit cannot be placed,
park it in `_shared.md` under a `## Unsorted (review)` heading and report it.

---

## Dedup rules (`optimize`)

Content is a duplicate-to-hoist when the same component, table, endpoint, or paragraph
appears in **2+ feature docs** with the same meaning.

1. Write one canonical copy in `_shared.md` under the right heading
   (`## Auth & middleware`, `## Base entities / core schema`, etc.).
2. In each feature doc, replace the copy with a one-line link under
   `## Shared dependencies` (e.g. `- [Base User entity](../_shared.md#base-entities--core-schema)`).
3. Keep feature-specific extensions in the feature doc (e.g. "roles adds a `role_id`
   FK to User") — hoist only the shared core, not the feature's own additions.

Do **not** hoist something used by a single feature, even if it is generic-sounding —
single-consumer content stays in that feature's doc to keep it self-contained.

---

## Token report format

Estimate tokens as `ceil(chars / 4)` per file. Present before/after for any mode that
changes files; for `optimize` always show the saving.

```
## Doc Optimizer — <mode> report

| Doc                          | Before | After | Δ      |
| ---------------------------- | ------ | ----- | ------ |
| features/roles.md            | 3,200  | 1,900 | −1,300 |
| features/customer.md         | 2,800  | 2,100 | −700   |
| _shared.md                   | 400    | 1,250 | +850   |
| **Total**                    | 6,400  | 5,250 | −1,150 |

Per-story read budget (folder-structure.md + one feature doc + _shared.md):
  roles story  ≈ <n> tokens  (was: all of docs/architecture ≈ <N> tokens)

Actions:
- migrated: <files>           (archived to docs/architecture/archive/)
- scaffolded: <feature docs>
- hoisted to _shared.md: <items>
- left as `—` in FEATURE_INDEX: <features needing design input>
```

The "per-story read budget" line is the headline number — it shows what a `build`/`fix`
run now reads versus reading the whole architecture before. Always include it.

---

## Safety checklist (every mode)

- Confirm the feature list before slicing (`migrate`) or renaming (`sync`).
- Archive, never delete, legacy docs.
- Confirm before removing any non-empty section (`optimize` prune step).
- Update `tasks/FEATURE_INDEX.md` `Docs` column and `README.md` index in the same run.
- Report what was left unresolved (`—` cells, `## Unsorted (review)` content) so the
  user knows what still needs `design`.
