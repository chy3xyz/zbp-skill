# zbp-skill

ZBP (Zig Best Practice) — Claude Code skill plugin. Comprehensive Zig patterns
cross-referenced with the [Zig 0.17 (dev) Language Reference](https://ziglang.org/documentation/master/).

## Structure

```
plugins/zbp-skill/skills/zbp/
├── SKILL.md                              # Core skill: 11 sections of patterns
├── references/
│   ├── zig-017-official-docs.md          # Pattern-to-docs cross-reference
│   ├── style-guide-comparison.md         # Official vs TigerBeetle style
│   ├── error-handling.md                 # Full error semantics from 0.17
│   ├── comptime-reference.md             # Comptime deep-dive from 0.17
│   ├── memory-management.md              # Allocators, lifetime, struct layout
│   └── leak-prevention.md                # Systematic leak prevention for AI code
├── examples/
│   └── comprehensive_resource.zig       # Full init/deinit/pool/C-interop example
└── scripts/
    └── check_build.zig                  # Scan project for common anti-patterns
```

## Patterns Covered (11 Sections)

1. **Memory Safety** — errdefer chains, arena allocators, poisoning, allocator selection guide
2. **Infallible Runtime Operations** — AssumeCapacity across all container types
3. **Error Handling** — narrow error sets, exhaustive switches, error composition
4. **Comptime & Generics** — anytype, type functions, @fieldParentPtr, @Type, @embedFile
5. **Memory Layout & Copy Safety** — extern structs, SIMD, mmap, cache alignment, packed structs
6. **Naming & Style** — official (camelCase fn, TitleCase types) + community (snake_case fn)
7. **Code Organization** — imports, intrusive data structures, object pools, ref counting
8. **Thread Safety & Concurrency** — threadlocal, lock-free MPSC queue, atomics
9. **Smart Pointer Patterns** — copy-on-write, RefCount mixin
10. **C Interop** — export fn, callconv, allocator bridging, pointer smuggling
11. **Official 0.17 Patterns** — anytype, sentinel-terminated types, for/while+else, inline loops, @branchHint, @constCast/@volatileCast, non-exhaustive enums, doc comments

## Sources & References

- [TigerBeetle](https://github.com/tigerbeetle/tigerbeetle) — financial transactions database
- [Bun](https://github.com/oven-sh/bun) — JavaScript runtime
- [libxev](https://github.com/mitchellh/libxev) — cross-platform event loop
- [Ghostty](https://github.com/ghostty-org/ghostty) — terminal emulator
- [Zig 0.17 Language Reference](https://ziglang.org/documentation/master/) — official docs

## Install

```
/plugin install zbp-skill@<your-marketplace>
```

Or add this repo as a marketplace:

```
/plugin marketplace add <owner>/zbp-skill
```

## License

MIT
