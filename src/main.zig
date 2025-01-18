const std = @import("std");
const Renderer = @import("graphics/graphics.zig").Renderer;

pub fn main() !void {
    try std.io.getStdOut().writeAll("Hello, my name is Bob\n");

    var renderer = try Renderer.init();
    defer renderer.deinit();

    var running = true;
    while (running) {
        running = renderer.update();
    }
}
