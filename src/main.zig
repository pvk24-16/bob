const std = @import("std");
const g = @import("graphics/graphics.zig");
const Window = g.window.Window;
const Shader = g.shader.Shader;
const VertexBuffer = g.buffer.VertexBuffer;
const ElementBuffer = g.buffer.ElementBuffer;
const UniformBuffer = g.buffer.UniformBuffer;

const vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
};

const Vertex = struct { pos: vec3, col: vec3 };

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
        Vertex{
            .pos = .{ .x = -0.8, .y = 0.0, .z = 0.0 },
            .col = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
        },
        Vertex{
            .pos = .{ .x = -0.4, .y = 0.0, .z = 0.0 },
            .col = .{ .x = 0.25, .y = 0.25, .z = 0.25 },
        },
        Vertex{
            .pos = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
            .col = .{ .x = 0.5, .y = 0.5, .z = 0.5 },
        },
        Vertex{
            .pos = .{ .x = 0.4, .y = 0.0, .z = 0.0 },
            .col = .{ .x = 0.75, .y = 0.75, .z = 0.75 },
        },
        Vertex{
            .pos = .{ .x = 0.8, .y = 0.0, .z = 0.0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        },
    };

    var vertex_buffer = VertexBuffer(Vertex).init();
    defer vertex_buffer.deinit();

    vertex_buffer.bind();
    vertex_buffer.write(&vertex_data, .static);
    vertex_buffer.enableAttribute(0, 3, .float, false, 0);
    vertex_buffer.enableAttribute(1, 3, .float, false, @offsetOf(Vertex, "col"));
    vertex_buffer.unbind();

    g.gl.glLineWidth(3);
    while (running) {
        window.update();

        g.gl.glClearColor(0.7, 0.4, 0.85, 1.0);
        g.gl.glClear(g.gl.GL_COLOR_BUFFER_BIT);

        default_shader.bind();

        vertex_buffer.bindArray();

        g.gl.glDrawArrays(g.gl.GL_LINE_STRIP, 0, 5);

        vertex_buffer.unbindArray();

        running = window.running();
    }
}
