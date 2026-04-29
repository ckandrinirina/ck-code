# Pre-Spec Templates & Q&A Banks

> Verbatim structure for the descriptive feature pre-spec output, plus the
> question banks the skill draws from. Translate section titles to the
> chosen output language. Keep section anchors ASCII.

---

## Question bank (Phase C3 — Conversational refinement)

Adapt to the feature type. Skip dimensions already clear from the user's
description. Ask 2-3 per round, max 3-4 rounds.

1. **Scope & user benefit**
   - "What problem does this solve, in the user's own words?"
   - "What would a user say has changed after this ships?"

2. **In/out of scope (v1 cut)**
   - "What's NOT in this version — even if it's tempting?"
   - "Are there modes / segments / surfaces explicitly excluded?"

3. **Visibility & UX surface**
   - "What does the user see (text, icons, animations, indicators)?"
   - "Are there changes the user should NOT see (silent / behind-the-scenes)?"

4. **Behavior boundaries**
   - "What's the trigger — what makes the feature activate?"
   - "What stops or unwinds it?"

5. **Configurability**
   - "What knobs do you want operations to tune without redeploy?"
   - "What's the kill-switch / disable path?"

6. **Edge cases & failure modes**
   - "What happens when the dependency is unavailable?"
   - "What's the worst-case behavior, and what guard catches it?"

7. **Success criteria**
   - "How would you know in 2 weeks that this works?"
   - "What metrics would you watch?"

After each round, summarize what was learned in 1-2 sentences and ask if
another round or proceed to writing.

---

## Forgotten-details checklist (Phase C2)

Tailor to the actual feature — don't dump irrelevant suggestions.

**User-facing features**
- accessibility (keyboard nav, screen reader, contrast)
- mobile-first behavior, touch target sizing
- internationalization (i18n keys, RTL languages)
- kill-switch / feature flag
- gradual rollout / A/B testing
- error states, empty states, loading states

**Backend / data features**
- rate limiting (per user, per IP, per endpoint)
- retention policies (TTLs, GDPR / DSR)
- audit trail
- observability / metrics / alerts
- idempotency (retries, duplicate requests)
- backwards compatibility / schema migration path

**Real-time / multiplayer**
- anti-detection (for hidden behaviors)
- anti-abuse (caps, throttles)
- eviction / kick rules
- reconnection
- race conditions, fairness invariants
- ordering guarantees

**Economy / payments**
- funding source (where money/points come from)
- refund policy
- daily / monthly caps
- fraud detection
- T&C / consumer-protection exposure

