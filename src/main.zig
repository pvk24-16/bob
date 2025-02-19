const std = @import("std");
const Client = @import("Client.zig");
const rt_api = @import("rt_api.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(gpa.allocator());
    defer args.deinit();

    const name = args.next() orelse unreachable;

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const path = args.next() orelse {
        try stderr.print("usage: {s} <path>\n", .{name});
        std.process.exit(1);
    };

    var client = Client.load(path) catch |e| {
        try stderr.print("error: failed to load '{s}': {s}\n", .{ path, @errorName(e) });
        std.process.exit(1);
    };
    defer client.unload();

    rt_api.fill(null, client.api.api);
    const info = &client.api.get_info()[0];

    try stdout.print("Name: {s}\n", .{info.name});
    try stdout.print("Description: {s}\n", .{info.description});
}
