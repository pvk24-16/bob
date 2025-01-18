const std = @import("std");
const Window = @import("graphics/graphics.zig").Window;

pub fn main() !void {
    try std.io.getStdOut().writeAll("Hello, my name is Bob\n");

    var running = true;
    var window = try Window(8).init();
    defer window.deinit();
    window.setUserPointer();

    while (running) {
        window.update();
        running = window.running();
    }
}
