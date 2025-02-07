const std = @import("std");
const Client = @import("Client.zig");
const Api = @import("Api.zig");

pub fn main() !void {
    var args = std.process.args();
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

    Api.fill(null, client.api.api);

    const info = &client.api.get_info()[0];

    try stdout.print("Name: {s}\n", .{info.name});
    try stdout.print("Description: {s}\n", .{info.description});
}
