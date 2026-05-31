# zbp-skill

Zig Best Practice skill for AI coding tools. 11 sections of production-derived
patterns, cross-referenced with Zig 0.17 dev docs.

## Quick Install (Claude Code)

```bash
curl -fsSL https://raw.githubusercontent.com/chy3xyz/zbp-skill/main/install.sh | bash
```

Then `/reload-plugins`. The `zbp` skill auto-loads when editing `.zig` files.

## Other AI Tools

| Tool | How to use |
|------|-----------|
| **Codex (OpenAI)** | Paste `zbp-system-prompt.txt` into Custom Instructions |
| **Kimi (Moonshot)** | Upload `SKILL.md` as knowledge file |
| **GitHub Copilot** | Copy rules into `.github/copilot-instructions.md` |
| **Cursor / Windsurf** | Copy rules into `.cursorrules` / `.windsurfrules` |
| **Any AI tool** | Use `zbp-system-prompt.txt` as system prompt |

Details: `plugins/zbp-skill/skills/zbp/references/tool-adapters.md`

## Patterns (11 Sections)

1. **Memory Safety** — errdefer chains, arena, poisoning, allocator selection
2. **Infallible Runtime** — AssumeCapacity across all container types
3. **Error Handling** — narrow error sets, exhaustive switches, error composition
4. **Comptime & Generics** — anytype, type functions, @fieldParentPtr, @Type
5. **Memory Layout** — extern/packed structs, SIMD, cache alignment
6. **Naming & Style** — official + community conventions
7. **Code Organization** — intrusive structures, object pools, ref counting
8. **Thread Safety** — threadlocal, lock-free MPSC queue, atomics
9. **Smart Pointers** — Cow, RefCount mixin
10. **C Interop** — export fn, callconv, allocator bridging
11. **Official 0.17** — sentinel types, for/while+else, @branchHint, non-exhaustive enums

## Sources

- [TigerBeetle](https://github.com/tigerbeetle/tigerbeetle) · [Bun](https://github.com/oven-sh/bun) · [libxev](https://github.com/mitchellh/libxev) · [Ghostty](https://github.com/ghostty-org/ghostty)
- [Zig 0.17 Language Reference](https://ziglang.org/documentation/master/)

## License

MIT
