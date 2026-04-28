# Plan Skill — Worked Examples

Concrete folder-structure examples for each mode. Use these as visual references when generating the planning artifacts.

---

## New Project Mode — tasks/ folder layout

```
tasks/
└── YYYY-MM-DD_<project-slug>/
    ├── PROJECT_OVERVIEW.md
    ├── epics/
    │   ├── 01_<epic-slug>/
    │   │   ├── EPIC.md
    │   │   └── stories/
    │   │       ├── 01_<story-slug>.md
    │   │       ├── 02_<story-slug>.md
    │   │       └── ...
    │   ├── 02_<epic-slug>/
    │   │   ├── EPIC.md
    │   │   └── stories/
    │   │       └── ...
    │   └── ...
    └── ROADMAP.md
```

---

## Feature Mode — Add Feature folder layout

A feature-specific dated folder, prefixed `feature-` so it does not collide with the main project plan. Numbering restarts at 01 inside this folder.

```
tasks/
└── YYYY-MM-DD_feature-<feature-slug>/
    ├── FEATURE_OVERVIEW.md          # Instead of PROJECT_OVERVIEW.md
    ├── epics/
    │   ├── 01_<epic-slug>/
    │   │   ├── EPIC.md
    │   │   └── stories/
    │   │       └── ...
    │   └── ...
    └── ROADMAP.md
```

---

## Feature Mode — Continue Existing Plan layout

Files are added inside the SAME existing dated folder. Epic numbering continues from the last existing epic (e.g., last existing was 04, new ones start at 05). `ROADMAP.md` is updated; `PROJECT_OVERVIEW.md` is left unchanged.

```
tasks/
└── YYYY-MM-DD_<existing-project-slug>/     # Same folder
    ├── PROJECT_OVERVIEW.md                  # Unchanged
    ├── epics/
    │   ├── ... (existing epics unchanged)
    │   ├── 05_<new-epic-slug>/              # Continues numbering
    │   │   ├── EPIC.md
    │   │   └── stories/
    │   │       └── ...
    │   └── ...
    └── ROADMAP.md                           # Updated with new epics
```
