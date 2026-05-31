---
name: zbp
description: This skill should be used when writing, modifying, or reviewing Zig code. Covers memory safety (errdefer chains, arena allocators, poisoning), error handling (narrow error sets, exhaustive switches), comptime patterns (@fieldParentPtr, @Type, type functions), memory layout (extern/packed structs, SIMD), thread safety (atomics, threadlocal, lock-free MPSC), C interop (export fn, callconv, allocator bridging), and naming conventions. Applies to any .zig file in any project. Triggers on "Zig best practice", "write Zig", "review Zig", "Zig memory safety", "Zig error handling", "Zig comptime", "Zig C interop", or when working on .zig files.
---

# Zig Best Practices

Patterns for writing safe, performant, and maintainable Zig code. Derived from
[TigerBeetle](https://github.com/tigerbeetle/tigerbeetle),
[Bun](https://github.com/oven-sh/bun),
[libxev](https://github.com/mitchellh/libxev), and
[Ghostty](https://github.com/ghostty-org/ghostty) production codebases,
cross-referenced with the [Zig 0.17 (dev) Language Reference](https://ziglang.org/documentation/master/).

## Quick Reference

| Concern | Key Pattern | Section |
|---------|------------|---------|
| Resource cleanup on error | `errdefer` after every `try` | §1 |
| No OOM at runtime | `ensureTotalCapacity` + `*AssumeCapacity` | §2 |
| Narrow error types | Explicit error sets, `catch \|err\| switch` | §3 |
| Compile-time polymorphism | Type functions, `@fieldParentPtr`, `@Type` | §4 |
| Wire/disk format safety | `extern struct` + comptime layout assertions | §5 |
| Code style | Official: `camelCase` fns, `TitleCase` types. Community: `snake_case` fns | §6 |
| Hot-path optimization | `inline fn`, `@branchHint`, intrusive data structures | §7 |
| Lock-free concurrency | `@atomicLoad`/`@atomicRmw`, MPSC queue | §8 |
| Shared ownership | Cow, RefCount mixin, object pools | §9 |
| C boundary | `export fn`, `callconv(.c)`, allocator bridging | §10 |

## Additional Resources

### Reference Files
- **`references/zig-017-official-docs.md`** — Cross-reference table mapping every
  pattern to the official Zig 0.17 Language Reference sections. Consult when
  verifying patterns against the language specification.
- **`references/style-guide-comparison.md`** — Detailed comparison of Official Zig
  style guide vs TigerBeetle conventions. Explains when and why to deviate.
- **`references/error-handling.md`** — Complete official semantics: error sets,
  error unions, `try`/`catch`/`errdefer`/`defer`, merging error sets, inferred
  error sets, error return traces. Extracted from the Language Reference.
- **`references/comptime-reference.md`** — Official comptime semantics: compile-time
  parameters, `anytype`, comptime variables, comptime expressions, generic data
  structures, `inline fn`, reflection patterns, and common pitfalls.
- **`references/memory-management.md`** — Official allocator selection guide (every
  allocator type with decision flow), lifetime & ownership conventions, heap
  allocation failure philosophy, and struct layout (default/extern/packed).
- **`references/leak-prevention.md`** — Systematic leak prevention for AI-generated
  Zig code: taxonomy of 6 leak patterns, verification protocol, and 3 design patterns
  that eliminate leaks by construction (Arena, AssumeCapacity, Owned vs Borrowed).

### Examples
- **`examples/comprehensive_resource.zig`** — Complete resource struct demonstrating
  all patterns: init/deinit with errdefer chains, infallible runtime operations,
  threadlocal caching, object pools, and C interop exports. Includes tests.

### Scripts
- **`scripts/check_build.zig`** — Scan a Zig project for common anti-patterns:
  `std.debug.assert` in production code, compound `assert(a and b)`, etc.

## Memory Leak Prevention Checklist

**Before claiming any Zig code is done, verify every item.** Token-efficient:
use `grep` patterns to scan, not manual review.

| # | Check | grep/verify command |
|---|-------|---------------------|
| 1 | Every `alloc`/`create` has `defer` or `errdefer` on next line | `grep -n 'alloc\|\.create(' *.zig \| grep -v defer\|errdefer` |
| 2 | Every `try` after an allocation has prior `errdefer` | Scan init functions: each `try X.init` needs `errdefer X.deinit` before it |
| 3 | Every `ArrayList`/`HashMap`/`ArrayListUnmanaged` has `defer deinit` | `grep -n 'ArrayList\|HashMap\|ArrayHashMap' *.zig` → verify `defer deinit` nearby |
| 4 | Every `ArenaAllocator` has `defer arena.deinit()` | `grep -n 'ArenaAllocator.init(' *.zig` |
| 5 | `defer if` for optional resources (File, alloc, etc.) | `grep -n '= null;' *.zig` → check for `defer if` nearby |
| 6 | Deinit reverses init order | Read `deinit()`: fields freed in reverse of `init()` field assignment order |
| 7 | All tests use `std.testing.allocator` | `grep -n 'allocator' *_test.zig` → should reference `testing.allocator` |
| 8 | `test` blocks free all allocations before exit | Run `zig test *.zig` — passes with 0 leaks |
| 9 | No bare `catch unreachable` on allocation failure in libraries | `grep -n 'alloc.*catch unreachable' *.zig` |
| 10 | `self.* = undefined` at end of `deinit()` (poison) | `grep -n 'fn deinit' *.zig` → verify poison in body |

### Token-Efficient Leak Scanning

When reviewing AI-generated Zig code, prefer these compact checks over full file reads:

```bash
# Fastest leak scan: find allocations without nearby defer
grep -n '\.alloc\|\.create(' *.zig | grep -v 'defer\|errdefer' | grep -v 'test\|_test'

# Find containers missing deinit
grep -n 'ArrayList\|HashMap\|ArrayHashMap' *.zig | while read line; do
    f=$(echo "$line" | cut -d: -f1)
    n=$(echo "$line" | cut -d: -f2)
    sed -n "$((n+1))p" "$f" | grep -q 'defer' || echo "MISSING defer at $f:$n"
done

# Verify tests pass with leak detection
zig test src/tests.zig 2>&1 | grep -E 'leaked|error'
```

### Top Leak Patterns AI Must Avoid

| Pattern | Cause | Prevention |
|---------|-------|------------|
| Missing `errdefer` | `try X.init()` after `try alloc` without prior `errdefer` | Every `try` gets an `errdefer` on prior allocations |
| ArrayList leak | `var list: ArrayList(T) = .empty` without `defer list.deinit(alloc)` | `defer` immediately after `.empty` / `.initCapacity` |
| Arena leak | `arena.init()` without `defer arena.deinit()` | Same — `defer` on next line |
| Optional resource leak | `var f: ?File = null;` then `f = ...try...` | `defer if (f) \|file\| file.close();` at declaration |
| Loop allocation leak | `alloc` inside loop without per-iteration free | Arena outside loop, or explicit free each iteration |
| Early return leak | Allocated then `return error.X` without cleanup | `errdefer` before any fallible operation |

## Zig Version Context

These patterns target **Zig 0.17 (dev)**. Key version notes:
- Build system: `b.path()` replaces string paths and `b.relativePath()`.
- Constraints in `std.Build.ExecutableOptions` use `LazyPath` via `b.path()`.
- Error return traces on by default in Debug/ReleaseSafe.
- `@constCast` is the explicit const-removal cast (use over `@ptrCast` for const).
- `std.testing.allocator` remains the standard leak-detection mechanism.

## 1. Memory Safety

### errdefer Chains: Every `try` Gets an `errdefer`

When initializing multiple resources, each `try` must have a matching `errdefer` that
cleans up on failure. This prevents leaks when a later initialization fails:

```zig
pub fn init(allocator: Allocator) error{OutOfMemory}!Self {
    var index = try Index.init(allocator, .{ ... });
    errdefer index.deinit(allocator);

    var cache = try Cache.init(allocator, .{ ... });
    errdefer cache.deinit(allocator);

    var buffer = try allocator.alloc(u8, size);
    errdefer allocator.free(buffer);

    return Self{
        .index = index,
        .cache = cache,
        .buffer = buffer,
    };
}
```

If `Cache.init` fails, `index.deinit` runs. If `allocator.alloc` fails, both
`cache.deinit` and `index.deinit` run. No leaks in any failure path. *[TigerBeetle]*

### Loop errdefer: Partial Array Cleanup

When initializing array elements one by one, `errdefer` must clean up `[0..i]`:

```zig
const blocks = try allocator.alloc(BlockPtr, count);
errdefer allocator.free(blocks);

for (blocks, 0..) |*block, i| {
    errdefer for (blocks[0..i]) |b| allocator.free(b);
    block.* = try allocate_block(allocator);
}
errdefer for (blocks) |b| allocator.free(b);
```

Two errdefers: the inner handles failure mid-loop (`[0..i]`), the outer handles
failure after the loop (all elements). *[TigerBeetle]*

### Two-Phase Create-Then-Init

When a struct must live on the heap (e.g., for pointer stability or self-references),
separate allocation from initialization:

```zig
var pool = try allocator.create(MessagePool);
errdefer allocator.destroy(pool);

pool.* = try MessagePool.init(allocator, options);
errdefer pool.deinit(allocator);
```

Each phase has its own errdefer: `destroy` for the allocation, `deinit` for the
initialized state. If `init` fails, only `destroy` runs (correct). If later code
fails, both `deinit` and `destroy` run (correct). *[TigerBeetle]*

### `defer if`: Conditional Cleanup for Optionals

When a resource is conditionally acquired, declare it as `null` with an immediate
`defer if`:

```zig
var trace_file: ?std.fs.File = null;
defer if (trace_file) |file| file.close();

var exe_path: ?[:0]const u8 = null;
defer if (exe_path) |path| allocator.free(path);

// Later, conditionally assign:
if (options.trace) |trace_path| {
    trace_file = try std.fs.cwd().createFile(trace_path, .{});
}
```

The `defer` captures the variable by reference and evaluates at scope exit. It
sees the final value, so cleanup runs only if the resource was actually acquired.
*[TigerBeetle]*

### Deinit Reversal and Poisoning

Deinitialization must reverse initialization order. Poison memory after free to
catch use-after-free:

```zig
pub fn deinit(self: *Self, allocator: Allocator) void {
    // Reverse order of init
    allocator.free(self.buffer);
    self.cache.deinit(allocator);
    self.index.deinit(allocator);
    self.* = undefined;  // Poison: any access after deinit is caught
}
```

For large buffers, conditional poisoning avoids performance cost:

```zig
if (build_options.verify) {
    @memset(message.buffer, undefined);
}
```
*[TigerBeetle]*

### Resource Grouping

Visually pair allocation with its cleanup. A blank line before + `defer` immediately
after makes leaks obvious in review:

```zig
var io = try IO.init(128, 0);
defer io.deinit();

var pool = try MessagePool.init(allocator, .client);
defer pool.deinit(allocator);
```

When an allocation appears without a `defer` on the next line, investigate.
*[TigerBeetle]*

### errdefer for Diagnostics

Use `errdefer` to log context before an error propagates:

```zig
errdefer log.err("failed to parse config at line {}", .{line_number});
const value = try parseValue(input);
```
*[TigerBeetle]*

### Allocator Passing

Pass allocators explicitly as parameters. Don't store them in structs unless
enforcing a lifecycle:

```zig
// GOOD: caller controls allocator lifetime
pub fn init(allocator: Allocator, options: Options) !Self { ... }
pub fn deinit(self: *Self, allocator: Allocator) void { ... }
```
*[TigerBeetle]*

### Arena Allocator for Temporary Work

Use `ArenaAllocator` when many temporary allocations share a single lifetime.
One `deinit` frees everything — no need to track individual allocations:

```zig
var arena = std.heap.ArenaAllocator.init(gpa);
defer arena.deinit();
const alloc = arena.allocator();

// All allocations below are freed at once by arena.deinit()
var seen = std.AutoHashMap(u64, void).init(alloc);
var buffer = try alloc.alloc(u8, 4096);
// No individual defer/free needed
```

Ideal for validation passes, serialization, and any scope with many short-lived
allocations. *[Ghostty]*

### Allocator Selection Guide

Per the [official docs](https://ziglang.org/documentation/master/#Choosing-an-Allocator),
choose the allocator based on use case:

| Scenario | Allocator |
|----------|-----------|
| Writing a library | Accept `Allocator` parameter — let caller decide |
| Linking libc | `std.heap.c_allocator` |
| Max bytes bounded at comptime | `std.heap.FixedBufferAllocator` |
| CLI app, run-to-completion | `ArenaAllocator` — one `deinit` frees all |
| Cyclical (game loop, web request) | `ArenaAllocator` per cycle; combine with `FixedBufferAllocator` if upper bound known |
| Testing for OOM correctness | `std.testing.FailingAllocator` |
| Testing general | `std.testing.allocator` |
| General purpose, Debug | `std.heap.DebugAllocator` — set up one in `main`, pass around |
| General purpose, ReleaseFast | `std.heap.smp_allocator` |

```zig
// CLI app pattern (official):
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    // All allocations freed by arena.deinit() — no manual cleanup.
}

// FixedBufferAllocator for comptime-bounded max:
var buffer: [4096]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const allocator = fba.allocator();
// Allocations from buffer; fail gracefully if exhausted.
```

### errdefer Capture

Capture the error value in `errdefer` blocks for diagnostics or conditional cleanup:

```zig
errdefer |err| {
    log.err("init failed: {s}", .{@errorName(err)});
}

// Conditional cleanup based on error kind
fn initResource(allocator: Allocator) !*Resource {
    const res = try allocator.create(Resource);
    errdefer |err| {
        if (err != error.OutOfMemory) {
            // On OOM, no cleanup needed (no partial state)
            allocator.destroy(res);
        }
    }
    try res.init(allocator);
    return res;
}
```

*[Official docs]*

### Defer Execution Semantics

Multiple `defer` expressions execute in **reverse order** of appearance. `defer`
inside an untaken branch never executes. `return` is not allowed inside `defer`:

```zig
defer { std.debug.print("1 ", .{}); }
defer { std.debug.print("2 ", .{}); }
// Prints "2 1" (reverse order)
```

*[Official docs]*

## 2. Infallible Runtime Operations

### The Principle

**Runtime state-changing operations must not fail.** If an operation partially modifies
state then fails (e.g., OOM), reverting partial state is complex and error-prone.
Instead: pre-allocate capacity at init where errors can be handled, then operate
infallibly at runtime where rollback would be dangerous. *[TigerBeetle]*

### HashMap

```zig
// At init: pre-allocate, can fail here
try map.ensureTotalCapacity(allocator, max_entries);

// At runtime: infallible
map.putAssumeCapacityNoClobber(key, value);   // assert key is new
map.putAssumeCapacity(key, value);            // allows overwrite
map.fetchPutAssumeCapacity(key, value);       // returns old value

// CRITICAL: putAssumeCapacity on HashMaps with no Value will NOT clobber.
// Use getOrPutAssumeCapacity instead:
const gop = map.getOrPutAssumeCapacity(key);
if (!gop.found_existing) {
    gop.key_ptr.* = key;
}
gop.value_ptr.* = value;
```
*[TigerBeetle, Zig stdlib]*

### ArrayList

```zig
// addOneAssumeCapacity: get pointer to uninitialized slot, then write
const entry = list.addOneAssumeCapacity();
entry.* = .{ .id = id, .data = data };

// appendAssumeCapacity: append a value
list.appendAssumeCapacity(value);

// appendSliceAssumeCapacity: bulk append
list.appendSliceAssumeCapacity(items);
```
*[TigerBeetle, Zig stdlib]*

### BoundedArray (Comptime Capacity)

For arrays with compile-time-known capacity, use assert-based bounds (no errors):

```zig
pub fn BoundedArrayType(comptime T: type, comptime capacity: usize) type {
    return struct {
        buffer: [capacity]T = undefined,
        count: u32 = 0,

        pub fn push(array: *@This(), item: T) void {
            assert(!array.full());   // Panic, not error
            array.buffer[array.count] = item;
            array.count += 1;
        }
    };
}
```
*[TigerBeetle]*

### RingBuffer

```zig
ring.push_assume_capacity(item);       // assert space, no error
ring.push_head_assume_capacity(item);  // same, prepend
```
*[TigerBeetle]*

### Rollback Log Pattern

When operations need to be reversible by design (not due to OOM), use a pre-allocated
rollback log:

```zig
if (scope_is_active) {
    if (old_value) |old| {
        // Infallible: log is pre-allocated
        rollback_log.appendAssumeCapacity(old);
    } else {
        rollback_log.appendAssumeCapacity(tombstone_from_key(key));
    }
}
```
*[TigerBeetle]*

## 3. Error Handling

### Narrow Error Sets

Each function declares the narrowest possible error set:

```zig
pub fn push(self: *RingBuffer, item: T) error{NoSpaceLeft}!void { ... }
pub fn parse(string: []const u8) error{InvalidRelease}!Result { ... }
pub fn init(allocator: Allocator) error{OutOfMemory}!Self { ... }
```
*[TigerBeetle]*

### Error Set Composition with `||`

Combine error sets from different sources into a single union:

```zig
// Merge related error sets
const IoError = std.posix.ReadError || std.posix.WriteError;

// Compose domain errors with system errors
const WatcherError = std.mem.Allocator.Error ||
    std.posix.KQueueError ||
    std.Thread.SpawnError;

// Merge across backend implementations
fn BackendErrorSet(comptime backends: []const Backend) type {
    var Set: type = error{};
    for (backends) |be| {
        Set = Set || be.Api().AcceptError;
    }
    return Set;
}
```

Use `||` when a function can fail with errors from multiple subsystems, or when
building a unified error type across compile-time-selected backends. *[Bun, libxev]*

### `catch |err| switch`: Exhaustive Error Recovery

The primary pattern for non-trivial error handling. List every error explicitly:

```zig
const bytes_read = result catch |err| switch (err) {
    error.InputOutput => {
        // Specific recovery logic
        log.warn("sector error: offset={}, subdividing...", .{offset});
        self.start_read(read, 0);
        return;
    },
    error.WouldBlock,
    error.ConnectionResetByPeer,
    error.SystemResources,
    => {
        log.err("fatal read: error={s}", .{@errorName(err)});
        @panic("unrecoverable read error");
    },
};
```
*[TigerBeetle]*

### `catch unreachable`: Proven Invariants

Use when prior validation guarantees the operation cannot fail. **Always comment why:**

```zig
var decoder = Decoder.init(body, .{
    .element_size = operation.event_size(),
}) catch unreachable; // Already validated by `input_valid()`.

const ts = posix.clock_gettime(posix.CLOCK.MONOTONIC) catch unreachable;
```
*[TigerBeetle]*

### `orelse` Patterns

```zig
// Propagate "not found" as domain result
const item = self.get(id) orelse return .not_found;

// Convert optional to specific error
const value = parts.next() orelse return error.InvalidFormat;

// Silently skip if not available
const writer = options.writer orelse return;

// Guaranteed to exist by invariant
const top = stack.peek() orelse unreachable;
```
*[TigerBeetle]*

### Exhaustive Switches

List all cases explicitly. Avoid bare `else =>` which hides missing cases when
new variants are added:

```zig
// GOOD: compiler catches new variants
switch (status) {
    .none, .pending => assert(pending_id == 0),
    .posted, .voided, .expired => assert(pending_id != 0),
}

// For comptime-impossible cases
.pulse => comptime unreachable,
```
*[TigerBeetle]*

### Return Type Precision

Use the simplest return type. Simpler types reduce call-site complexity:

`void` > `bool` > `u64` > `?u64` > `!u64` > `error{X}!T`

```zig
fn on_callback(grid: *Grid) void { ... }        // No failure possible
pub fn empty(self: *const Queue) bool { ... }    // Simple predicate
pub fn pop(self: *RingBuffer) ?T { ... }         // May have nothing
pub fn init(alloc: Allocator) error{OutOfMemory}!Self { ... }  // Specific error
```
*[TigerBeetle]*

### `@panic` Messages

Use for unrecoverable invariant violations. Messages must be specific:

```zig
@panic("impossible read");
@panic("latent sector error: no spare sectors to reallocate");
@panic("timeout was not reset correctly");
```
*[TigerBeetle]*

### `error.SkipZigTest` for Platform-Specific Tests

Return `error.SkipZigTest` to skip tests on unsupported platforms:

```zig
test "pty read/write" {
    switch (builtin.os.tag) {
        .linux, .macos => {},
        else => return error.SkipZigTest,
    }
    // Platform-specific test body...
}

test "io_uring completion" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    // Linux-only test...
}
```

The Zig test runner recognizes this error and reports the test as skipped
rather than failed. *[libxev]*

### Comptime Error Type Assertions

Verify error types at compile time to guard exhaustive handling:

```zig
comptime assert(@TypeOf(err) == error{OutOfMemory});
```

Ensures that a `catch` block handles exactly the expected error set, catching
drift when upstream functions change their error types. *[Ghostty]*

## 4. Comptime & Generics

### `anytype` Function Parameters

Use `anytype` when a function should accept any type without a comptime type
parameter. The concrete type is inferred at the call site. Use `@TypeOf` and
`@typeInfo` to inspect the inferred type:

```zig
fn addFortyTwo(x: anytype) @TypeOf(x) {
    return x + 42;
}

// Works with any type that supports + 42:
const a = addFortyTwo(1);        // comptime_int
const b = addFortyTwo(@as(i64, 2)); // i64
```

This is "compile-time duck typing" — the function compiles for any type that
satisfies the operations in the body. *[Official docs]*

### Type Functions

Return `type` from comptime-parameterized functions:

```zig
pub fn QueueType(comptime T: type) type {
    return struct {
        head: ?*T = null,
        tail: ?*T = null,
        count: u32 = 0,

        pub fn push(self: *@This(), node: *T) void { ... }
        pub fn pop(self: *@This()) ?*T { ... }
    };
}
```
*[TigerBeetle]*

### Comptime Assertions in Structs

Validate layout and invariants at compile time:

```zig
pub const Header = extern struct {
    checksum: u128,
    command: Command,
    size: u32,
    padding: [7]u8 = @splat(0),

    comptime {
        assert(@sizeOf(Header) == 64);
        assert(@sizeOf(Header) % @alignOf(u128) == 0);
        // Verify no compiler-inserted padding
        assert(no_padding(Header));
    }
};
```
*[TigerBeetle]*

### Interface via `@fieldParentPtr`

Implement interfaces by embedding subsystems as named fields. Callbacks receive
the subsystem pointer and recover the parent:

```zig
const Server = struct {
    grid: Grid,
    journal: Journal,
    state_machine: StateMachine,

    fn grid_callback(grid: *Grid) void {
        // Recover Server from its grid field
        const self: *Server = @alignCast(@fieldParentPtr("grid", grid));
        // Now has full access to Server
        self.state_machine.open(sm_callback);
    }

    fn sm_callback(sm: *StateMachine) void {
        const self: *Server = @alignCast(
            @fieldParentPtr("state_machine", sm),
        );
    }
};
```

Zero-cost polymorphism — no vtable indirection. Works because structs have
stable addresses (statically allocated). *[TigerBeetle]*

### Type Erasure for Callbacks

Store typed callbacks as untyped function pointers:

```zig
pub fn read(
    self: *IO,
    comptime Context: type,
    context: Context,
    comptime callback: fn (Context, *Completion, ReadError!usize) void,
    completion: *Completion,
) void {
    completion.* = .{
        .context = context,
        .callback = struct {
            fn erased(ctx: ?*anyopaque, comp: *Completion, res: *const anyopaque) void {
                callback(
                    @ptrCast(@alignCast(ctx)),
                    comp,
                    @as(*const ReadError!usize, @ptrCast(@alignCast(res))).*,
                );
            }
        }.erased,
    };
}
```
*[TigerBeetle]*

### Tagged Unions for State Machines

```zig
const Phase = union(enum) {
    idle: void,
    loading: struct { offset: u64, remaining: u32 },
    processing: struct { operation: Op, timestamp: u64 },
    done: void,
};

// Dispatch — always exhaustive
switch (self.phase) {
    .idle => { ... },
    .loading => |l| { ... },
    .processing => |p| { ... },
    .done => { ... },
}
```
*[TigerBeetle]*

### Labeled Blocks for Computed Values

Multi-statement value computation with `blk:` / `break :blk`:

```zig
// Comptime constant with complex initialization
pub const slot_bases = bases: {
    var array = std.enums.EnumArray(Tag, u32).initFill(0);
    var next: u32 = 0;
    for (std.enums.values(Tag)) |tag| {
        array.set(tag, next);
        next += slot_limits.get(tag);
    }
    break :bases array;
};

// Runtime conditional computation
const timeout: u64 = timeout: {
    if (options.timeout_ms) |ms| {
        break :timeout ms * std.time.ns_per_ms;
    }
    break :timeout default_timeout_ns;
};
```
*[TigerBeetle]*

### Dynamic Type Construction with `@Type`

Build types from comptime data:

```zig
const MyEnum = blk: {
    var fields: []const std.builtin.Type.EnumField = &.{};
    for (config.items, 0..) |item, i| {
        fields = fields ++ &[_]std.builtin.Type.EnumField{.{
            .name = item.name,
            .value = i,
        }};
    }
    break :blk @Type(.{ .@"enum" = .{
        .tag_type = u32,
        .fields = fields,
        .decls = &.{},
        .is_exhaustive = true,
    } });
};
```
*[TigerBeetle, libxev]*

### `@hasDecl` / `@hasField` for Compile-Time Interface Checking

Verify that a type implements required methods or fields at compile time:

```zig
pub fn Cow(comptime T: type, comptime VTable: type) type {
    return union(enum) {
        borrowed: *const T,
        owned: T,

        fn copy(this: *const T, allocator: Allocator) T {
            if (!@hasDecl(VTable, "copy"))
                @compileError(@typeName(VTable) ++ " needs `copy()` function");
            return VTable.copy(this, allocator);
        }
    };
}

// Optional method dispatch
if (comptime std.meta.hasFn(Type, "reset")) {
    node.data.reset();
}
```

Use `@hasDecl` for hard interface requirements (emit `@compileError` if missing).
Use `std.meta.hasFn` / `@hasDecl` with `if` for optional capabilities. *[Bun]*

### Compile-Time Platform / Backend Selection

Use `switch` on `builtin.os.tag` or config enums to select implementations:

```zig
pub const Backend = enum {
    io_uring, epoll, kqueue, wasi_poll, iocp,

    pub fn default() Backend {
        return switch (builtin.os.tag) {
            .linux => .io_uring,
            .ios, .macos, .freebsd => .kqueue,
            .wasi => .wasi_poll,
            .windows => .iocp,
            else => @compileError("no default backend"),
        };
    }
};

// Select implementation type at compile time
pub fn Loop(comptime backend: Backend) type {
    return switch (backend) {
        .io_uring => @import("backend/io_uring.zig").Loop,
        .epoll => @import("backend/epoll.zig").Loop,
        .kqueue => @import("backend/kqueue.zig").Loop,
    };
}
```
*[libxev]*

### Compile-Time Configuration-Driven Composition

Use options structs with comptime parameters to selectively enable features:

```zig
pub const StreamOptions = struct {
    read: ReadMethod = .none,
    write: WriteMethod = .none,
    close: bool = false,

    pub const ReadMethod = enum { none, read, recv };
    pub const WriteMethod = enum { none, write, send };
};

pub fn GenericStream(comptime xev: type, comptime options: StreamOptions) type {
    return struct {
        // Only generate read methods if read is enabled
        pub usingnamespace if (options.read != .none) struct {
            pub fn read(self: *@This(), buf: []u8) !usize { ... }
        } else struct {};
    };
}
```
*[libxev]*

### `@setEvalBranchQuota`

Increase comptime evaluation budget for complex reflection:

```zig
@setEvalBranchQuota(32_000);
inline for (std.meta.fields(LargeStruct)) |field| {
    // Process each field
}
```
*[TigerBeetle]*

### `void` as Type-Level Feature Flag

Replace unavailable platform types with `void` to eliminate dead code at comptime:

```zig
const macos = switch (builtin.os.tag) {
    .macos => @import("macos"),
    else => void,
};

const DisplayLink = switch (builtin.os.tag) {
    .macos => *macos.video.DisplayLink,
    else => void,
};

// Usage: comptime check removes entire code path on non-macOS
if (comptime DisplayLink != void) {
    // macOS-specific display link setup
}
```

The compiler completely eliminates branches on `void` types. No runtime cost,
no `#ifdef`-style preprocessor. *[Ghostty]*

### Comptime String Processing with `@embedFile`

Process embedded files (e.g., shader includes) at compile time:

```zig
fn loadShader(comptime path: []const u8) [:0]const u8 {
    return comptime processIncludes(
        @embedFile(path),
        std.fs.path.dirname(path).?,
    );
}

fn processIncludes(
    comptime contents: [:0]const u8,
    comptime basedir: []const u8,
) [:0]const u8 {
    @setEvalBranchQuota(100_000);
    var i: usize = 0;
    while (i < contents.len) : (i += 1) {
        if (std.mem.startsWith(u8, contents[i..], "#include")) {
            // Extract filename, recursively embed
            return std.fmt.comptimePrint("{s}{s}{s}", .{
                contents[0..i],
                @embedFile(basedir ++ "/" ++ filename),
                processIncludes(contents[end..], basedir),
            });
        }
    }
    return contents;
}
```

Recursive comptime preprocessor — resolves `#include` directives by embedding
files during compilation. Zero runtime I/O. *[Ghostty]*

### Recursive Deep Equality via Type Introspection

Generic equality that recurses through structs, optionals, arrays, and unions:

```zig
pub fn deepEqual(comptime T: type, old: T, new: T) bool {
    switch (@typeInfo(T)) {
        .optional => |info| {
            if (old == null and new == null) return true;
            if (old == null or new == null) return false;
            return deepEqual(info.child, old.?, new.?);
        },
        .array => |info| {
            for (old, new) |o, n| {
                if (!deepEqual(info.child, o, n)) return false;
            }
            return true;
        },
        .@"struct" => |info| {
            if (@hasDecl(T, "equal")) return old.equal(new);
            inline for (info.fields) |field| {
                if (!deepEqual(
                    field.type,
                    @field(old, field.name),
                    @field(new, field.name),
                )) return false;
            }
            return true;
        },
        else => return old == new,
    }
}
```

Respects custom `equal` methods when present. Uses `inline for` over struct
fields for zero-cost compile-time unrolling. *[Ghostty]*

## 5. Memory Layout & Copy Safety

### Extern Struct with Layout Assertions

For wire formats, disk formats, or FFI types:

```zig
pub const Record = extern struct {
    id: u128,
    timestamp: u64,
    flags: u32,
    padding: [4]u8 = @splat(0),  // Deterministic zero padding

    comptime {
        assert(@sizeOf(Record) == 32);
        assert(@offsetOf(Record, "id") == 0);
        assert(@offsetOf(Record, "timestamp") == 16);
        assert(no_padding(Record));  // No hidden compiler padding
    }
};
```
*[TigerBeetle]*

### `@splat(0)` for Deterministic Padding

All padding and reserved fields must be zero-initialized. This prevents information
leakage and ensures deterministic checksums:

```zig
reserved: [88]u8 = @splat(0),
padding: [7]u8 = @splat(0),
```
*[TigerBeetle]*

### Safe Copy Functions

Wrap `@memcpy` with directional and size safety:

```zig
// copy_disjoint: ASSERTS regions don't overlap
copy_disjoint(.exact, T, target, source);   // target.len == source.len
copy_disjoint(.inexact, T, target, source); // target.len >= source.len

// copy_left: overlapping, target before source (forward copy)
copy_left(.exact, T, target, source);

// copy_right: overlapping, target after source (backward copy)
copy_right(.exact, T, target, source);
```

The precision enum (`.exact` vs `.inexact`) asserts the length relationship,
catching size mismatches at runtime. *[TigerBeetle]*

### Safe Byte-to-Type Reinterpretation

```zig
// .exact: byte length must be exact multiple of element size
const items = bytes_as_slice(.exact, Item, raw_bytes);

// .inexact: truncate to largest whole number of elements
const headers = bytes_as_slice(.inexact, Header, raw_bytes);
```
*[TigerBeetle]*

### Aligned Allocation for Direct I/O

```zig
const buffers = try allocator.alignedAlloc(
    [message_size_max]u8,
    sector_size,  // alignment for Direct I/O
    count,
);

comptime {
    assert(message_size_max % sector_size == 0);
}
```
*[TigerBeetle]*

### Packed Struct Bitfields

Use `packed struct` for bit-level memory layout control:

```zig
const Sync = packed struct {
    idle: u14 = 0,
    spawned: u14 = 0,
    unused: bool = false,
    notified: bool = false,
    state: enum(u2) {
        pending = 0,
        signaled,
        waking,
        shutdown,
    } = .pending,
};

// With explicit backing type
pub const Flags = packed struct(u8) {
    allow_variance: bool = false,
    allow_const: bool = false,
    allow_empty: bool = false,
    _: u5 = 0,  // Explicit padding bits
};
```

Packed structs fit into a single integer, enabling atomic load/store of the
entire struct. Useful for thread-safe status words and protocol flags. *[Bun]*

### Sentinel Values

Use `maxInt` for boundary markers in sorted structures:

```zig
pub const sentinel_key: Key = .{
    .field = math.maxInt(Field),
    .timestamp = math.maxInt(u64),
};
```
*[TigerBeetle]*

### Explicit Division Intent

Make rounding intent explicit to the reader:

```zig
@divExact(total_size, block_size);           // Must divide evenly
@divFloor(numerator, denominator);           // Round toward zero
div_ceil(numerator, denominator);            // Round up
```
*[TigerBeetle]*

### Branchless Operations for Hot Paths

```zig
pub inline fn branchless_select(comptime T: type, flag: bool, a: T, b: T) T {
    @branchHint(.unpredictable);
    return if (flag) a else b;
}
```
*[TigerBeetle]*

### SIMD with `@Vector`

Use `@Vector` for data-parallel operations that map to hardware SIMD:

```zig
pub const F32x4 = @Vector(4, f32);
pub const Mat = [4]F32x4;

pub fn ortho2d(left: f32, right: f32, bottom: f32, top: f32) Mat {
    const w = right - left;
    const h = top - bottom;
    return .{
        .{ 2 / w, 0, 0, 0 },
        .{ 0, 2 / h, 0, 0 },
        .{ 0, 0, -1, 0 },
        .{ -(right + left) / w, -(top + bottom) / h, 0, 1 },
    };
}
```

`@Vector` operations compile to SIMD instructions (SSE, AVX, NEON) when
available. Use for math-heavy hot paths like matrix transforms, color
operations, and batch processing. *[Ghostty]*

### Memory-Mapped I/O

Use `mmap` for large, page-aligned allocations with OS-level lifecycle:

```zig
pub fn init(cap: Capacity) !Page {
    const l = layout(cap);
    assert(l.total_size % std.heap.page_size_min == 0);
    const backing = try posix.mmap(
        null,
        l.total_size,
        posix.PROT.READ | posix.PROT.WRITE,
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
        -1,
        0,
    );
    errdefer posix.munmap(backing);
    // ...
}
```

Anonymous mmap is guaranteed zero-initialized by the OS. Useful for terminal
page buffers, large lookup tables, and any allocation that benefits from
page-granularity lifecycle control. *[Ghostty]*

### Cache-Line Aligned Buffers

Align buffers to cache line boundaries to prevent false sharing:

```zig
var read_buf: [4096]u8 align(std.atomic.cache_line) = undefined;
var buf: [4096]u8 align(std.atomic.cache_line) = undefined;
```

Critical for buffers accessed from multiple threads. `std.atomic.cache_line`
is the platform's cache line size (typically 64 bytes). *[Ghostty]*

## 6. Naming & Style

### Official Style (Zig 0.17 Language Reference)

Per the [official style guide](https://ziglang.org/documentation/master/#Style-Guide):

- **`camelCase`** for functions: `addOne`, `deferExample`
- **`TitleCase`** for types: `Point`, `LinkedList`
- **`snake_case`** for variables: `my_var`, `total_count`
- **Exception**: A struct with 0 fields used purely as a namespace → `snake_case`
- **Exception**: If `x` is callable and returns `type`, then `x` is `TitleCase`
- **Acronyms follow same rules**: `VsrState`, `IoCompletion` (not `VSRState`, `IOCompletion`)
- **File names**: types → `TitleCase`, namespaces → `snake_case`
- **Directory names**: `snake_case`
- **4-space indentation**, open braces on same line
- **Line length**: aim for 100, use common sense
- **Doc comments**: `///` for declarations, `//!` for top-level module docs
- **No underscore prefixes** for visibility
- **Avoid redundancy**: no `Value`, `Data`, `Context` in type names

### TigerBeetle/Community Conventions

Production Zig codebases (TigerBeetle, Bun, libxev, Ghostty) use **`snake_case`**
for functions. This is the dominant convention in the ecosystem. **Follow the
convention of the codebase you're in.** For greenfield projects, either convention
is valid — `snake_case` gives more community alignment.

### Units/Qualifiers Last

Sort by descending significance — units and qualifiers go last:
```zig
latency_ms_max    // not: max_latency_ms
latency_ms_min    // lines up with latency_ms_max
offset_bytes      // unit last
accounts_count    // qualifier last
```
*[TigerBeetle]*

### No Abbreviations

Use `source`/`target`, not `src`/`dest`. *[TigerBeetle]*

### Callbacks Last

Callback parameters go **last** in parameter lists. *[TigerBeetle]*

### Named Arguments via Struct

Use `options: struct` when arguments can be mixed up (e.g., two `u64` params):

```zig
fn memcpy(options: struct {
    source: [*]const u8,
    target: [*]u8,
    count: usize,
}) void { ... }
```
*[TigerBeetle]*

### Explicitly-Sized Types

Use `u32`, `u64` instead of architecture-specific `usize`:

```zig
count: u32 = 0,      // not: count: usize
offset: u64,         // not: offset: usize
```
*[TigerBeetle]*

### Inline Functions

Mark hot-path functions `pub inline fn`. Note: `inline` in Zig is **not an
optimization hint** — it forces comptime propagation of arguments and semantically
changes the function call. Use only when:
- Comptime argument propagation is required
- Stack frame count matters for debugging
- Benchmarks prove it helps

```zig
pub inline fn hash(value: anytype) u64 { ... }
pub inline fn empty(self: *const Queue) bool { return self.count == 0; }
```
*[Official docs, TigerBeetle]*

## 7. Code Organization

### Import Order

1. Zig builtins: `builtin`, `std`
2. Extended stdlib utilities
3. Commonly used members: `assert`, `mem`
4. Project modules
5. Type aliases

```zig
const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;

const constants = @import("constants.zig");
const log = std.log.scoped(.module_name);

const MyType = @import("my_module.zig").MyType;
```
*[TigerBeetle]*

### Scoped Logging

Every module that logs should create a scoped logger:

```zig
const log = std.log.scoped(.storage);
```
*[TigerBeetle]*

### Struct Member Ordering

Fields first, then types, then methods:

```zig
const Tracer = struct {
    time: Time,
    process_id: ProcessID,

    const ProcessID = struct { cluster: u128, replica: u8 };

    pub fn init(allocator: Allocator) !Tracer { ... }
    pub fn deinit(self: *Tracer) void { ... }
};
```
*[TigerBeetle]*

### Assertions as Documentation

- Minimum 2 assertions per function.
- Split compound assertions: `assert(a); assert(b);` not `assert(a and b);`.
- Single-line implication: `if (a) assert(b);`
- State invariants positively: `if (index < length)` not `if (index >= length)`.
- Comptime assertions for constant relationships.

*[TigerBeetle]*

### Intrusive Data Structures

Embed link fields in nodes instead of allocating separate containers:

```zig
const Node = struct {
    data: Data,
    back: ?*@This() = null,
    next: ?*@This() = null,
};

const List = DoublyLinkedListType(Node, .back, .next);
```

Benefits: zero allocation, O(1) insert/remove, nodes can be in multiple lists
via distinct field pairs. *[TigerBeetle]*

**Intrusive priority queue (pairing heap):**

```zig
pub fn IntrusiveHeap(
    comptime T: type,
    comptime Context: type,
    comptime less: *const fn (ctx: Context, a: *T, b: *T) bool,
) type {
    return struct {
        root: ?*T = null,
        context: Context,

        pub fn insert(self: *Self, v: *T) void {
            self.root = if (self.root) |root| self.meld(v, root) else v;
        }

        pub fn deleteMin(self: *Self) ?*T {
            const root = self.root orelse return null;
            self.root = if (root.heap.child) |child|
                self.combine_siblings(child) else null;
            root.heap = .{};
            return root;
        }
    };
}

// Embed heap metadata in nodes
const Timer = struct {
    deadline: u64,
    callback: *const fn () void,
    heap: IntrusiveHeap(Timer, void, lessThan).Field = .{},
};
```

Pairing heaps give O(1) insert and amortized O(log n) deleteMin with zero
allocation. Ideal for timer wheels and priority scheduling. *[libxev]*

### Reference Counting for Shared Resources

When resources are shared across subsystems, use explicit ref counting:

```zig
pub fn ref(message: *Message) *Message {
    assert(message.references > 0);
    message.references += 1;
    return message;
}

pub fn unref(pool: *Pool, message: *Message) void {
    message.references -= 1;
    if (message.references == 0) {
        message.header = undefined;
        pool.free_list.push(message);
    }
}
```

Every `ref()` must have a matching `unref()`. Assert reference counts at
critical ownership transitions. *[TigerBeetle]*

### Object Pool with Free List

Reuse allocations via a singly-linked free list:

```zig
pub fn ObjectPool(comptime T: type, comptime max_count: comptime_int) type {
    return struct {
        const Node = struct { data: T, next: ?*Node = null };

        list: ?*Node = null,
        count: u32 = 0,

        pub fn get(self: *@This(), allocator: Allocator) *Node {
            if (self.list) |node| {
                self.list = node.next;
                self.count -= 1;
                if (comptime std.meta.hasFn(T, "reset")) node.data.reset();
                return node;
            }
            return allocator.create(Node) catch unreachable;
        }

        pub fn release(self: *@This(), node: *Node) void {
            if (max_count > 0 and self.count >= max_count) {
                allocator.destroy(node);
                return;
            }
            node.next = self.list;
            self.list = node;
            self.count += 1;
        }
    };
}
```

Optional `reset()` method on pooled objects clears state for reuse. Compile-time
`max_count` bounds pool growth. *[Bun]*

## 8. Thread Safety & Concurrency

### `threadlocal var`

Per-thread state without synchronization:

```zig
// Simple thread-local flag
pub threadlocal var is_main_thread: bool = false;

// Conditional threadlocal based on compile-time config
const Storage = if (threadsafe) void else DataStruct;
threadlocal var tls_data: Storage = .{};

inline fn data() *DataStruct {
    if (comptime threadsafe) return &tls_data;
    return &global_data;
}
```

Use `threadlocal` for per-thread caches, allocator state, or thread identity.
Combine with comptime booleans to compile away thread-local storage when
single-threaded. *[Bun]*

### Lock-Free MPSC Queue

Multi-producer single-consumer queue using atomics (Vyukov queue):

```zig
pub fn MpscQueue(comptime T: type) type {
    return struct {
        head: *T,
        tail: *T,
        stub: T,

        pub fn push(self: *Self, v: *T) void {
            @atomicStore(?*T, &v.next, null, .unordered);
            const prev = @atomicRmw(*T, &self.head, .Xchg, v, .acq_rel);
            @atomicStore(?*T, &prev.next, v, .release);
        }

        pub fn pop(self: *Self) ?*T {
            var tail = @atomicLoad(*T, &self.tail, .unordered);
            var next_ = @atomicLoad(?*T, &tail.next, .acquire);
            if (tail == &self.stub) {
                const next = next_ orelse return null;
                @atomicStore(*T, &self.tail, next, .unordered);
                tail = next;
                next_ = @atomicLoad(?*T, &tail.next, .acquire);
            }
            if (next_) |next| {
                @atomicStore(*T, &self.tail, next, .unordered);
                return tail;
            }
            return null;
        }
    };
}
```

Key atomic operations:
- `@atomicRmw(.Xchg, ...)` — atomic exchange for lock-free enqueue.
- `@atomicStore` / `@atomicLoad` — with explicit memory ordering (`.acquire`,
  `.release`, `.acq_rel`).
- No mutexes needed; the producer side is wait-free.

*[libxev]*

### Atomic Operations Summary

```zig
// Atomic load/store with ordering
const val = @atomicLoad(u32, &shared, .acquire);
@atomicStore(u32, &shared, new_val, .release);

// Atomic read-modify-write
const old = @atomicRmw(u32, &counter, .Add, 1, .seq_cst);
const prev = @atomicRmw(*Node, &head, .Xchg, new_node, .acq_rel);

// Compare-and-swap
const result = @cmpxchgStrong(
    u32, &value, expected, desired, .seq_cst, .monotonic,
);
```

Memory ordering from weakest to strongest:
`.unordered` < `.monotonic` < `.acquire`/`.release` < `.acq_rel` < `.seq_cst`.
Use the weakest ordering that maintains correctness. *[libxev, Bun]*

## 9. Smart Pointer Patterns

### Copy-on-Write (Cow)

Tagged union that borrows or owns data, copying only when mutation is needed:

```zig
pub fn Cow(comptime T: type, comptime VTable: type) type {
    return union(enum) {
        borrowed: *const T,
        owned: T,

        pub fn borrow(val: *const T) @This() {
            return .{ .borrowed = val };
        }

        pub fn own(val: T) @This() {
            return .{ .owned = val };
        }

        pub fn toOwned(this: *@This(), allocator: Allocator) *T {
            switch (this.*) {
                .borrowed => |b| {
                    this.* = .{ .owned = VTable.copy(b, allocator) };
                },
                .owned => {},
            }
            return &this.owned;
        }

        pub fn deinit(this: *@This(), allocator: Allocator) void {
            if (this.* == .owned) VTable.deinit(&this.owned, allocator);
        }
    };
}
```

Avoids copies when only reading. The VTable pattern (with `@hasDecl` checks)
ensures `copy` and `deinit` are implemented. *[Bun]*

### Reference Counting Mixin

Embed reference counting in any struct via a comptime mixin:

```zig
pub fn RefCount(
    comptime T: type,
    comptime field_name: []const u8,
    comptime destructor: anytype,
) type {
    return struct {
        raw_count: u32 = 1,

        pub fn ref(self: *T) *T {
            const rc = &@field(self, field_name);
            assert(rc.raw_count > 0);
            rc.raw_count += 1;
            return self;
        }

        pub fn deref(self: *T) void {
            const rc = &@field(self, field_name);
            rc.raw_count -= 1;
            if (rc.raw_count == 0) {
                destructor(self);
            }
        }
    };
}

// Usage: embed in struct
const Resource = struct {
    data: []u8,
    rc: RefCount(Resource, "rc", destroy) = .{},

    fn destroy(self: *Resource) void {
        allocator.free(self.data);
        allocator.destroy(self);
    }
};
```

The mixin uses `@field` with `field_name` to access itself within the parent
struct — same `@fieldParentPtr` philosophy but for reference counting. *[Bun]*

## 10. C Interop

### `export fn` for C API

Expose Zig functions to C with `export`:

```zig
export fn xev_loop_init(loop: *xev.Loop) c_int {
    loop.* = xev.Loop.init(.{}) catch |err| return errorCode(err);
    return 0;
}

export fn xev_timer_run(
    v: *xev.Timer,
    loop: *xev.Loop,
    next_ms: u64,
    userdata: ?*anyopaque,
    cb: *const fn (*xev.Loop, c_int, ?*anyopaque) callconv(.c) void,
) void {
    // Bridge C callback to Zig callback
}
```
*[libxev]*

### `callconv(.c)` for Callbacks

Use C calling convention for functions passed to C libraries:

```zig
pub fn alloc(_: ?*anyopaque, len: usize) callconv(.c) ?*anyopaque {
    return mimalloc.mi_malloc(len);
}

pub fn free(_: ?*anyopaque, ptr: ?*anyopaque) callconv(.c) void {
    mimalloc.mi_free(ptr);
}
```
*[Bun]*

### Security-Conscious Memory Deallocation

Zero memory before freeing to prevent sensitive data leaks:

```zig
export fn secure_free(ptr: *anyopaque) void {
    const len = allocator.usable_size(ptr);
    @memset(@as([*]u8, @ptrCast(ptr))[0..len], 0);
    allocator.free(ptr);
}
```

Critical for cryptographic keys, passwords, and authentication tokens.
Always zero before free, never rely on the allocator to clear memory. *[Bun]*

### Platform-Specific Type Selection

Select C-compatible types based on target platform:

```zig
const Context = if (builtin.os.tag == .windows)
    std.os.windows.CONTEXT
else if (builtin.os.tag == .linux and builtin.abi == .musl)
    musl.jmp_buf
else
    std.c.ucontext_t;
```
*[Bun]*

### Context Pointer Smuggling

Encode small values (enums, indices) inside the context pointer itself:

```zig
pub fn taggedPageAllocator(tag: VMTag) Allocator {
    return .{
        .ptr = @ptrFromInt(@as(usize, @intFromEnum(tag))),
        .vtable = &TaggedPageAllocator.vtable,
    };
}

fn alloc(context: *anyopaque, n: usize, ...) ?[*]u8 {
    const tag: VMTag = @enumFromInt(
        @as(u8, @truncate(@intFromPtr(context))),
    );
    return map(n, alignment, tag);
}
```

Avoids an extra heap allocation for context by encoding the value directly
in the pointer. Only safe for values that fit in a pointer. *[Ghostty]*

### Anonymous Struct C Callback Wrapper

Wrap inline functions as C callbacks via anonymous struct:

```zig
c.spvc_context_set_error_callback(
    ctx,
    @ptrCast(&(struct {
        fn callback(_: ?*anyopaque, msg: [*c]const u8) callconv(.c) void {
            log.err("SPIR-V error: {s}", .{msg});
        }
    }).callback),
    null,
);
```

Creates a function pointer to a static function defined inline. The anonymous
struct exists only at comptime — no runtime overhead. *[Ghostty]*

### Bidirectional Allocator Wrapper

Bridge between C and Zig allocator interfaces:

```zig
pub const Allocator = extern struct {
    ctx: *anyopaque,
    vtable: *const VTable,

    /// Wrap a Zig allocator for C consumption
    pub fn fromZig(zig_alloc: *const std.mem.Allocator) Allocator {
        return .{
            .ctx = @ptrCast(@constCast(zig_alloc)),
            .vtable = &ZigAllocator.vtable,
        };
    }

    /// Wrap this C allocator for Zig consumption
    pub fn zig(self: *const Allocator) std.mem.Allocator {
        return .{
            .ptr = @ptrCast(@constCast(self)),
            .vtable = &zig_vtable,
        };
    }
};
```

Enables passing allocators across the C/Zig boundary in either direction.
*[Ghostty]*

## 11. Additional Official 0.17 Patterns

### Heap Allocation Failure Philosophy

Zig's convention: **handle OOM, don't crash**. Per the official docs:

- `error.OutOfMemory` is a recoverable error, not a panic.
- This makes libraries reusable in embedded, real-time, and non-overcommit contexts.
- Linux overcommit masks OOM bugs; handling OOM correctly makes code portable.
- Each allocator failure returns `error.OutOfMemory` — propagate it.

*[Official docs]*

### Sentinel-Terminated Pointers and Arrays

Zig provides compile-time overflow protection via sentinel-terminated types:

```zig
// Sentinel-terminated pointer: length determined by sentinel value
const name: [*:0]const u8 = "hello";   // pointer to null-terminated string

// Sentinel-terminated array: fixed length + sentinel
const str: [5:0]u8 = "hello".*;        // array with guaranteed 0 byte after

// Sentinel-terminated slice
const slice: [:0]const u8 = "hello";    // slice with guaranteed 0 after

// Compile-time check: passing non-null-terminated to null-terminated is error
// fn printf(fmt: [*:0]const u8, ...) — rejects non-null-terminated strings
```

Use `[*:0]T` and `[:0]T` for C interop with null-terminated strings. The compiler
verifies sentinel presence at compile time. *[Official docs]*

### `for` + `else` and `while` + `else` Patterns

`for` and `while` loops support `else` clauses that execute when the loop exits
without `break`:

```zig
// for + else: check if a value was found
const found = for (items) |item| {
    if (item == target) break true;
} else false;

// while + else: search with early exit
fn rangeHasNumber(begin: usize, end: usize, number: usize) bool {
    var i = begin;
    return while (i < end) : (i += 1) {
        if (i == number) break true;
    } else false;
}

// while with continue expression
var i: usize = 0;
while (i < 10) : (i += 1) {
    // i increments on each continue (but NOT on break)
}
```

`break` from a `while` loop can carry a value; `else` receives that value if no
`break` occurred. The continue expression (`: (expr)`) runs on `continue`, not
on `break`. *[Official docs]*

### `inline for` / `inline while` for Comptime Unrolling

Forcibly unroll loops at compile time. Capture values become comptime-known:

```zig
inline for (std.meta.fields(MyStruct)) |field| {
    // field.name, field.type are comptime-known
    // Can use types as first-class values here
}
```

Only use when: (1) semantics require comptime execution, or (2) benchmarks
prove it's faster. *[Official docs]*

### `@branchHint` for Hot/Cold Paths

```zig
fn abort() noreturn {
    @branchHint(.cold);   // Optimizer deprioritizes this path
    while (true) {}
}

pub inline fn branchless_select(
    comptime T: type, flag: bool, a: T, b: T
) T {
    @branchHint(.unpredictable);
    return if (flag) a else b;
}
```

Use `.cold` for error paths and abort handlers; `.unpredictable` for branchless
select patterns. *[Official docs, TigerBeetle]*

### `@constCast` and `@volatileCast`

```zig
// @constCast: explicit const removal (preferred over @ptrCast for this)
const x: *const u8 = &data;
const y: *u8 = @constCast(x);

// @volatileCast: add/remove volatile qualifier
const v: *volatile u8 = @volatileCast(ptr);
```

`volatile` is for MMIO only — **not** for concurrency (use Atomics). *[Official docs]*

### Non-Exhaustive Enums

Prevent exhaustive switching across library boundaries:

```zig
const Color = enum(u8) {
    red,
    green,
    blue,
    _,  // Trailing _ makes enum non-exhaustive
};
// Switch on Color requires else clause
```

Use non-exhaustive enums for C interop enums and stable library APIs where
new variants may be added. *[Official docs]*

### `@errorFromInt` / `@intFromError` / `@setRuntimeSafety`

```zig
// Convert between error codes and integers (for serialization)
const code = @intFromError(error.SomeError);
const err = @errorFromInt(code);

// Per-block safety toggle
@setRuntimeSafety(false);  // Disable safety checks for this block
const result = unsafeOperation();
@setRuntimeSafety(true);
```

### Doc Comment Guidance

```zig
//! Top-level module documentation (at start of namespace)

/// Documentation for the following declaration (struct, fn, field, etc.)
pub fn doSomething() void { ... }
```

Doc comments are **compile-error** if placed in unexpected positions.
*[Official docs]*
