const std = @import("std");
const g = @import("graphics/graphics.zig");
const Window = g.Window;
const Shader = g.Shader;

pub fn main() !void {
    try std.io.getStdOut().writeAll("Hello, my name is Bob\n");

    var running = true;
    var window = try Window(8).init();
    defer window.deinit();
    window.setUserPointer();

    var default_shader = try Shader.init(
        @embedFile("shaders/default.vert"),
        @embedFile("shaders/default.frag"),
    );
    defer default_shader.deinit();

    while (running) {
        window.update();
        running = window.running();
    }
}
