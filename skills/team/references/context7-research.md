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

## 2. Research Each Technology via context7 MCP

For EACH technology in the list, use the context7 MCP tools:

1. **Resolve the library ID:**
   Use `mcp__context7__resolve-library-id` (or
   `mcp__plugin_context7_context7__resolve-library-id`) to find the correct
   library identifier for each technology.

2. **Fetch current documentation:**
   Use `mcp__context7__query-docs` (or
   `mcp__plugin_context7_context7__query-docs`) to fetch:
   - Current best practices and coding conventions
   - Recommended project structure
   - Common patterns and anti-patterns
   - Performance best practices
   - Error handling patterns
   - Testing approaches
   - Latest version changes or migration notes

## 3. Supplement with WebSearch When Needed

If context7 doesn't have sufficient documentation for a technology, use WebSearch:

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
