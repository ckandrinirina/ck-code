# Plan Skill — Worked Examples

Folder-structure examples per mode. `STORIES_INDEX.md` (per plan) and
`tasks/FEATURE_INDEX.md` (top-level) are shown as **generated** — they are produced by
`scripts/ck-index.sh` from story frontmatter in Phase 5.7, never hand-written.

---

## New Project Mode — tasks/ folder layout

```
tasks/
├── FEATURE_INDEX.md                        # GENERATED (top-level, all plans)
└── YYYY-MM-DD_<project-slug>/
    ├── PROJECT_OVERVIEW.md
    ├── STORIES_INDEX.md                     # GENERATED (this plan)
    ├── epics/
    │   ├── 01_<epic-slug>/
    │   │   ├── EPIC.md                       # frontmatter, no ## Stories table
    │   │   └── stories/
    │   │       ├── 01_<story-slug>.md        # frontmatter source of truth
    │   │       ├── 02_<story-slug>.md
    │   │       └── ...
    │   ├── 02_<epic-slug>/
    │   │   ├── EPIC.md
    │   │   └── stories/
    │   │       └── ...
    │   └── NN_integration-e2e/               # mandatory final epic
    │       ├── EPIC.md
    │       └── stories/
    │           └── ...
    └── ROADMAP.md
```

---

## Feature Mode — Add Feature folder layout

A feature-specific dated folder, prefixed `feature-` so it does not collide with the main
project plan. Numbering restarts at `01` inside this folder.

```
tasks/
├── FEATURE_INDEX.md                        # GENERATED — new epic rows appended
└── YYYY-MM-DD_feature-<feature-slug>/
    ├── FEATURE_OVERVIEW.md                  # instead of PROJECT_OVERVIEW.md
    ├── STORIES_INDEX.md                     # GENERATED (this plan)
    ├── epics/
    │   ├── 01_<epic-slug>/
    │   │   ├── EPIC.md
    │   │   └── stories/
    │   │       └── ...
    │   └── NN_integration-e2e/
    │       └── ...
    └── ROADMAP.md
```

---

## Feature Mode — Continue Existing Plan layout

Files are added inside the SAME existing dated folder. Epic numbering continues from the
last existing epic (last was `04` → new ones start at `05`). `STORIES_INDEX.md` and
`FEATURE_INDEX.md` are regenerated; `PROJECT_OVERVIEW.md` is left unchanged.

```
tasks/
├── FEATURE_INDEX.md                        # GENERATED — regenerated across all plans
└── YYYY-MM-DD_<existing-project-slug>/     # same folder
    ├── PROJECT_OVERVIEW.md                  # unchanged
    ├── STORIES_INDEX.md                     # GENERATED — regenerated with new rows
    ├── epics/
    │   ├── ... (existing epics unchanged)
    │   ├── 05_<new-epic-slug>/              # continues numbering
    │   │   ├── EPIC.md
    │   │   └── stories/
    │   │       └── ...
    │   └── NN_integration-e2e/              # new final epic for the appended scope
    │       └── ...
    └── ROADMAP.md                           # updated with new epics
```
