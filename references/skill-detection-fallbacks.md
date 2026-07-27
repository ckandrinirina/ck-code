# Skill Detection — Anchor Fallbacks (legacy generations only)

Read this **only** when Step 4a.2 of [`skill-detection.md`](skill-detection.md) found an
expert or guide whose frontmatter carries **no `paths:` and no `keywords:`** — an older
`/ck-code:team` generation. Current generations are self-describing, so a normal
`build`/`fix` run never opens this file.

These tables are a **last resort**, not a roster: they list anchors for slugs that older
generations happened to produce. Never treat them as the set of skills a project has —
only the `ls` in Step 4a decides that.

## Experts — path / keyword anchors

| File path / keyword                                           | Expert            |
| ------------------------------------------------------------- | ----------------- |
| `mobile/`, `app/`, `components/`, `screens/`, `ui/`           | `expert-frontend` |
| `server/`, `api/`, `backend/`, `services/`                    | `expert-backend`  |
| `docker/`, `.github/`, `ci/`, `deploy/`                       | `expert-devops`   |
| `auth/`, secrets/crypto/payment paths or keywords             | `expert-security` |
| DB migrations, `.sql`, `models/`, schema changes              | `expert-database` |
| Technical Notes mentions "frontend"/"UI"/"component"/"screen" | `expert-frontend` |
| Technical Notes mentions "API"/"endpoint"/"server"/"handler"  | `expert-backend`  |
| Technical Notes mentions "deploy"/"CI"/"docker"/"pipeline"    | `expert-devops`   |

## Guides — extension / pattern anchors

| Extension / pattern  | Guide                                         |
| -------------------- | --------------------------------------------- |
| `.rs`                | `guide-rust`                                  |
| `.cpp`, `.h`, `.hpp` | `guide-cpp` (+ `guide-juce` if JUCE detected) |
| `.ts`, `.tsx`        | `guide-typescript`                            |
| `.tsx` in `mobile/`  | `guide-react-native`                          |
| `.py`                | `guide-python`                                |
| `.go`                | `guide-go`                                    |
| `.java`, `.kt`       | `guide-java`                                  |
| `.swift`             | `guide-swift`                                 |
| Framework-specific   | `guide-axum`, `guide-juce`, etc.              |

## Rules

- **Never** open this file when every present skill declares `paths:` or `keywords:` — the manifest wins.
- **Never** infer a skill exists because it appears in a table here — Step 4a's `ls` is the only authority.
- **Always** prefer a `paths:` match over an anchor row when both are available.
