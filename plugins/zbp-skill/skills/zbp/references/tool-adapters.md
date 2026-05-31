# Loading ZBP into Different AI Coding Tools

ZBP is a Claude Code plugin but the skill content (patterns, references, scripts)
works with any AI coding assistant. This guide shows how to load it into each tool.

## Tool Compatibility Matrix

| Tool | Method | Effort | Token efficiency |
|------|--------|--------|-----------------|
| Claude Code | Native plugin (`/plugin install`) | Zero | Best (progressive disclosure) |
| Claude API / Console | Copy `zbp-system-prompt.txt` as system prompt | Low | Good (full context) |
| Codex (OpenAI) | Paste into Custom Instructions or upload as file | Low | Good |
| Kimi (Moonshot) | Upload SKILL.md as knowledge file | Low | Good |
| Copilot (GitHub) | `.github/copilot-instructions.md` | Low | Good |
| Cursor | `.cursorrules` or Rules for AI | Low | Good |
| Windsurf | `.windsurfrules` | Low | Good |
| Zed AI | Context files or assistant config | Low | Good |
| Terminal AI (aichat, tgpt) | Pipe prompt file as context | Med | Med |

---

## Claude Code (Native)

```bash
# Install as plugin
/plugin install zbp-skill@chy3xyz

# Or add marketplace
/plugin marketplace add chy3xyz/zbp-skill
```

The skill auto-loads when editing `.zig` files. Progressive disclosure: only
the SKILL.md body loads (~40KB); reference files load on demand.

---

## Codex (OpenAI)

Codex doesn't have a plugin system. Use one of:

### Option A: Custom Instructions (persistent, recommended)
1. Go to Settings → Custom Instructions
2. Paste the content from `zbp-system-prompt.txt` (concise ~5KB version)
3. Prefix: "When writing or reviewing Zig code, follow these patterns:"

### Option B: Upload as Knowledge File (per-session)
1. Start a new chat
2. Upload `SKILL.md` as a knowledge file
3. Say: "Read this Zig best practice document. Apply these patterns to all Zig code."

### Option C: MCP Server (if using Claude Code with Codex backend)
Not applicable — Codex doesn't support MCP skill loading.

---

## Kimi (Moonshot)

Kimi supports file uploads and web content:

### Method 1: Upload SKILL.md
1. Upload `SKILL.md` as a file attachment
2. Say: "Remember this Zig best practice document. Apply these patterns to all Zig code going forward."

### Method 2: Knowledge Base (if available)
1. If Kimi supports a persistent knowledge base, upload all `.md` files
2. Reference: "Write Zig code following my best practices knowledge base"

### Method 3: URL reference
If the repo is public:
1. Say: "Write code following the Zig best practices from https://github.com/chy3xyz/zbp-skill"
2. Kimi will fetch and reference the repository content

---

## GitHub Copilot

### Workspace Instructions (recommended)
Create `.github/copilot-instructions.md` in your Zig project:

```markdown
## Zig Coding Standards

Follow the Zig Best Practices from zbp-skill:

1. Every allocation MUST have defer/errdefer on the VERY NEXT LINE.
2. Every try after allocation MUST have prior errdefer.
3. Use initCapacity (not .init) for ArrayList in Zig 0.17.
4. Use std.testing.allocator in all test blocks.
5. Deinit MUST reverse init order and end with self.* = undefined.

Full reference: https://github.com/chy3xyz/zbp-skill
```

### Chat context
1. Open Copilot Chat
2. Paste key patterns as context: "When writing Zig, follow these rules: [paste top 20 lines of SKILL.md]"

---

## Cursor

### Rules for AI
Create `.cursorrules` in your Zig project root:

```markdown
# Zig Best Practices (zbp-skill)
- errdefer after every try-init
- defer on allocation line
- ArenaAllocator for temporary work
- std.testing.allocator in tests
- Narrow error sets, avoid anyerror
- Prefer AssumeCapacity for hot paths
- Source: https://github.com/chy3xyz/zbp-skill
```

Or use Cursor's Settings → Rules for AI → paste `zbp-system-prompt.txt`.

---

## Windsurf

Create `.windsurfrules` in project root with the same content as Cursor rules above.

Or configure via:
1. Settings → AI → Custom Rules
2. Paste condensed rules from `zbp-system-prompt.txt`

---

## Zed AI

### Assistant Configuration
In `.zed/assistant.json` or `~/.config/zed/assistant.json`:

```json
{
  "context_servers": [],
  "default_model": {
    "provider": "anthropic",
    "name": "claude-sonnet-4-6"
  },
  "system_prompt_extra": "When writing Zig: every alloc must have defer/errdefer on next line; use initCapacity not .init; use std.testing.allocator in tests; deinit reverses init order; prefer ArenaAllocator for temporary allocations."
}
```

---

## Generic / Terminal AI Tools (aichat, tgpt, llm)

### Pipe as context
```bash
# Load the skill context before your query
cat zbp-system-prompt.txt | aichat "Review this Zig code for memory leaks: $(cat src/main.zig)"

# Or use a shell alias
alias zig-ai='aichat --system-file ~/zbp-skill/zbp-system-prompt.txt'
```

### Shell integration
Add to `~/.bashrc` or `~/.zshrc`:
```bash
zig_review() {
    aichat --system-file ~/zbp-skill/zbp-system-prompt.txt "Review for leaks and anti-patterns: $(cat "$1")"
}
# Usage: zig_review src/main.zig
```

---

## Token Efficiency by Tool

Tool-specific optimization tips:

| Tool | Optimization |
|------|-------------|
| Claude Code | Progressive disclosure built-in — no action needed |
| Claude API | Send SKILL.md as system prompt; cache with `cache_control` |
| Codex | Use Custom Instructions (persistent, not per-message) |
| Kimi | Upload once, reference by name in follow-ups |
| Copilot | `.github/copilot-instructions.md` is auto-loaded |
| Cursor | `.cursorrules` is auto-loaded per-project |
| All tools | The `zbp-system-prompt.txt` is the token-optimized core |

---

## The Universal Core

Regardless of tool, these 5 rules prevent 80% of Zig memory leaks:

1. `defer` or `errdefer` on the line after EVERY allocation
2. `errdefer` before EVERY `try` that follows an allocation
3. `deinit` reverses `init` order; ends with `self.* = undefined`
4. `std.testing.allocator` in ALL tests
5. Arena allocator for request/scope-level temporary work
