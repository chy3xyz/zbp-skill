# Memory Leak Prevention — Systematic Approach for AI-Generated Zig

## Why AI Leaks Memory in Zig

AI's default code generation patterns from other languages leak in Zig:

1. **RAII assumption** — AI writes `list: ArrayList(T) = .empty` then assumes cleanup
   is automatic. Zig has no destructors. Deinit must be explicit.
2. **Error-path blindness** — AI focuses on happy path, forgets cleanup on error.
3. **Early-return amnesia** — AI inserts early returns without cleanup.
4. **Copy-paste without adaptation** — AI copies patterns without their errdefer chains.

## The One Rule That Prevents 80% of Leaks

**Every allocation must have a `defer` or `errdefer` on the very next line.**

```zig
// BAD — no cleanup (Zig 0.17)
var list: std.ArrayList(u8) = .empty;
try list.append(allocator, 'x');

// GOOD — cleanup paired with allocation (Zig 0.17)
var list: std.ArrayList(u8) = .empty;
defer list.deinit(allocator);
try list.append(allocator, 'x');
```

Enforce this mechanically: after writing any `alloc`, `create`, or `.initCapacity(`,
immediately write its `defer` cleanup before writing any other code.

## Zig 0.17 API Changes

Zig 0.17 renamed/removed several init methods:

| Old (0.14–0.16) | New (0.17) |
|---|---|
| `ArrayList(T).init(alloc)` | `var list: ArrayList(T) = .empty;` |
| `ArrayList(T).init(alloc)` (with capacity) | `try ArrayList(T).initCapacity(alloc, n)` |
| `GeneralPurposeAllocator(.{}){}` | `std.heap.DebugAllocator(.{}){}` |
| `GeneralPurposeAllocator(.{}){}.allocator()` | `gpa.allocator()` (same, DebugAllocator) |
| `AutoHashMap(K,V).init(alloc)` | Still works in 0.17 |
| `ArenaAllocator.init(alloc)` | Still works in 0.17 |

## Taxonomy of Leak Patterns

### P1: Missing errdefer on Multi-Resource Init

Most common in AI code. Each `try` after an allocation needs `errdefer`:

```zig
// LEAK: if Cache.init fails, index is leaked
pub fn init(a: Allocator) !Self {
    var index = try Index.init(a);
    var cache = try Cache.init(a);      // index LEAKED if this fails
    return Self{ .index = index, .cache = cache };
}

// FIX: errdefer before each subsequent try
pub fn init(a: Allocator) !Self {
    var index = try Index.init(a);
    errdefer index.deinit(a);
    var cache = try Cache.init(a);
    errdefer cache.deinit(a);
    return Self{ .index = index, .cache = cache };
}
```

### P2: Container Without defer deinit

```zig
// LEAK (Zig 0.17)
var list: std.ArrayList(u32) = .empty;
try list.append(alloc, 42);
return list;  // No deinit, but no leak if caller takes ownership

// But this LEAKS:
var list: std.ArrayList(u32) = .empty;
try list.append(alloc, 42);
// ... function returns without deinit and without transferring ownership

// FIX:
var list: std.ArrayList(u32) = .empty;
defer list.deinit(alloc);
try list.append(alloc, 42);
```

### P3: Optional Resource Without defer if

```zig
// LEAK: if file is opened, it's never closed
var file: ?std.fs.File = null;
if (options.log) |path| {
    file = try std.fs.cwd().createFile(path, .{});
}
// ... file.close() never called

// FIX: defer if at declaration
var file: ?std.fs.File = null;
defer if (file) |f| f.close();
```

### P4: Loop Allocation Without Per-Iteration Free

```zig
// LEAK: allocates on every iteration, never frees
while (iter.next()) |item| {
    const buf = try alloc.alloc(u8, item.size);
    process(buf);
}

// FIX: free each iteration, or use arena
while (iter.next()) |item| {
    const buf = try alloc.alloc(u8, item.size);
    defer alloc.free(buf);
    process(buf);
}

// OR: arena for entire loop
var arena = std.heap.ArenaAllocator.init(alloc);
defer arena.deinit();
while (iter.next()) |item| {
    const buf = try arena.allocator().alloc(u8, item.size);
    process(buf);
}
```

