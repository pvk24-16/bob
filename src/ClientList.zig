const std = @import("std");
const builtin = @import("builtin");

const ClientList = @This();

const library: struct {
    prefix: []const u8,
    suffix: []const u8,
} = switch (builtin.os.tag) {
    .linux => .{ .prefix = "lib", .suffix = ".so" },
    .macos => .{ .prefix = "lib", .suffix = ".dylib" },
    .windows => .{ .prefix = "", .suffix = ".dll" },
    else => @compileError("unsupported platform"),
};

path: []const u8,
list: std.ArrayList([*:0]const u8),

pub fn init(allocator: std.mem.Allocator, path_override: ?[]const u8) !ClientList {
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    const path = blk: {
        if (path_override) |override| {
            break :blk try allocator.dupe(u8, override);
        }

        switch (builtin.os.tag) {
            // Default path on Linux is $XDG_DATA_HOME/bob, or ~/.local/state/bob
            .linux => {
                const xdg_data_home = env.get("XDG_DATA_HOME");

                if (xdg_data_home) |path| {
                    break :blk try std.fs.path.join(allocator, &.{ path, "bob" });
                } else {
                    const home = env.get("HOME") orelse {
                        std.log.err("HOME is not defined", .{});
                        return error.missing_env;
                    };

                    break :blk try std.fs.path.join(allocator, &.{ home, ".local/share/bob" });
                }
            },

            // Default path on Windows is %LOCALAPPDATA%\bob
            .windows => {
                const localappdata = env.get("LOCALAPPDATA") orelse {
                    std.log.err("LOCALAPPDATA is not defined", .{});
                    return error.missing_env;
                };

                break :blk try std.fs.path.join(allocator, &.{ localappdata, "bob" });
            },

            // Default path on MacOS is ~/Library/bob
            .macos => {
                const home = env.get("HOME") orelse {
                    std.log.err("HOME is not defined", .{});
                    return error.missing_env;
                };

                break :blk try std.fs.path.join(allocator, &.{ home, "Library/bob" });
            },

            else => @compileError("unsupported platform" ++ @tagName(builtin.os.tag)),
        }
    };

    std.log.info("creating client list. path is {s}", .{path});

    try std.fs.cwd().makePath(path);

    return .{
        .path = path,
        .list = std.ArrayList([*:0]const u8).init(allocator),
    };
}

pub fn deinit(self: *ClientList) void {
    self.clearClients();
    self.list.deinit();
    self.list.allocator.free(self.path);
}

pub fn getClientPath(self: *const ClientList, index: usize) ![]const u8 {
    var buf = [_]u8{0} ** 64;
    var stream = std.io.fixedBufferStream(&buf);
    const name = std.mem.span(self.list.items[index]);

    try stream.writer().writeAll(library.prefix);
    try stream.writer().writeAll(name);
    try stream.writer().writeAll(library.suffix);

    return std.fs.path.join(self.list.allocator, &.{
        self.path,
        name,
        stream.getWritten(),
    });
}

pub fn getClientParentPath(self: *const ClientList, index: usize) ![]const u8 {
    const name = std.mem.span(self.list.items[index]);
    return std.fs.path.join(self.list.allocator, &.{ self.path, name });
}

pub fn freePath(self: *const ClientList, path: []const u8) void {
    self.list.allocator.free(path);
}

pub fn readClientDir(self: *ClientList) !void {
    self.clearClients();

    const dir = try std.fs.cwd().openDir(self.path, .{ .iterate = true });
    var iter = dir.iterate();

    while (try iter.next()) |entry| {
        if (entry.kind != .directory) {
            continue;
        }

        const name = try self.list.allocator.dupeZ(u8, entry.name);

        try self.list.append(name);
    }
}

fn clearClients(self: *ClientList) void {
    for (self.list.items) |name| {
        // Some annoying stuff to be able to free a C string
        var slice: [:0]const u8 = undefined;

        slice.ptr = @ptrCast(name);
        slice.len = std.mem.len(name);
        self.list.allocator.free(slice);
    }

    self.list.clearRetainingCapacity();
}
