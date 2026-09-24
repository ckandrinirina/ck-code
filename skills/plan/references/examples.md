# Plan Skill — Worked Examples

Folder-structure examples per mode. `STORIES_INDEX.md` (per plan) and
`tasks/EPICS_INDEX.md` (top-level) are shown as **generated** — `ck-index` produces them
from frontmatter in Phase 5.7; they are gitignored, never hand-written and never committed.

---

## New Project Mode — tasks/ folder layout

```
tasks/
├── VERSION.md                              # layout: v7 stamp (written by the version gate)
├── .gitignore                              # keeps the two views out of git (ck-index)
├── EPICS_INDEX.md                          # GENERATED, gitignored (top-level, all plans)
└── YYYY-MM-DD_<project-slug>/
    ├── OVERVIEW.md                          # plan record (frontmatter) + prose
    ├── STORIES_INDEX.md                     # GENERATED, gitignored (this plan)
    ├── epics/
    │   ├── 01_<epic-slug>/
    │   │   ├── EPIC.md                       # frontmatter (no integration:), no ## Stories table
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

## Increment Mode — new plan folder layout

A new dated folder named for the work — no prefix; the date keeps it distinct from earlier
plans. It gets its own `OVERVIEW.md` record and its own integration level. Epic numbering
does **not** restart here — it continues from the project-wide maximum (SKILL.md 3.1), so
the numbers below are illustrative of a project whose prior plans ended at epic `04`.

```
tasks/
├── EPICS_INDEX.md                          # GENERATED — new epic rows appear
└── YYYY-MM-DD_<slug>/
    ├── OVERVIEW.md                          # this plan's record + prose
    ├── STORIES_INDEX.md                     # GENERATED (this plan)
    ├── epics/
    │   ├── 05_<epic-slug>/                  # continues the project, does not restart
    │   │   ├── EPIC.md
    │   │   └── stories/
    │   │       └── ...
    │   └── NN_integration-e2e/
    │       └── ...
    └── ROADMAP.md
```

---

## Increment Mode — Continue Existing Plan layout

Files are added inside the SAME existing dated folder. Epic numbering continues from the
**project-wide** maximum — which may sit in a *different, newer* plan folder than the one
being extended, so never read it off this folder's own last epic. `STORIES_INDEX.md` and
`EPICS_INDEX.md` are regenerated; `OVERVIEW.md` (record and integration level) is left
unchanged.

```
tasks/
├── EPICS_INDEX.md                          # GENERATED — regenerated across all plans
└── YYYY-MM-DD_<existing-slug>/             # same folder
    ├── OVERVIEW.md                          # unchanged
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
