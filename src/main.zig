const std = @import("std");

pub fn main() !void {
    try std.io.getStdOut().writeAll("Hello, my name is Bob\n");
}
