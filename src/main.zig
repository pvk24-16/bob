const std = @import("std");
const g = @import("graphics/graphics.zig");
const Window = g.window.Window;
const Shader = g.shader.Shader;
const VertexBuffer = g.buffer.VertexBuffer;
const IndexBuffer = g.buffer.ElementBuffer;

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
            .pos = .{ .x = 0.8, .y = 0.8, .z = 0.0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        },
        Vertex{
            .pos = .{ .x = 0.8, .y = -0.8, .z = 0.0 },
            .col = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
        },
        Vertex{
            .pos = .{ .x = -0.8, .y = -0.8, .z = 0.0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        },
        Vertex{
            .pos = .{ .x = -0.8, .y = 0.8, .z = 0.0 },
            .col = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
        },
    };

    var indices = [_]u8{
        0, 1, 2,
        2, 3, 0,
    };

    var index_buffer = IndexBuffer(u8).init();
    defer index_buffer.deinit();
    var vertex_buffer = VertexBuffer(Vertex).init();
    defer vertex_buffer.deinit();

    vertex_buffer.bind();
    index_buffer.bind();

    vertex_buffer.write(&vertex_data, .static);
    vertex_buffer.enableAttribute(0, 3, .float, false, 0);
    vertex_buffer.enableAttribute(1, 3, .float, false, @offsetOf(Vertex, "col"));
    index_buffer.write(&indices, .static);

    index_buffer.unbind();
    vertex_buffer.unbind();

    default_shader.bind();
    while (running) {
        window.update();

        default_shader.setF32("time", @floatCast(g.glfw.glfwGetTime()));

        g.gl.glClearColor(0.7, 0.4, 0.85, 1.0);
        g.gl.glClear(g.gl.GL_COLOR_BUFFER_BIT);

        vertex_buffer.bindArray();
        index_buffer.bind();

        g.gl.glDrawElements(
            g.gl.GL_TRIANGLES,
            indices.len,
            index_buffer.indexType(),
            null,
        );

        index_buffer.unbind();
        vertex_buffer.unbindArray();

        running = window.running();
    }
}