### P5: Self-Referential Struct Cleanup

```zig
// LEAK: deiniting in wrong order, or missing nested deinit
pub fn deinit(self: *Self, a: Allocator) void {
    a.free(self.buffer);       // OK
    self.cache.deinit(a);      // OK
    self.index.deinit(a);      // OK
    // MISSING: self.* = undefined (poison)
}
```

### P6: Test Leaks

```zig
// LEAK: tests using non-testing allocator bypass leak detection
test "process" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const a = gpa.allocator();
    var list: std.ArrayList(u8) = .empty;
    // Missing defer list.deinit(a) AND using gpa instead of testing.allocator
}

// FIX: always use std.testing.allocator in tests
test "process" {
    const a = std.testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(a);
}
```

## Token-Efficient Verification Protocol

Before claiming any Zig code is done, execute in this order:

### Step 1: Mechanical Scan (0 tokens — run script)
```bash
zig run scripts/check_build.zig -- src/
```

### Step 2: Targeted grep (minimal tokens)
```bash
# Find allocations without nearby cleanup
grep -n '\.alloc\|\.create\|\.initCapacity(' src/*.zig | grep -v 'defer\|errdefer\|test'

# Find container init without defer deinit
grep -A1 '(ArrayList\|HashMap\|ArrayHashMap)' src/*.zig | grep -v 'defer'

# Find ArenaAllocator without defer deinit
grep -A1 'ArenaAllocator.init(' src/*.zig | grep -v 'defer'
```

### Step 3: Run Tests with Leak Detection (0 tokens — automated)
```bash
zig build test 2>&1 | grep -i 'leak\|error'
```

### Step 4: Manual Review (only if Steps 1-3 find issues)
Read each flagged function and verify:
- Every `alloc`/`create` has next-line `defer`
- Every `try` after allocation has prior `errdefer`
- Deinit order is reverse of init order
- `self.* = undefined` at end of deinit

## Design Patterns That Eliminate Leaks by Construction

### Pattern A: Arena for Request/Frame Scope

Instead of tracking individual allocations, use one arena per request:

```zig
pub fn handleRequest(a: std.mem.Allocator, req: Request) !Response {
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    const aa = arena.allocator();
    // Allocate freely — all freed at once on return
}
```

**Token cost**: 3 lines. **Leak risk**: zero.

### Pattern B: AssumeCapacity for Hot Paths

Pre-allocate at init, infallible at runtime:

```zig
// Init: allocate once, can fail
pub fn init(a: Allocator, max: u32) !Self {
    var map = std.AutoHashMap(u32, Value).init(a);
    try map.ensureTotalCapacity(max);
    return Self{ .map = map };
}

// Runtime: infallible, no allocation, no leak possible
pub fn put(self: *Self, key: u32, val: Value) void {
    self.map.putAssumeCapacity(key, val);
}
```

**Token cost**: 2 extra lines in init. **Leak risk**: zero at runtime.

### Pattern C: Owned vs Borrowed Convention

Document ownership in function signatures:

```zig
/// Caller owns the returned slice — must free with `allocator`.
pub fn encode(a: Allocator, data: []const u8) ![]u8 { ... }

/// Borrowed — caller must NOT free. Valid until next call.
pub fn view(self: *const Self) []const u8 { ... }
```

**Token cost**: 1 doc comment line. **Leak risk**: eliminated by convention.

## Token Efficiency Principles for Zig AI Prompts

1. **Prefer arena over manual tracking** — 3 lines of arena = dozens of individual defer/errdefer lines saved.
2. **Prefer AssumeCapacity over runtime allocation** — pre-allocate once, zero allocation at runtime.
3. **Use `defer` on the allocation line** — don't defer writing the defer.
4. **Group allocation + cleanup visually** — blank line before `var x = try ...`, `defer` on next line.
5. **Use `std.testing.allocator` in all tests** — automatic leak detection, zero manual checking.
6. **Write deinit immediately after init** — don't write the rest of the function first.