**AI / automation features**
- human override path
- transparency (what's logged, who can see it)
- audit log
- CPU / cost budget per request
- model fallback / failure mode

---

# Pre-Spec Section Templates

---

## Title

Format: `<Project name> — Specification: <feature name> (<scope qualifier>)`

Examples:

- `LUDOKA — Spécification : système de bots intelligents (mode Free uniquement)`
- `Acme Shop — Specification: same-day delivery (US East beta)`

Keep under ~80 characters. The title is also the GitHub issue title.

---

## Section 1 — Contexte / Context

One short paragraph stating:

1. What this document is (a feature spec, posted for review and comments).
2. Where it stands (early draft, awaiting input).
3. Where it goes next (open invitation to comment, no named approvers).

> **A scope-qualifier blockquote** if the feature has hard boundaries:
> e.g. "Strict scope: free games only. Paid mode is unaffected."

---

## Section 2 — Objectif / Objective

A short lead sentence (one line), then a **numbered list** of 4-7 high-level
objectives. Each objective is one sentence in plain language describing what
the system does — not how.

Each item should be readable on its own. Avoid nesting bullets under a
numbered objective unless absolutely necessary.

If the feature has a clear out-of-scope cut, add an **"Out of scope (v1)"**
sub-heading with a short bulleted list.

---

## Section 3 — Validated Product Decisions / Décisions produit déjà validées

A 2-column table summarizing answers the user has already locked in. Format:

| Question | Validated answer |
|---|---|
| ... | ... |

This section captures Q&A outputs from Phase 3 of the skill. Skip the section
entirely if no decisions were made (rare).

---

## Section 4 — Product Rules / Règles produit définitives

A 2-column or 3-column table of authoritative rules. Each rule is a single
short sentence with concrete defaults where applicable.

Two acceptable formats:

**Format A (2 columns):**

| Rule | Value |
|---|---|
| ... | ... |

**Format B (3 columns) — when justification matters:**

| Rule | Value | Reason |
|---|---|---|

Use Format B sparingly — only for rules where the WHY is critical
(e.g. brand promises, hard constraints from existing spec).

---

## Section 5 — Detailed Behaviors / Comportements détaillés

The narrative core of the spec. Use sub-sections for distinct behaviors.

For each sub-behavior:

- A descriptive title (`### <name>`).
- 1-2 sentences of context.
- Step-by-step prose OR a short numbered/bulleted sequence.
- Concrete defaults inline (`"about 60 seconds"`, `"every ~8 seconds"`).
- An illustrative example if it clarifies — phrased at human time
  granularity, not code:

  ```
  Example sequence (illustrative — every match is different):

  0 s      : lobby created by a human
  0 → 10 s : no bot — give time for other humans
  ~10 s    : a first bot joins (2 players)
  ~34 s    : a second bot joins (3 players)
  ~57 s    : a last bot joins in the final 1-3 seconds (4 players)
  60 s     : start countdown
  ```

  These are NOT code blocks describing schemas; they describe a
  human-observable timeline. Acceptable.

If a behavior has anti-detection / anti-abuse / fairness aspects, give them
their own sub-section with a "Why X and not Y?" paragraph.

---

## Section 6 — User-Facing View / Côté utilisateur

(Include only if the feature has user-visible behavior worth calling out.)

Bullet list of what the user sees, with emphasis on what's deliberately
hidden from them. Examples:

- "No icon, no label, no tooltip indicates that ..."
- "The pseudo of <X> appears in the leaderboard exactly like any other player."
- "Points are awarded according to the existing rules — nothing changes here."

---

## Section 7 — Backend / Behind-the-Scenes / Côté backend

(Include only if there's meaningful backend tracking the user should NOT see
but stakeholders should understand.)

Plain-language description of what the platform records and forwards
internally:

- "Every match including <feature> is logged with <which fields> and forwarded
  to the platform's audit log."
- "The information is filtered out of every response sent to the browser."
- "Coordination with the <X> team is needed to accept the new field."

---

## Section 8 — Minimal Technical Impact / Impact technique minimal

(Include only when the user explicitly asked for low-cost / low-impact
implementation.)

Two short subsections at most:

- **No persistent connections / no extra background workload** — describe in
  plain language why the feature is cheap.
- **CPU / memory cost estimate** — give a one-line ballpark
  ("about <N> ms/s of CPU added per <M> concurrent ...").

Avoid implementation primitives (timer keys, locks, polling intervals).

---

## Section 9 — Configurable Knobs / Configurations clés

Bullet list of operational knobs, each described in plain language:

- **<Knob name>** — what it does, with default value.
- **<Knob name>** — ...

Example:

- **Global kill-switch** — instantly disables the entire feature in case of
  incident.
- **Wait window before fill** — how long to wait for real users before adding
  bots (default 60 s).
- **Eviction spacing** — when a real user arrives, one bot leaves every
  N seconds (default 8 s).

Do NOT format as `BOT_FILL_DELAY_SECONDS=60` env-var-style. Stakeholders
should be able to read this without knowing about environment variables.

---

## Section 10 — Open Considerations / Points à clarifier

(Include only if Phase 3 Q&A surfaced ambiguities the user explicitly chose
to defer.)

Short bulleted list of topics that remain to be decided, phrased as questions
or unknowns. NO "to be validated by X" — leave the section open for any
stakeholder to comment on.

If everything is locked, omit this section entirely. Do not pad.

---

## Section 11 — Next Step / Prochaine étape

Always present, always the same shape. One short paragraph:

> Any remarks, modifications, or questions can be commented directly in this
> issue. Once the content is aligned, implementation can start with this
> specification as the entry point.

Translate to the chosen language. NO mention of internal tooling, slash
commands, or specific approver names.

---

## Localized section titles

Apply consistent translations across the whole document.

| English | French | Spanish |
|---|---|---|
| Context | Contexte | Contexto |
| Objective | Objectif | Objetivo |
| Out of scope | Hors-périmètre | Fuera del alcance |
| Validated product decisions | Décisions produit déjà validées | Decisiones de producto ya validadas |
| Product rules | Règles produit définitives | Reglas de producto definitivas |
| Detailed behaviors | Comportements détaillés | Comportamientos detallados |
| User-facing view | Côté utilisateur | Vista del usuario |
| Behind the scenes | Côté backend | Detrás de escena |
| Minimal technical impact | Impact technique minimal | Impacto técnico mínimo |
| Configurable knobs | Configurations clés | Configuraciones clave |
| Open considerations | Points à clarifier | Puntos a aclarar |
| Next step | Prochaine étape | Próximo paso |

For other languages, ask the user once for translations of these titles
before generating the document.

---

## Things to avoid in the OUTPUT (recap)

- ❌ Code blocks describing types, schemas, or env vars
- ❌ File paths inside the repo (`apps/backend/...`)
- ❌ Internal tool names (slash commands, plugin names)
- ❌ "Validated by CTO / approved by PO / etc." lines
- ❌ Architectural primitives (Redis keys, locks, polling)
- ❌ Walls of imperative engineering directives ("MUST X", "SHALL Y")

## Things to include (recap)

- ✅ Numbered objectives in plain language
- ✅ Tables for rules and decisions
- ✅ Narrative prose for behaviors with concrete defaults inline
- ✅ Illustrative timelines at human granularity
- ✅ Plain-language description of operational knobs
- ✅ Open invitation for stakeholder comments at the end
