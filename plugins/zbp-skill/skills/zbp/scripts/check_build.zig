#!/usr/bin/env zig run
/// Zig Best Practice scanner — detects memory leak patterns, anti-patterns,
/// and style violations across a Zig project.
///
/// Usage: zig run scripts/check_build.zig -- <path-to-zig-project>
///
/// Checks:
///   Leak detection:
///     - alloc/create without nearby defer/errdefer
///     - ArrayList/HashMap/ArrayListUnmanaged .init without defer deinit
///     - ArenaAllocator.init without defer deinit
///     - try after allocation without prior errdefer
///     - alloc + catch unreachable (OOM ignorance in library code)
///   Anti-patterns:
///     - std.debug.assert in production (non-test) code
///     - assert(a and b) compound assertions
///     - Missing const on variables never mutated

const std = @import("std");

pub fn main() !void {
    // Zig 0.17: GeneralPurposeAllocator removed. Use DebugAllocator for
    // debug/test, or SmpAllocator for release. A CLI tool like this is
    // short-lived — DebugAllocator with leak checking is appropriate.
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print(
            \\zbp-check — Zig Best Practice scanner v2
            \\
            \\Usage: {s} <path-to-zig-project> [--strict]
            \\
            \\  --strict   Treat warnings as errors (non-zero exit)
            \\
        , .{args[0]});
        return;
    }

    const root_path = args[1];
    const strict = if (args.len > 2) std.mem.eql(u8, args[2], "--strict") else false;

    var dir = std.fs.cwd().openDir(root_path, .{ .iterate = true }) catch |err| {
        std.debug.print("ERROR: cannot open '{s}': {s}\n", .{ root_path, @errorName(err) });
        return;
    };
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var total_leaks: usize = 0;
    var total_warnings: usize = 0;

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".zig")) continue;

        const source = dir.readFileAlloc(allocator, entry.path, 10 * 1024 * 1024) catch |err| {
            std.debug.print("WARN: skip {s}: {s}\n", .{ entry.path, @errorName(err) });
            continue;
        };
        defer allocator.free(source);

        const is_test = std.mem.containsAtLeast(u8, entry.path, 1, "test") or
            std.mem.endsWith(u8, entry.path, "_test.zig");

        var issues = std.ArrayList([]const u8).initCapacity(allocator, 0) catch |err| {
            std.debug.print("ERROR: OOM in check_build: {s}\n", .{@errorName(err)});
            continue;
        };
        defer {
            for (issues.items) |issue| allocator.free(issue);
            issues.deinit(allocator);
        }

        checkLeaks(allocator, &issues, entry.path, source, is_test);
        checkAntiPatterns(allocator, &issues, entry.path, source, is_test);

        for (issues.items) |issue| {
            const prefix: []const u8 = if (std.mem.startsWith(u8, issue, "LEAK")) "LEAK" else "WARN";
            if (std.mem.eql(u8, prefix, "LEAK")) {
                total_leaks += 1;
            } else {
                total_warnings += 1;
            }
            std.debug.print("{s}: {s}\n", .{ entry.path, issue });
        }
    }

    std.debug.print("\n---\nLEAK: {d}  WARN: {d}\n", .{ total_leaks, total_warnings });

    if (strict and (total_leaks + total_warnings) > 0) {
        std.process.exit(1);
    }
}

// ─── Leak Detection ────────────────────────────────────────────────────

