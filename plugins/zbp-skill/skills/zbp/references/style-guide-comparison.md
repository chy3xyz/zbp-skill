# Zig Style Guide Comparison

## Official Zig Style Guide vs TigerBeetle Conventions

Zig's [official style guide](https://ziglang.org/documentation/master/#Style-Guide)
differs from TigerBeetle's in several areas. The skill presents TigerBeetle
conventions (derived from the largest Zig production codebase) annotated with
official guidance.

### Function Naming

| Aspect | Official Zig | TigerBeetle |
|--------|-------------|-------------|
| Functions | `camelCase` | `snake_case` |
| Types | `TitleCase` | `PascalCase` (same) |
| Variables | `snake_case` | `snake_case` |
| Constants | `snake_case` or `SCREAMING_SNAKE_CASE` | `snake_case` |
| Namespace structs (0 fields) | `snake_case` | N/A |
| Callable returning type | `TitleCase` | `PascalCase` |
| Files (types) | `TitleCase` | `snake_case` |
| Files (namespaces) | `snake_case` | `snake_case` |
| Directories | `snake_case` | `snake_case` |
| Indentation | 4 spaces | 4 spaces |
| Brace style | Same line | Same line |
| Line length | Aim for 100 | ~100 |
| Doc comments | `///` for decls, `//!` for modules | `///` for decls |

### Official Rules from Zig 0.17 Docs

The [Names section](https://ziglang.org/documentation/master/#Names) lays out
precise rules:

1. If `x` is a **struct with 0 fields** and never meant to be instantiated → `x` is a "namespace" → `snake_case`
2. If `x` is a **type or type alias** → `TitleCase`
3. If `x` is **callable and returns `type`** → `TitleCase`
4. If `x` is **otherwise callable** → `camelCase`
5. Otherwise → `snake_case`

**Acronyms**: Follow same capitalization rules. Even 2-letter acronyms.
Official: `VsrState`, `IoCompletion`. TigerBeetle uses: `VSRState`, `IOCompletion`.

### Redundancy Rules (Official)

- **Avoid these words in type names**: `Value`, `Data`, `Context`, `Manager`, `State`
- **No**: `utils`, `misc`, or somebody's initials — indicates categorization failure
- **No underscore prefixes** for visibility — Zig has no visibility name mangling
Bun, libxev, Ghostty all use `snake_case`). When contributing to an existing
codebase, follow its convention. For new projects, pick one and be consistent.

### Field Name Ordering

**TigerBeetle**: Units/qualifiers last, sorted by descending significance:
```zig
latency_ms_max    // not: max_latency_ms
latency_ms_min    // lines up with latency_ms_max
offset_bytes      // unit last
accounts_count    // qualifier last
```

**Official**: No specific rule for field ordering. The avoid-redundancy rule
implies keeping names short but descriptive.

### Variable Declaration

**Official**: "Use `const` rather than `var` when declaring a variable. This
causes less work for both humans and computers."

**TigerBeetle**: Follows this strictly. All variables are `const` by default;
`var` only when mutation is required.

### Visibility

**Official**: "Refrain from Underscore Prefixes." No `_private` or `_internal`.
Zig has no visibility-based name mangling.

**TigerBeetle**: No underscore prefixes for visibility. Uses `pub` judiciously.

### Redundancy

**Official**: "Avoid Redundancy in Names" — don't repeat type information.

```zig
// BAD: repeats type info
const value_i32: i32 = 0;

// GOOD
const value: i32 = 0;
```

**TigerBeetle**: Adds "units last" rule for disambiguation:
```zig
latency_ms: u64     // OK — "ms" is a unit qualifier, not type repetition
count_total: u32    // OK — "total" is a semantic qualifier
```

### Documentation Comments

**Official**:
- `///` for documentation on the declaration that follows
- `//!` for module-level documentation at the top of a namespace
- "Doc comments are only allowed in certain places; it is a compile error to
  have a doc comment in an unexpected place."

**TigerBeetle**: Uses `///` extensively. Each public function has a doc comment
describing parameters, return values, and invariants.

### Indentation

**Official**: 4-space indentation. No tabs.

**TigerBeetle**: 4-space indentation. Consistent with official.

### Assertions as Documentation (TigerBeetle-Specific)

Not in the official style guide but a TigerBeetle convention:
- Minimum 2 assertions per function.
- Split compound assertions: `assert(a); assert(b);` not `assert(a and b);`.
- Single-line implication: `if (a) assert(b);`.
- State invariants positively: `if (index < length)` not `if (index >= length)`.

### Struct Member Ordering (TigerBeetle-Specific)

Not in the official style guide:
- Fields first, then types, then methods.
- Public items before private items.
- `deinit` immediately follows `init` for visual pairing.

### Import Order (TigerBeetle-Specific)

Not in the official style guide:
1. Zig builtins: `builtin`, `std`
2. Extended stdlib utilities
3. Commonly used members: `assert`, `mem`
4. Project modules
5. Type aliases

### Callback Position

**TigerBeetle**: Callback parameters go **last** in parameter lists.

```zig
pub fn read(
    self: *IO,
    comptime Context: type,
    context: Context,
    comptime callback: fn (Context, *Completion, Error!usize) void,  // last
    completion: *Completion,
) void { ... }
```

### Allocator Position

**Official**: Convention passes allocator as the first argument.

**TigerBeetle**: Same. Allocator is always the first parameter in `init` and
`deinit` functions.

## When to Deviate from Official

The official style guide is for the Zig standard library and compiler. Production
codebases often adopt conventions optimized for their domain:

1. **`snake_case` functions** — Dominant in the ecosystem (TigerBeetle, Bun, Ghostty,
   libxev). The ergonomic advantage is consistency with the C FFI world.
2. **Units-last naming** — Not official but immensely useful for codebases with
   many time/size/count values.
3. **Assertions-as-documentation** — TigerBeetle-specific but valuable for
   correctness-critical code.

**Rule of thumb**: Follow the convention of the codebase you're in. For greenfield
projects, `snake_case` + TigerBeetle conventions give you the most community
alignment.
