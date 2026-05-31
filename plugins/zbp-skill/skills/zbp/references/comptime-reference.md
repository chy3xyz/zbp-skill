# Zig Comptime — Official 0.17 Reference

Extracted from the [Zig 0.17 (dev) Language Reference](https://ziglang.org/documentation/master/).

## Core Concept

Zig distinguishes compile-time-known vs runtime-known expressions. Types are
**first-class citizens**: they can be assigned to variables, passed as parameters,
and returned from functions — but only in compile-time-known expressions.

## Compile-Time Parameters (`comptime T: type`)

How Zig implements generics — **compile-time duck typing**.

```zig
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}
```

Rules:
- At the call site, the value **must** be comptime-known (compile error otherwise).
- In the function body, the value **is** comptime-known.
- If the type doesn't support the operations used, you get a compile error at the
  call site (not when the generic function is defined).

```zig
// Compile error: cannot pass runtime value to comptime parameter
fn foo(condition: bool) void {
    const result = max(if (condition) f32 else u64, 1234, 5678);
    // ERROR: unable to resolve comptime value
}

// Compile error: operator > not allowed for type 'bool'
_ = max(bool, true, false);
```

## `anytype` — Compile-Time Duck Typing Without Comptime Parameter

```zig
fn addFortyTwo(x: anytype) @TypeOf(x) {
    return x + 42;
}
```

Compiles for any type supporting `+ 42`. Use `@TypeOf` and `@typeInfo` to introspect
the inferred type.

## Compile-Time Variables (`comptime var`)

Guarantees that **every** load and store happens at compile time. Violation = compile
error. Combined with `inline` loops, enables partial evaluation:

```zig
fn performFn(comptime prefix_char: u8, start_value: i32) i32 {
    var result: i32 = start_value;
    comptime var i = 0;
    inline while (i < cmd_fns.len) : (i += 1) {
        if (cmd_fns[i].name[0] == prefix_char) {
            result = cmd_fns[i].func(result);
        }
    }
    return result;
}
```

The compiler generates **separate specialized functions** for each `prefix_char`
value. This is not primarily for optimization — it's for correctness: ensuring
compile-time computation actually happens at compile time.

## Compile-Time Expressions (`comptime { }`)

Within a `comptime` block:
- All variables are comptime variables.
- All `if`, `while`, `for`, `switch` evaluated at compile time (or compile error).
- `return` and `try` are **invalid** (unless function is called at compile time).
- Code with runtime side effects emits a compile error.
- All function calls cause the compiler to **interpret** the function at compile time.

```zig
// Function works at both compile-time and runtime, no modification needed:
fn fibonacci(index: u32) u32 {
    if (index < 2) return index;
    return fibonacci(index - 1) + fibonacci(index - 2);
}

test "fibonacci" {
    try expectEqual(13, fibonacci(7));          // runtime
    try comptime expectEqual(13, fibonacci(7)); // comptime
}
```

## Generic Data Structures

Functions returning `type` produce named generic structs:

```zig
fn List(comptime T: type) type {
    return struct {
        items: []T,
        len: usize,
    };
}

var buffer: [10]i32 = undefined;
var list = List(i32){ .items = &buffer, .len = 0 };
```

The compiler infers the name `List(i32)` from the function name + parameters.
Functions called at compile time are **memoized** — `LinkedList(i32) == LinkedList(i32)`.

Self-referential structs work because top-level declarations are order-independent:

```zig
const Node = struct {
    next: ?*Node,   // OK — pointer size known at compile time
    name: []const u8,
};
```

## `inline fn`

`inline` makes a function **semantically inlined** at the call site. This is NOT
an optimization hint — it changes semantics:

- Arguments that are comptime-known at the call site become **Compile-Time Parameters**
  inside the function.
- This propagates comptime-ness to the return value.

```zig
inline fn foo(a: i32, b: i32) i32 {
    return a + b;
}

// If a and b are comptime-known, return value is also comptime-known
if (foo(1200, 34) != 1234) {
    @compileError("bad");  // Evaluated at compile time
}
```

**When to use `inline`:**
1. Force comptime propagation of arguments to return value.
2. Change stack frame count (debugging).
3. Real-world benchmarks prove it helps.

**Caveat**: `inline` **restricts** what the compiler can do — it may harm binary
size, compilation speed, and runtime performance. Let the compiler decide unless
one of the three reasons above applies.

## Comptime Reflection

```zig
// Check if a type has a declaration
if (@hasDecl(T, "reset")) { ... }

// Check if a type has a field
if (@hasField(T, "field_name")) { ... }

// Full type introspection
switch (@typeInfo(T)) {
    .@"struct" => |s| {
        inline for (s.fields) |f| { ... }
    },
    else => {},
}

// Inspect function signatures
const return_type = @typeInfo(@TypeOf(myFn)).@"fn".return_type;
```

## `@setEvalBranchQuota`

Increase comptime evaluation budget for complex reflection:

```zig
@setEvalBranchQuota(32_000);
inline for (std.meta.fields(LargeStruct)) |field| {
    // process each field
}
```

## Common Pitfalls

1. **Inferred error sets** make a function generic — no function pointers, no recursion.
2. **Comptime parameters** can't be runtime values — `max(if(x) f32 else u64, ...)` fails.
3. **`inline fn`** restricts the compiler — use sparingly.
4. **Comptime memoization** means two calls with same args return the same type.
5. **`@compileError`** in untaken branches is fine — compiler only analyzes taken paths.

## See Also

- SKILL.md §4: Comptime & Generics patterns
- Official: [comptime](https://ziglang.org/documentation/master/#comptime)
- Official: [Builtin Functions](https://ziglang.org/documentation/master/#Builtin-Functions)
