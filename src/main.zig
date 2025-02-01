const std = @import("std");
const g = @import("graphics/graphics.zig");
const math = @import("math/math.zig");
const objparser = @import("obj_parser.zig");
const texture = @import("graphics/textures.zig");
const Window = g.window.Window;
const Shader = g.shader.Shader;
const VertexBuffer = g.buffer.VertexBuffer;
const IndexBuffer = g.buffer.ElementBuffer;
const Mat4 = math.Mat4;

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

    default_shader.bind();

    const allocator = std.heap.page_allocator;
    const buffers = try objparser.parseObj("objects/fish.obj", allocator);
    // defer buffers.deinit();

    const tex = try texture.createTexture("objects/fish_texture.png");

    var vertex_buffer = buffers.vertex_buffer.with_tex;
    var index_buffer = buffers.index_buffer;
    const num_indices = buffers.index_count;

    g.gl.glEnable(g.gl.GL_DEPTH_TEST);

    while (running) {
        window.update();

        default_shader.setF32("time", @floatCast(g.glfw.glfwGetTime()));
        default_shader.setMat4("perspectiveMatrix", Mat4.perspective(90, 0.1, 10.0));
        default_shader.setTexture("tex", tex, 0);

        g.gl.glClearColor(0.7, 0.4, 0.85, 1.0);
        g.gl.glClear(g.gl.GL_COLOR_BUFFER_BIT);
        g.gl.glClear(g.gl.GL_DEPTH_BUFFER_BIT);

        vertex_buffer.bindArray();
        index_buffer.bind();

        g.gl.glDrawElements(
            g.gl.GL_TRIANGLES,
            @intCast(num_indices),
            index_buffer.indexType(),
            null,
        );

        index_buffer.unbind();
        vertex_buffer.unbindArray();

        running = window.running();
    }
}
