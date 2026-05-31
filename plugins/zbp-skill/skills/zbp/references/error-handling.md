# Zig Error Handling — Official 0.17 Semantics

Extracted from the [Zig 0.17 (dev) Language Reference](https://ziglang.org/documentation/master/).

## Error Set Type

An error set is like an `enum`. Each error name across the entire compilation gets
assigned an unsigned integer > 0. The same error name declared more than once gets
the same integer value.

Error set type defaults to `u16`. Pass `--error-limit [num]` to override.

### Coercion Rules

**Subset → Superset: OK.** Coerce from a smaller error set to a larger one:

```zig
const FileOpenError = error{ AccessDenied, OutOfMemory, FileNotFound };
const AllocationError = error{ OutOfMemory };

fn foo(err: AllocationError) FileOpenError {
    return err;  // OK — OutOfMemory is in FileOpenError
}
```

**Superset → Subset: COMPILE ERROR.** Cannot coerce to a smaller error set:

```zig
fn foo(err: FileOpenError) AllocationError {
    return err;  // ERROR: AccessDenied, FileNotFound not in AllocationError
}
```

**Single-error shortcut**: `error{x}` is equivalent to `error{x}`.

## Error Union Type

Formed with `!` binary operator: `!T` or `E!T`.

```zig
pub fn parseU64(buf: []const u8, radix: u8) !u64 {
    // ... return error.InvalidChar;  or  return x;
}
```

The return type `!u64` means the error set is **inferred** (the compiler determines
which errors can be returned). `anyerror!u64` means any error.

Five ways to handle an error union:

| Method | Use Case |
|--------|----------|
| `catch default_value` | Provide fallback |
| `catch |err| return err` | Propagate |
| `try expr` | Shortcut for propagate |
| `catch unreachable` | Proven impossible (crashes in Debug/ReleaseSafe) |
| `if (expr) \|v\| { } else \|err\| switch(err) { }` | Handle each error |

### catch

```zig
const number = parseU64(str, 10) catch 13;

// With block:
const number = parseU64(str, 10) catch blk: {
    // complex fallback logic
    break :blk 13;
};
```

### try

```zig
const number = try parseU64(str, 10);
// Equivalent to:
// const number = parseU64(str, 10) catch |err| return err;
```

### catch unreachable

```zig
const number = parseU64("1234", 10) catch unreachable;
```

`unreachable` invokes safety-checked Illegal Behavior. In Debug/ReleaseSafe, triggers
a safety panic. In ReleaseFast/ReleaseSmall, undefined behavior.

### Exhaustive Error Handling

```zig
if (parseU64(str, 10)) |number| {
    doSomethingWithNumber(number);
} else |err| switch (err) {
    error.Overflow => { /* handle overflow */ },
    error.InvalidChar => unreachable,
}
```

### Handling Some Errors

```zig
if (parseU64(str, 10)) |number| {
    doSomethingWithNumber(number);
} else |err| switch (err) {
    error.Overflow => { /* handle overflow */ },
    else => |leftover_err| return leftover_err,
}
```

## errdefer

Executes the deferred expression **only** when the function returns with an error
from the block:

```zig
fn createFoo(param: i32) !Foo {
    const foo = try tryToAllocateFoo();
    errdefer deallocateFoo(foo);  // runs only on error

    const tmp_buf = allocateTmpBuffer() orelse return error.OutOfMemory;
    defer deallocateTmpBuffer(tmp_buf);  // runs unconditionally

    if (param > 1337) return error.InvalidParam;
    // errdefer does NOT run (success path), but defer DOES run
    return foo;
}
```

Key properties:
- Deallocation code directly follows allocation code — robust, readable.
- Error checking is compile-error if omitted (`catch unreachable` is explicit).
- Zig pre-weights branches in favor of errors not occurring (small optimization).

## defer

Executes unconditionally at scope exit. **Reverse order** of appearance:

```zig
defer { print("1 ", .{}); }
defer { print("2 ", .{}); }
// Prints: "2 1"
```

`return` is **not allowed** inside a defer expression — compile error.

Defers inside untaken branches (e.g., `if (false)`) never execute.

## Merging Error Sets

Use `||` to merge two error sets:

```zig
const A = error{ NotDir, PathNotFound };
const B = error{ OutOfMemory, PathNotFound };
const C = A || B;
// C = error{NotDir, PathNotFound, OutOfMemory}
```

Doc comments from the **left-hand side** override those from the right. Critical
for comptime-branched error sets:

```zig
// Standard library uses:
const OpenError = LinuxFileOpenError || WindowsFileOpenError;
```

## Inferred Error Sets

Omit the error set left of `!` to let the compiler infer:

```zig
fn add(comptime T: type, a: T, b: T) !T { ... }
```

**Trade-offs:**
- Pro: Less typing, self-updating error sets.
- Con: Function becomes **generic** — trickier to get function pointers, error sets
  may differ across build targets.
- Con: **Incompatible with recursion**.
- Recommendation: Start with explicit error set, let compile errors guide additions.

## Error Return Traces

Show **all** points where an error was returned (not a stack trace):

```
error: PermissionDenied
  bang2.zig:38:5: return error.PermissionDenied;
  hello.zig:30:5: try bang2();
  bar.zig:17:31: error.FileNotFound => try hello();
  foo.zig:7:9: try bar();
  main.zig:2:5: try foo(12);
```

The trace shows the original error (`FileNotFound`) and the final error
(`PermissionDenied`), making error transformation chains clear.

## Compile-Time Error Type Assertions

```zig
comptime assert(@TypeOf(err) == error{OutOfMemory});
```

Catches drift when upstream functions change their error types. Use
`comptime` + `@typeInfo` for exhaustive error set checking.

## See Also

- SKILL.md §3: Error Handling patterns
- SKILL.md §1: errdefer chains for resource cleanup
- Official: [Errors](https://ziglang.org/documentation/master/#Errors)
- Official: [defer](https://ziglang.org/documentation/master/#defer)
- Official: [errdefer](https://ziglang.org/documentation/master/#errdefer)
