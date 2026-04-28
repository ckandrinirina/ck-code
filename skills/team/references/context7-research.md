# Context7 Research Instructions

Detailed guidance for Phase 1.6 of `SKILL.md`: how to research current best
practices for every detected technology before generating any expert or guide
skill. **This research is mandatory — never skip it.**

---

## 1. Identify All Technologies to Research

From `tech-stack.md` and the codebase scan, build a list of every language,
framework, library, and tool. Example:

```
Technologies detected:
- C++ (JUCE 8.x)
- Rust (Axum 0.7, Tokio 1.x, tonic 0.11, sqlx 0.7)
- TypeScript/React Native (Expo SDK 50+, Zustand)
- Protobuf / gRPC
- CMake 3.22+
- SQLite
```

## 2. Research Each Technology via context7

For EACH technology in the list, look up the library and fetch its docs.
context7 ships in **two equivalent forms** — pick whichever is available, in
this order:

### Resolution order

1. **MCP tools** (preferred when available):
   - `mcp__context7__resolve-library-id` (or `mcp__plugin_context7_context7__resolve-library-id`)
   - `mcp__context7__query-docs` (or `mcp__plugin_context7_context7__query-docs`)
   Quick check: if the available tool list contains a `mcp__*context7*` entry,
   use these.

2. **`ctx7` CLI** (fallback when MCP is unavailable — works in any shell-capable
   environment, including parallel sub-agents that don't inherit MCP):

   ```bash
   # Resolve library ID:
   npx -y @upstash/context7 library "<technology name>" "<query>"
   # Or, if installed globally:
   ctx7 library "<technology name>" "<query>"

   # Fetch docs:
   ctx7 docs <library-id> "<query>"
   ```

   First-run setup (one-time per machine): `npx -y @upstash/context7 setup`
   handles OAuth/API-key auth. Subsequent calls are non-interactive.
   Note: confirm the package name with `npm search context7` if `@upstash/context7`
   does not resolve — Upstash has shipped the CLI under a few names while it
   stabilises.

3. **WebSearch** (last-resort fallback if neither MCP nor CLI is reachable):
   see section 3 below.

### What to fetch (regardless of form)

For each library, request:
- Current best practices and coding conventions
- Recommended project structure
- Common patterns and anti-patterns
- Performance best practices
- Error handling patterns
- Testing approaches
- Latest version changes or migration notes

## 3. Supplement with WebSearch When Needed

If neither context7 form has sufficient documentation for a technology, use WebSearch:

- "[Technology] best practices [year]"
- "[Technology] coding standards"
- "[Technology] project structure conventions"
- "[Technology] common mistakes to avoid"

## 4. Build Best Practices Knowledge Base

Compile the research into a structured knowledge base that will be injected
into both expert skills AND language guide skills:

```markdown
## Best Practices Knowledge (auto-researched)

### [Language/Framework 1]
**Version:** [current version in project]
**Key Conventions:**
- [Convention 1]
- [Convention 2]
**Project Structure:** [recommended layout]
**Patterns:** [important patterns]
**Anti-patterns:** [things to avoid]
**Testing:** [recommended testing approach]
**Performance:** [key performance practices]

### [Language/Framework 2]
...
```

This knowledge base serves two purposes:

1. Injected into expert skills to make their advice current and accurate.
2. Used directly as content for language/framework guide skills.
