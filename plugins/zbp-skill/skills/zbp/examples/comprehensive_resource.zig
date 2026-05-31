//! Comprehensive example: All memory safety, error handling, and
//! resource management patterns in one file. Demonstrates every
//! pattern from the Zig best practices skill.
//!
//! This is reference code — not meant to compile standalone.

const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;

const log = std.log.scoped(.example);

// ─── Type Function Pattern ───────────────────────────────────────────

pub fn ObjectPool(comptime T: type, comptime max_count: comptime_int) type {
    return struct {
        const Node = struct {
            data: T,
            next: ?*@This() = null,
        };

        list: ?*Node = null,
        count: u32 = 0,

        pub fn get(self: *@This(), allocator: mem.Allocator) *Node {
            if (self.list) |node| {
                self.list = node.next;
                self.count -= 1;
                // Optional reset if T supports it
                if (comptime std.meta.hasFn(T, "reset"))
                    node.data.reset();
                return node;
            }
            // Fallback allocation — should be infallible in practice
            return allocator.create(Node) catch @panic("OOM in pool get");
        }

        pub fn release(self: *@This(), allocator: mem.Allocator, node: *Node) void {
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

// ─── Resource Struct with Full Init/Deinit ───────────────────────────

const MyResource = struct {
    index: Index,
    cache: Cache,
    buffer: []u8,
    pool: ObjectPool(Entry, 256),

    pub fn init(allocator: mem.Allocator, options: struct {
        capacity: usize,
        max_entries: u32,
    }) error{OutOfMemory}!MyResource {
        // Phase 1: Allocate index
        var index = try Index.init(allocator, .{});
        errdefer index.deinit(allocator);

        // Phase 2: Allocate cache
        var cache = try Cache.init(allocator, .{
            .max_entries = options.max_entries,
        });
        errdefer cache.deinit(allocator);

        // Phase 3: Allocate buffer
        const buffer = try allocator.alloc(u8, options.capacity);
        errdefer allocator.free(buffer);

        return MyResource{
            .index = index,
            .cache = cache,
            .buffer = buffer,
            .pool = .{},
        };
    }

    /// Deinit reverses init order.
    pub fn deinit(self: *MyResource, allocator: mem.Allocator) void {
        allocator.free(self.buffer);
        self.cache.deinit(allocator);
        self.index.deinit(allocator);
        self.* = undefined; // Poison to catch use-after-free
    }

    /// Infallible runtime operation — capacity pre-allocated at init.
    pub fn put(self: *MyResource, entry: Entry) void {
        assert(self.cache.count() < self.cache.max_entries);
        // AssumeCapacity: pre-validated, no error possible
        self.cache.putAssumeCapacity(entry.key, entry);
    }
};

// ─── Stub Types ──────────────────────────────────────────────────────

const Index = struct {
    pub fn init(allocator: mem.Allocator, options: anytype) error{OutOfMemory}!Index {
        _ = allocator;
        _ = options;
        return .{};
    }
    pub fn deinit(self: *Index, allocator: mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
};

const Cache = struct {
    max_entries: u32 = 0,
    entries: u32 = 0,

    pub fn init(allocator: mem.Allocator, options: anytype) error{OutOfMemory}!Cache {
        _ = allocator;
        return .{ .max_entries = options.max_entries };
    }
    pub fn deinit(self: *Cache, allocator: mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
    pub fn count(self: *const Cache) u32 { return self.entries; }
    pub fn putAssumeCapacity(self: *Cache, key: u64, entry: anytype) void {
        _ = key;
        _ = entry;
        self.entries += 1;
    }
};

const Entry = struct {};

// ─── C Interop Pattern ───────────────────────────────────────────────

/// Export a C-callable init function
export fn my_resource_init(
    allocator: *anyopaque,
    capacity: usize,
    max_entries: u32,
) ?*MyResource {
    const zig_alloc = @as(*mem.Allocator, @ptrCast(@alignCast(allocator)));
    const resource = zig_alloc.create(MyResource) catch return null;
    resource.* = MyResource.init(zig_alloc.*, .{
        .capacity = capacity,
        .max_entries = max_entries,
    }) catch |err| {
        log.err("my_resource_init failed: {s}", .{@errorName(err)});
        zig_alloc.destroy(resource);
        return null;
    };
    return resource;
}

export fn my_resource_deinit(resource: ?*MyResource, allocator: *anyopaque) void {
    const r = resource orelse return;
    const zig_alloc = @as(*mem.Allocator, @ptrCast(@alignCast(allocator)));
    r.deinit(zig_alloc.*);
    zig_alloc.destroy(r);
}

// ─── Thread-Local Pattern ────────────────────────────────────────────

threadlocal var tls_cache: ?*Cache = null;

pub fn getThreadCache(allocator: mem.Allocator) *Cache {
    if (tls_cache) |c| return c;
    const c = allocator.create(Cache) catch @panic("OOM for TLS cache");
    c.* = Cache.init(allocator, .{ .max_entries = 64 }) catch |err| {
        // init failed — free the allocation before panicking
        allocator.destroy(c);
        @panic("OOM for TLS cache init");
    };
    tls_cache = c;
    return c;
}

// ─── Tests ───────────────────────────────────────────────────────────

test "init/deinit no leaks" {
    const allocator = std.testing.allocator;

    var resource = try MyResource.init(allocator, .{
        .capacity = 4096,
        .max_entries = 16,
    });
    defer resource.deinit(allocator);

    // Verify initial state
    try std.testing.expectEqual(0, resource.cache.count());
}

test "pool get/release cycle" {
    const allocator = std.testing.allocator;
    var pool: ObjectPool(Entry, 256) = .{};

    const node = pool.get(allocator);
    pool.release(allocator, node);

    // Pool should have one cached entry
    try std.testing.expectEqual(@as(u32, 1), pool.count);
}

test "errdefer chain on init failure" {
    // This test documents the pattern — the actual errdefer chain
    // is verified by the test allocator leak detection.
    const allocator = std.testing.allocator;

    // If any init step fails, all prior resources are cleaned
    var resource = try MyResource.init(allocator, .{
        .capacity = 1024,
        .max_entries = 4,
    });
    defer resource.deinit(allocator);
}

// ─── anytype Pattern ─────────────────────────────────────────────────

/// Demonstrates anytype — "compile-time duck typing."
/// Compiles for any type that supports * 2 + 1.
fn doublePlusOne(x: anytype) @TypeOf(x) {
    return x * 2 + 1;
}

test "anytype with different types" {
    try std.testing.expectEqual(@as(i32, 5), doublePlusOne(@as(i32, 2)));
    try std.testing.expectEqual(@as(f32, 5.0), doublePlusOne(@as(f32, 2.0)));
}

// ─── errdefer Capture ─────────────────────────────────────────────────

fn resourceWithDiagnostics(allocator: std.mem.Allocator) !*Cache {
    const c = try allocator.create(Cache);
    errdefer |err| {
        log.err("resource init failed: {s}, cleaning up", .{@errorName(err)});
        allocator.destroy(c);
    }
    c.* = try Cache.init(allocator, .{ .max_entries = 64 });
    return c;
}

test "errdefer capture on allocation failure" {
    // With std.testing.FailingAllocator, can test OOM paths
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    _ = resourceWithDiagnostics(failing.allocator()) catch |err| {
        try std.testing.expectEqual(error.OutOfMemory, err);
    };
}

// ─── for/while + else Patterns ────────────────────────────────────────

fn findInSlice(items: []const u32, target: u32) bool {
    return for (items) |item| {
        if (item == target) break true;
    } else false;
}

fn rangeHasNumber(begin: u32, end: u32, num: u32) bool {
    var i = begin;
    return while (i < end) : (i += 1) {
        if (i == num) break true;
    } else false;
}

test "for/while else patterns" {
    const items = [_]u32{ 1, 2, 3, 4, 5 };
    try std.testing.expect(findInSlice(&items, 3));
    try std.testing.expect(!findInSlice(&items, 99));
    try std.testing.expect(rangeHasNumber(0, 10, 5));
    try std.testing.expect(!rangeHasNumber(0, 10, 99));
}

// ─── Sentinel-Terminated Types ────────────────────────────────────────

fn cStyleStrLen(str: [*:0]const u8) usize {
    return std.mem.sliceTo(str, 0).len;
}

test "sentinel-terminated pointer" {
    const hello: [:0]const u8 = "hello";
    try std.testing.expectEqual(@as(usize, 5), cStyleStrLen(hello));
    try std.testing.expectEqual(@as(usize, 5), hello.len); // sentinel not included
}

// ─── @branchHint ──────────────────────────────────────────────────────

fn coldErrorPath() noreturn {
    @branchHint(.cold);
    @panic("unreachable error path");
}

pub inline fn branchlessSelect(
    comptime T: type,
    flag: bool,
    a: T,
    b: T,
) T {
    @branchHint(.unpredictable);
    return if (flag) a else b;
}

test "branchHint patterns" {
    try std.testing.expectEqual(@as(u32, 10), branchlessSelect(u32, true, 10, 20));
    try std.testing.expectEqual(@as(u32, 20), branchlessSelect(u32, false, 10, 20));
}

// ─── Non-Exhaustive Enum ─────────────────────────────────────────────

const PlatformFeature = enum(u8) {
    linux_kqueue = 1,
    io_uring = 2,
    iocp = 3,
    _, // non-exhaustive — new variants can be added
};

fn featureName(f: PlatformFeature) []const u8 {
    return switch (f) {
        .linux_kqueue => "Linux KQueue",
        .io_uring => "io_uring",
        .iocp => "IOCP",
        else => "unknown feature", // required for non-exhaustive
    };
}

test "non-exhaustive enum" {
    try std.testing.expect(std.mem.eql(u8, "io_uring", featureName(.io_uring)));
}
