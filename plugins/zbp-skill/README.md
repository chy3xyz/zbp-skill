# zbp-skill

ZBP (Zig Best Practice) — Claude Code skill plugin with comprehensive Zig patterns.
Cross-referenced with [Zig 0.17 (dev) Language Reference](https://ziglang.org/documentation/master/).

## About

Installs the `zbp` skill, loading when writing/modifying/reviewing Zig code.
Production-derived patterns for:

- Memory safety (errdefer chains, arena allocators, poisoning)
- Infallible runtime operations (AssumeCapacity)
- Error handling (narrow error sets, exhaustive switches)
- Comptime & generics (type functions, @fieldParentPtr, @Type, anytype)
- Memory layout & copy safety (extern/packed structs, SIMD)
- Naming & style (official + community conventions)
- Thread safety & concurrency (atomics, lock-free queues)
- C interop (export fn, callconv, allocator bridging)
- Official 0.17 patterns (sentinel-terminated, for/while+else, @branchHint)

## Sources

Patterns from [TigerBeetle](https://github.com/tigerbeetle/tigerbeetle),
[Bun](https://github.com/oven-sh/bun),
[libxev](https://github.com/mitchellh/libxev),
[Ghostty](https://github.com/ghostty-org/ghostty), and the
[Zig 0.17 Language Reference](https://ziglang.org/documentation/master/).

## License

MIT
