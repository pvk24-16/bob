const std = @import("std");
const g = @import("graphics/graphics.zig");
const Window = g.window.Window;
const Shader = g.shader.Shader;
const VertexBuffer = g.buffer.VertexBuffer;

const vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
};

const Vertex = struct {
    pos: vec3,
};

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

    var vertex_data = [_]Vertex{
        Vertex{ .pos = .{ .x = 0.0, .y = 0.8, .z = 0.0 } },
        Vertex{ .pos = .{ .x = -0.8, .y = -0.8, .z = 0.0 } },
        Vertex{ .pos = .{ .x = 0.8, .y = -0.8, .z = 0.0 } },
    };

    var vertex_buffer = VertexBuffer(Vertex).init();
    defer vertex_buffer.deinit();

    vertex_buffer.write(&vertex_data, .static);
    vertex_buffer.enableAttribute(0, 3, .float, false, 0);

    while (running) {
        window.update();

        g.gl.glClearColor(0.7, 0.4, 0.85, 1.0);
        g.gl.glClear(g.gl.GL_COLOR_BUFFER_BIT);

        default_shader.bind();
        vertex_buffer.bind();
        g.gl.glDrawArrays(g.gl.GL_TRIANGLES, 0, vertex_data.len);
        vertex_buffer.unbind();

        running = window.running();
    }
}
