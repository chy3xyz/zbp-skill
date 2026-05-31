# Zig 0.17 (dev) Official Documentation Cross-Reference

Each pattern in the skill maps to sections in the official
[Zig Language Reference](https://ziglang.org/documentation/master/).

## Memory Safety Patterns → Official Docs

| Skill Pattern | Official Docs Section |
|---|---|
| `errdefer` chains | [Errors > Error Union Type > errdefer](https://ziglang.org/documentation/master/#errdefer) |
| `defer` / `defer if` | [defer](https://ziglang.org/documentation/master/#defer) |
| ArenaAllocator | [Memory > Choosing an Allocator](https://ziglang.org/documentation/master/#Memory) |
| Allocator as explicit parameter | [Memory > Lifetime and Ownership](https://ziglang.org/documentation/master/#Lifetime-and-Ownership) |
| Testing allocator for leak detection | [Zig Test > Report Memory Leaks](https://ziglang.org/documentation/master/#Report-Memory-Leaks) |
| Heap allocation failure handling | [Memory > Heap Allocation Failure](https://ziglang.org/documentation/master/#Heap-Allocation-Failure) |
| Two-phase create-then-init | [struct > Default Field Values](https://ziglang.org/documentation/master/#struct) |
| Debug/ReleaseSafe `0xaa` poison | [Build Mode > Debug](https://ziglang.org/documentation/master/#Build-Mode) |

## Error Handling → Official Docs

| Skill Pattern | Official Docs Section |
|---|---|
| Narrow error sets | [Errors > Error Set Type](https://ziglang.org/documentation/master/#Error-Set-Type) |
| `catch \|err\| switch` | [Errors > catch](https://ziglang.org/documentation/master/#catch) |
| `try` operator | [Errors > try](https://ziglang.org/documentation/master/#try) |
| Error set merging (`\|\|`) | [Errors > Merging Error Sets](https://ziglang.org/documentation/master/#Merging-Error-Sets) |
| `error.SkipZigTest` | [Zig Test > Skip Tests](https://ziglang.org/documentation/master/#Skip-Tests) |
| Error return traces | [Errors > Error Return Traces](https://ziglang.org/documentation/master/#Error-Return-Traces) |
| `@errorName` | [Builtin Functions > @errorName](https://ziglang.org/documentation/master/#@errorName) |

## Comptime & Generics → Official Docs

| Skill Pattern | Official Docs Section |
|---|---|
| Type functions (`fn(comptime T: type) type`) | [comptime > Generic Data Structures](https://ziglang.org/documentation/master/#comptime) |
| `comptime` block | [comptime](https://ziglang.org/documentation/master/#comptime) |
| `@Type` dynamic construction | [Builtin Functions > @Type](https://ziglang.org/documentation/master/#@Type) |
| `@typeInfo` introspection | [Builtin Functions > @typeInfo](https://ziglang.org/documentation/master/#@typeInfo) |
| `@hasDecl` / `@hasField` | [Builtin Functions > @hasDecl](https://ziglang.org/documentation/master/#@hasDecl) |
| `@fieldParentPtr` | [Builtin Functions > @fieldParentPtr](https://ziglang.org/documentation/master/#@fieldParentPtr) |
| `@embedFile` | [Builtin Functions > @embedFile](https://ziglang.org/documentation/master/#@embedFile) |
| `@setEvalBranchQuota` | [Builtin Functions > @setEvalBranchQuota](https://ziglang.org/documentation/master/#@setEvalBranchQuota) |
| `inline for` / `inline while` | [for > inline for](https://ziglang.org/documentation/master/#for) |
| Compile-time platform selection | [Compile Variables](https://ziglang.org/documentation/master/#Compile-Variables) |
| `void` as type-level feature flag | [Zero Bit Types > void](https://ziglang.org/documentation/master/#Zero-Bit-Types) |
| `usingnamespace` | [Namespace](https://ziglang.org/documentation/master/#Namespace) |

## Memory Layout → Official Docs

| Skill Pattern | Official Docs Section |
|---|---|
| `extern struct` | [struct > extern struct](https://ziglang.org/documentation/master/#extern-struct) |
| `packed struct` | [struct > packed struct](https://ziglang.org/documentation/master/#packed-struct) |
| `@sizeOf` / `@alignOf` | [Builtin Functions](https://ziglang.org/documentation/master/#Builtin-Functions) |
| `@offsetOf` | [Builtin Functions > @offsetOf](https://ziglang.org/documentation/master/#@offsetOf) |
| `@bitCast` | [Casting > Explicit Casts > @bitCast](https://ziglang.org/documentation/master/#@bitCast) |
| `@splat(0)` padding | [Arrays](https://ziglang.org/documentation/master/#Arrays) |
| `@Vector` SIMD | [Vectors](https://ziglang.org/documentation/master/#Vectors) |
| `@memcpy` / `@memset` | [Builtin Functions > @memcpy](https://ziglang.org/documentation/master/#@memcpy) |
| Cache-line alignment | [Atomics](https://ziglang.org/documentation/master/#Atomics) |
| `volatile` for MMIO | [Pointers > volatile](https://ziglang.org/documentation/master/#volatile) |
| `@divExact` / `@divFloor` | [Operators](https://ziglang.org/documentation/master/#Operators) |

## Concurrency & Atomics → Official Docs

| Skill Pattern | Official Docs Section |
|---|---|
| `@atomicLoad` | [Atomics](https://ziglang.org/documentation/master/#Atomics) |
| `@atomicStore` | [Atomics](https://ziglang.org/documentation/master/#Atomics) |
| `@atomicRmw` | [Atomics](https://ziglang.org/documentation/master/#Atomics) |
| `@cmpxchgStrong` / `@cmpxchgWeak` | [Atomics](https://ziglang.org/documentation/master/#Atomics) |
| `threadlocal var` | [Variables > Thread Local](https://ziglang.org/documentation/master/#Thread-Local) |
| Memory ordering | [Atomics](https://ziglang.org/documentation/master/#Atomics) |
| `std.atomic.cache_line` | [Atomics](https://ziglang.org/documentation/master/#Atomics) |

## C Interop → Official Docs

| Skill Pattern | Official Docs Section |
|---|---|
| `export fn` | [C > Exporting a C Library](https://ziglang.org/documentation/master/#C) |
| `callconv(.c)` | [Functions](https://ziglang.org/documentation/master/#Functions) |
| `extern struct` for C ABI | [struct > extern struct](https://ziglang.org/documentation/master/#extern-struct) |
| `?*anyopaque` context | [C > C Pointers](https://ziglang.org/documentation/master/#C) |
| `@ptrCast` / `@alignCast` | [Casting > Explicit Casts](https://ziglang.org/documentation/master/#Explicit-Casts) |

## Naming & Style → Official Docs

| Convention | Official Style Guide |
|---|---|
| Types: `PascalCase` | [Style Guide](https://ziglang.org/documentation/master/#Style-Guide) |
| Functions: `camelCase` (official) / `snake_case` (TigerBeetle/community) | [Style Guide](https://ziglang.org/documentation/master/#Style-Guide) |
| Constants: `snake_case` or `SCREAMING_SNAKE_CASE` | [Style Guide](https://ziglang.org/documentation/master/#Style-Guide) |
| No underscore prefixes for visibility | [Style Guide > Avoid Redundancy](https://ziglang.org/documentation/master/#Style-Guide) |
| Avoid redundancy in names | [Style Guide](https://ziglang.org/documentation/master/#Style-Guide) |
| Doc comments: `///` for declarations, `//!` for modules | [Style Guide](https://ziglang.org/documentation/master/#Style-Guide) |
| 4-space indentation, no tabs | [Style Guide](https://ziglang.org/documentation/master/#Style-Guide) |

## Builtin Functions Key to Patterns

The skill uses these builtins heavily. Reference the official docs for full
signatures:

- `@import` — compile-time module import
- `@Type` — dynamic type construction from `std.builtin.Type`
- `@typeInfo` — runtime type introspection
- `@fieldParentPtr` — parent struct recovery from field pointer
- `@field` — field access by comptime string name
- `@hasDecl` / `@hasField` — compile-time interface checking
- `@This` — returns innermost struct/enum/union type
- `@src` — source location (file, line, column)
- `@compileError` — emit compile error with message
- `@compileLog` — emit compile-time debug output
- `@panic` — crash with message (unrecoverable)
- `@trap` — crash via illegal instruction (debuggable)
- `@branchHint` — branch predictor hint
- `@setRuntimeSafety` — per-block safety toggle
- `@inComptime` — detect compile-time execution

## Build System Reference

The Zig build system is documented at:
[https://ziglang.org/documentation/master/#Zig-Build-System](https://ziglang.org/documentation/master/#Zig-Build-System)

Key patterns used in production codebases:

```zig
// build.zig — standard build script
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
```

## Additional Official Doc Patterns

### Allocator Selection Flow

| Scenario | Allocator |
|----------|-----------|
| Writing a library | Accept `Allocator` parameter |
| Linking libc | `std.heap.c_allocator` |
| Bounded at comptime | `std.heap.FixedBufferAllocator` |
| CLI, run-to-completion | `ArenaAllocator` with `page_allocator` |
| Cyclical (game loop, web handler) | `ArenaAllocator` per cycle; + `FixedBufferAllocator` |
| Test OOM handling | `std.testing.FailingAllocator` |
| Test general | `std.testing.allocator` |
| General purpose, Debug | `std.heap.DebugAllocator` |
| General purpose, ReleaseFast | `std.heap.smp_allocator` |

### `anytype` Function Parameters

Official docs section: [Function Parameter Type Inference](https://ziglang.org/documentation/master/#Function-Parameter-Type-Inference)

### Sentinel-Terminated Types

Official docs sections: [Sentinel-Terminated Arrays](https://ziglang.org/documentation/master/#Sentinel-Terminated-Arrays),
[Sentinel-Terminated Pointers](https://ziglang.org/documentation/master/#Sentinel-Terminated-Pointers),
[Sentinel-Terminated Slices](https://ziglang.org/documentation/master/#Sentinel-Terminated-Slices)

### `for` + `else` / `while` + `else`

Official docs sections: [for](https://ziglang.org/documentation/master/#for), [while](https://ziglang.org/documentation/master/#while)

### `inline for` / `inline while`

Official docs sections: [inline for](https://ziglang.org/documentation/master/#inline-for), [inline while](https://ziglang.org/documentation/master/#inline-while)

### Non-Exhaustive Enums

Official docs section: [Non-exhaustive enum](https://ziglang.org/documentation/master/#Non-exhaustive-enum)

### `@branchHint`

Official docs section: [Builtin Functions > @branchHint](https://ziglang.org/documentation/master/#@branchHint)

### Defer / errdefer Semantics

Official docs sections: [defer](https://ziglang.org/documentation/master/#defer), [errdefer](https://ziglang.org/documentation/master/#errdefer)

Key rules:
- Multiple defers execute in **reverse order** of appearance
- defers not executed if control never reaches them
- `return` not allowed inside defer expression
- `errdefer` only runs on error exit path from the block
- `errdefer |err| { ... }` captures the error value

### Atomics (Official)

Official docs section: [Atomics](https://ziglang.org/documentation/master/#Atomics)

⚠️ The official Atomics section is a **TODO stub** ("TODO: @atomic rmw", "TODO: builtin atomic memory ordering enum"). The atomic patterns in SKILL.md §8 are derived from production codebases, not official documentation.

## Version Notes

The documentation at `https://ziglang.org/documentation/master/` tracks the
`master` branch (0.17.0-dev). Key changes from 0.14.x:

1. **Build system**: `b.path()` replaces `b.relativePath()`; `b.createModule(.{...})` pattern with `.root_source_file` and `.optimize` in module options; `b.addExecutable(.{ .root_module = ... })` accepts module directly.
2. **`@constCast`**: explicit const-removal cast (prefer over `@ptrCast` for const).
3. **`@volatileCast`**: volatile pointer qualifier conversion for MMIO.
4. **Error return traces**: on by default in Debug/ReleaseSafe.
5. **`std.testing.allocator`**: unchanged; remains the standard leak detector.
6. **FailingAllocator**: `std.testing.FailingAllocator` for testing OOM handling.
7. **`std.heap.DebugAllocator`**: configurable general purpose allocator for Debug mode.
8. **`std.heap.smp_allocator`**: general purpose allocator for ReleaseFast mode.