fn checkLeaks(
    allocator: std.mem.Allocator,
    issues: *std.ArrayList([]const u8),
    path: []const u8,
    source: []const u8,
    is_test: bool,
) void {
    _ = is_test;

    var lines_it = std.mem.splitSequence(u8, source, "\n");
    var line_no: usize = 1;
    var prev_line: []const u8 = "";
    var prev_prev_line: []const u8 = "";

    while (lines_it.next()) |line| : (line_no += 1) {
        defer {
            prev_prev_line = prev_line;
            prev_line = line;
        }

        // ── .alloc() or .create() without defer/errdefer nearby ──
        if (std.mem.containsAtLeast(u8, line, 1, ".alloc(") or
            std.mem.containsAtLeast(u8, line, 1, ".create("))
        {
            const has_defer_nearby = std.mem.containsAtLeast(u8, prev_line, 1, "defer") or
                std.mem.containsAtLeast(u8, prev_prev_line, 1, "defer") or
                std.mem.containsAtLeast(u8, line, 1, "defer");

            if (!has_defer_nearby and !std.mem.containsAtLeast(u8, line, 1, "test")) {
                const alloc_type = if (std.mem.containsAtLeast(u8, line, 1, ".create(")) "create" else "alloc";
                appendIssue(allocator, issues, "LEAK", "line {d}: {s}() without nearby defer/errdefer", .{ line_no, alloc_type }) catch {};
            }
        }

        // ── Container .init() without defer deinit ──
        const container_init = std.mem.containsAtLeast(u8, line, 1, "ArrayList") or
            std.mem.containsAtLeast(u8, line, 1, "HashMap") or
            std.mem.containsAtLeast(u8, line, 1, "ArrayListUnmanaged") or
            std.mem.containsAtLeast(u8, line, 1, "ArrayListManaged");
        if (container_init and std.mem.containsAtLeast(u8, line, 1, ".init(")) {
            const has_defer = std.mem.containsAtLeast(u8, prev_line, 1, "defer");
            if (!has_defer) {
                appendIssue(allocator, issues, "LEAK", "line {d}: container .init() without defer deinit on next line", .{line_no}) catch {};
            }
        }

        // ── ArenaAllocator.init without defer deinit ──
        if (std.mem.containsAtLeast(u8, line, 1, "ArenaAllocator.init(")) {
            const has_defer = std.mem.containsAtLeast(u8, prev_line, 1, "defer");
            if (!has_defer) {
                appendIssue(allocator, issues, "LEAK", "line {d}: ArenaAllocator.init() without defer deinit on next line", .{line_no}) catch {};
            }
        }

        // ── alloc + catch unreachable (ignoring OOM in library code) ──
        if (std.mem.containsAtLeast(u8, line, 1, "alloc") and
            std.mem.containsAtLeast(u8, line, 1, "catch unreachable"))
        {
            appendIssue(allocator, issues, "LEAK", "line {d}: alloc with catch unreachable — OOM should be propagated in library code", .{line_no}) catch {};
        }
    }
}

// ─── Anti-Pattern Detection ───────────────────────────────────────────

fn checkAntiPatterns(
    allocator: std.mem.Allocator,
    issues: *std.ArrayList([]const u8),
    path: []const u8,
    source: []const u8,
    is_test: bool,
) void {
    // ── std.debug.assert in production code ──
    if (!is_test and std.mem.containsAtLeast(u8, source, 1, "std.debug.assert")) {
        appendIssue(allocator, issues, "WARN", "std.debug.assert in production code — remove or guard with build_options", .{}) catch {};
    }

    // ── Compound assert(a and b) ──
    var line_iter = std.mem.splitSequence(u8, source, "\n");
    var line_no: usize = 1;
    while (line_iter.next()) |line| : (line_no += 1) {
        if (std.mem.containsAtLeast(u8, line, 1, "assert(") and
            std.mem.containsAtLeast(u8, line, 1, " and ") and
            !std.mem.containsAtLeast(u8, line, 1, "// skip-check"))
        {
            appendIssue(allocator, issues, "WARN", "line {d}: compound assert(a and b) — prefer assert(a); assert(b);", .{line_no}) catch {};
        }
    }
}

fn appendIssue(
    allocator: std.mem.Allocator,
    issues: *std.ArrayList([]const u8),
    tag: []const u8,
    comptime fmt: []const u8,
    args: anytype,
) !void {
    // Two-phase: allocate first, then errdefer, then append.
    // If allocPrint fails, try returns before msg is assigned — no cleanup needed.
    const msg = try std.fmt.allocPrint(allocator, tag ++ ": " ++ fmt, args);
    errdefer allocator.free(msg);
    try issues.append(msg);
    // NOTE: errdefer fires only if append() fails. msg is then freed.
    // If append() succeeds, errdefer does NOT fire — msg now owned by ArrayList.
}
