# Zig Memory Management — Official 0.17 Reference

Extracted from the [Zig 0.17 (dev) Language Reference](https://ziglang.org/documentation/master/).

## Choosing an Allocator

Per the official docs decision flow:

### Library
Accept `Allocator` as a parameter. Let the user decide.

### Linking libc
`std.heap.c_allocator` is the right choice for the main allocator.

### Compile-time bounded max bytes
`std.heap.FixedBufferAllocator` — uses a fixed backing buffer.

### CLI app, run-to-completion (no cyclical pattern)
`ArenaAllocator` — one `deinit()` frees everything:

```zig
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    // No need to free anything manually — arena.deinit() handles all.
    const ptr = try allocator.create(i32);
}
```

### Cyclical pattern (game loop, web request handler)
`ArenaAllocator` per cycle. Combine with `FixedBufferAllocator` if upper memory
bound is known.

### Testing OOM correctness
`std.testing.FailingAllocator` — simulates allocation failures.

### Testing general
`std.testing.allocator` — leak detection built in.

### General purpose, Debug mode
`std.heap.DebugAllocator` — configurable via comptime options. Set up one in `main`,
pass it or sub-allocators around.

### General purpose, ReleaseFast mode
`std.heap.smp_allocator` — solid choice for multi-threaded performance.

## Lifetime and Ownership

The Zig programmer is responsible for ensuring pointers are not accessed after
the memory is no longer available. A **slice is a form of pointer** — it references
other memory.

### Conventions

When a function returns a pointer, the **documentation must explain who "owns" it**:

| Ownership | Implication |
|-----------|-------------|
| "caller owns" | Caller must free; function should accept `Allocator` |
| "callee owns" | Don't free; valid until callee says otherwise |
| "borrowed" | Pointer valid for duration of some scope |

### Lifetime Examples

`std.ArrayList(T).items` — valid until the next time the list is resized (e.g.,
by appending elements). Document this carefully.

## Heap Allocation Failure

Zig's convention: **handle OOM, don't crash**.

`error.OutOfMemory` represents heap allocation failure. Libraries return this
error code when allocation prevents an operation from completing.

### Why Not Just Crash?

The official docs rebut "just crash on OOM" arguments:

1. **Not all OSes overcommit.** Linux has it (configurable), Windows doesn't,
   embedded systems don't, real-time systems pre-allocate.
2. **Library reuse.** Correct OOM handling makes a library reusable across all
   contexts — embedded, real-time, non-overcommit.
3. **Overcommit is bad UX.** When Linux nears memory exhaustion, the system
   locks up, then the OOM Killer kills a random process based on heuristics.
   Non-deterministic, often kills critical processes, often fails to recover.

### Pattern

```zig
fn init(allocator: Allocator) error{OutOfMemory}!Self {
    const buffer = try allocator.alloc(u8, size);
    errdefer allocator.free(buffer);
    // ...
}
```

Never `catch unreachable` on allocation failures in library code.

## Struct Layout

### `struct` (default)
- Zig gives **no guarantees** about field order or struct size.
- Fields are guaranteed to be **ABI-aligned**.
- Compiler may reorder fields for optimal layout.
- Use for normal application data.

### `extern struct`
- In-memory layout matches the **C ABI** for the target.
- Fields not reordered; predictable layout.
- Use for: C interop, wire/disk formats, FFI.

```zig
pub const Header = extern struct {
    magic: u32,
    version: u16,
    flags: u16,
    // No compiler reordering
};
```

### `packed struct`
- Based on interpreting integers differently. Has a **backing integer** — implicitly
  determined by total bit count of fields, or explicitly provided.
- Well-defined memory layout: exactly the ABI of the backing integer.
- Fields arranged **least to most significant** bits.
- Participates in `@bitCast` and `@ptrCast` (even at comptime).

```zig
const Full = packed struct { number: u16 };
const Divided = packed struct { half1: u8, quarter3: u4, quarter4: u4 };

// Reinterpret via bitCast:
const full = Full{ .number = 0x1234 };
const divided: Divided = @bitCast(full);
// divided.half1 == 0x34, divided.quarter3 == 0x2, divided.quarter4 == 0x1
```

**Allowed field types in packed structs:**
- Integer fields: use exactly `bit_width` bits.
- `bool`: exactly 1 bit.
- Enum fields: bit width of integer tag type.
- Packed union fields: bit width of largest union field.
- Nested packed struct fields: bits of their backing integer.

**Backing integer rules:**
- Inferred: always unsigned, bit width matches total field bits.
- Explicit: compile error if bit width ≠ total field bits.
- Example: `packed struct(u32) { a: u16, b: u8 }` — ERROR (16+8=24 ≠ 32).

### Faulty Default Field Values

```zig
const S = struct {
    a: u32 = 0,
    b: u32,
};
// S{ .b = 1 } — OK, a defaults to 0
// S{ .a = 1 } — ERROR, b needs explicit value
```

Default field values are **not defaults in the traditional sense** — they only
apply when the field is not provided. If you provide all fields, defaults are
ignored. This can mask initialization bugs.

## Pointers to Structs

When using a pointer to a struct, fields can be accessed directly without
explicit dereference:

```zig
const list2 = List{ .first = &node, .last = &node, .len = 1 };
try expectEqual(1234, list2.first.?.data);
// Not: list2.first.?.*.data
```

## See Also

- SKILL.md §1: Memory Safety patterns
- SKILL.md §5: Memory Layout & Copy Safety
- Official: [Memory](https://ziglang.org/documentation/master/#Memory)
- Official: [struct](https://ziglang.org/documentation/master/#struct)
- Official: [Choosing an Allocator](https://ziglang.org/documentation/master/#Choosing-an-Allocator)
