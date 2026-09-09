# Claude Design Brief — Template & Authoring Rules

> Read by `spec` Phase 4.5 only. Produces `design-brief.md` inside the spec folder: a
> self-contained brief the user pastes into [claude.ai/design](https://claude.ai/design)
> to build the project's design system.

The brief has two jobs. The obvious one is describing the product so the design comes out
right. The second is **making the resulting design system machine-readable for ck-code**:
a system whose foundations are CSS custom properties and whose groups carry the names
[`design-system.md`](../../../references/design-system.md) already looks for extracts
cleanly on the high-confidence path, with no `⚠️` low-confidence tokens and no gaps for
`build` to invent. A brief that skips § 6 produces a design system that technically works
and costs the user a manual token-confirmation pass on every sync.

## Authoring rules

- **Derive every word from the spec.** The brief restates what `pre-spec.md` established —
  product, users, surfaces, tone. It never introduces a product decision the spec has not
  made. A dimension the spec left open is written as an open question in § 7, not filled in.
- **Plain language, same as the spec.** No file paths, no framework names, no ck-code
  vocabulary. The reader is Claude Design, and after it the user.
- **Same language as the spec** (`.metadata.json#language`), except § 6, which stays in
  English — it names literal group labels and CSS property syntax that must not be translated.
- **Name the screens the spec actually implies**, not a generic app skeleton. Three real
  screens beat twelve invented ones.
- **Never mention `/ck-code:*` inside §§ 1–5.** § 6 is technical instruction for the design
  tool and § 8 is the hand-back line — those are the only places tooling appears.

## Template

Write the file exactly in this shape. Omit § 5 when the spec describes no data-heavy
surface; omit § 7 when nothing is open. Everything else is always present.

---

```markdown
# Design brief — <Product name>

<One paragraph: what the product is and who uses it, lifted from the spec's Context
section. Two or three sentences.>

## 1. Product & audience

- **Product** — <name and one-line description>
- **Primary users** — <who, from the spec's target-user material>
- **Platform** — <web / mobile web / iOS / Android / desktop, per the spec>
- **Tone** — <3-5 adjectives that describe the intended feel, e.g. "calm, precise,
  data-dense, unfussy">

## 2. Brand direction

<A short paragraph. If the spec or project already states brand colors, typefaces, or a
reference product, say so plainly and mark them as fixed. If it does not, say the
direction is open and give the constraints that exist — contrast requirements,
dark mode, an existing logo — rather than inventing a palette.>

| Element | Direction |
|---|---|
| Color | <fixed values, or the intent: "one calm accent, generous neutral range"> |
| Typography | <fixed family, or the intent: "one sans for UI, tabular figures needed"> |
| Density | <compact / comfortable / spacious, with the reason> |
| Motion | <how much, and where it is forbidden> |
| Dark mode | <required / not required> |

## 3. Screens

One row per screen the spec implies. Purpose is what the user is doing there.

| Screen | Purpose | Key elements |
|---|---|---|
| <name> | <what the user accomplishes> | <the 3-6 things on it> |

## 4. Components needed

The component inventory, grouped. Each line names the component and every state or
variant the spec's behaviors actually require.

- **Actions** — <buttons: variants, sizes, states including disabled and loading>
- **Forms** — <inputs, selects, toggles; include error and helper-text states>
- **Navigation** — <nav bars, tabs, breadcrumbs>
- **Feedback** — <toasts, banners, empty states, loading states, error states>
- **Data display** — <tables, lists, cards, badges, charts>
- **Overlays** — <modals, drawers, tooltips, menus>

## 5. Data & density notes

<Only when the product shows real data. What the heaviest screen holds, roughly how many
rows or items, and whether the design must survive long strings, missing values, or
right-to-left text.>

## 6. Design-system output requirements

Please build this as a **design system project** and follow these output conventions —
they let the project's codebase consume the system directly:

1. **Foundations as CSS custom properties.** Every foundation value is declared as a
   custom property on `:root` — `--color-…`, `--font-…`, `--space-…`, `--radius-…`,
   `--shadow-…`. Components reference those properties; no literal color, size, radius,
   or shadow values inside a component's CSS.
2. **Foundation cards use these exact group labels**, one card per group:
   `Type`, `Colors`, `Spacing`, `Radii`, `Shadows`, `Brand`. A group with nothing in it is
   omitted rather than renamed.
3. **One card per component**, showing every variant and state side by side in that single
   card, grouped under a component label such as `Actions`, `Forms`, `Navigation`,
   `Feedback`, `Data display`, or `Overlays`.
4. **Self-contained cards.** Each card's HTML carries its own styles and depends on no
   external stylesheet, script, or font CDN. Web-safe stacks or embedded fonts only.
5. **Semantic, stable class names** on every element — the component's markup and class
   names are copied verbatim into the codebase, so they are part of the deliverable, not
   scaffolding.
6. **Both themes** when § 2 requires dark mode: define the dark values as overrides of the
   same custom properties, never as a separate parallel set of names.

## 7. Open questions

<Only when the spec left something genuinely undecided that affects the design. One
bullet per question, phrased so the designer can answer it inline.>

## 8. When the design system is ready

Copy its URL from the address bar and hand it back in Claude Code:

    /ck-code:design ds <paste the URL here>

That links the design system to this project, caches its tokens and component sources into
the repository, and makes every later UI implementation build against it.
```

---

## After writing the brief

`spec` Phase 4.5 owns the rest: stamp `designSystem` in `.metadata.json`
(`status: "awaiting-link"`, `briefPath`), and print the hand-off — open
[claude.ai/design](https://claude.ai/design), paste the brief, then return with
`/ck-code:design ds <url>`. Nothing else is written, and no `DesignSync` call is made:
the whole point of the brief is that the user leaves and comes back, possibly days later
in a different session.
