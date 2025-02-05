const std = @import("std");
const g = @import("graphics/graphics.zig");
const math = @import("math/math.zig");
const objparser = @import("graphics/obj_parser.zig");
const texture = @import("graphics/textures.zig");
const Window = g.window.Window;
const Shader = g.shader.Shader;
const VertexBuffer = g.buffer.VertexBuffer;
const IndexBuffer = g.buffer.ElementBuffer;
const ArrayBuffer = g.buffer.ArrayBuffer;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Vec4 = math.Vec4;

pub fn randomWiggleCoefs(
    allocator: std.mem.Allocator,
    count: usize,
    x_range: struct { f32, f32 },
    y_range: struct { f32, f32 },
    z_range: struct { f32, f32 },
    w_range: struct { f32, f32 },
) ![]Vec4 {
    var prng = std.crypto.random;

    const coefs = try allocator.alloc(Vec4, count);
    for (coefs) |*coef| {
        coef.* = Vec4{
            .x = prng.float(f32) * (x_range[1] - x_range[0]) + x_range[0],
            .y = prng.float(f32) * (y_range[1] - y_range[0]) + y_range[0],
            .z = prng.float(f32) * (z_range[1] - z_range[0]) + z_range[0],
            .w = prng.float(f32) * (w_range[1] - w_range[0]) + w_range[0],
        };
    }

    return coefs;
}

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

    // Generate vertex/index buffers from .obj file

    const tex = try texture.createTexture("objects/fish_texture.png");
    const allocator = std.heap.page_allocator;
    var buffers = try objparser.parseObj("objects/fish.obj", allocator);
    defer buffers.deinit();

    var vertex_buffer = buffers.vertex_buffer.with_tex;
    var index_buffer = buffers.index_buffer;
    const num_indices = buffers.index_count;

    // x : side-to-side amplitude
    // y : side-to-side wiggle
    // z : up-down amplitude
    // w : phase
    const wiggle_coefs = try randomWiggleCoefs(
        allocator,
        100,
        .{ 0.3, 1.5 },
        .{ 4.0, 10.0 },
        .{ 0.3, 3.0 },
        .{ 0.0, 10.0 },
    );

    var offset_buffer = ArrayBuffer(Vec4).init();
    defer offset_buffer.deinit();

    offset_buffer.bind();
    offset_buffer.write(wiggle_coefs, .static);
    offset_buffer.enableAttribute(3, 4, .float, false, 0);
    offset_buffer.setDivisior(3, 1);

    default_shader.bind();

    g.gl.glEnable(g.gl.GL_DEPTH_TEST);
    g.gl.glEnable(g.gl.GL_CULL_FACE);
    g.gl.glCullFace(g.gl.GL_BACK);

    default_shader.setMat4(
        "transformMatrix",
        Mat4.perspective(90, 0.1, 30.0)
            .translate(0.0, 0.0, -5.0),
    );
    default_shader.setTexture("tex", tex, 0);

    while (running) {
        window.update();

        default_shader.setF32("time", @floatCast(g.glfw.glfwGetTime()));
        g.gl.glClearColor(0.2, 0.5, 0.85, 1.0);
        g.gl.glClear(g.gl.GL_COLOR_BUFFER_BIT);
        g.gl.glClear(g.gl.GL_DEPTH_BUFFER_BIT);

        vertex_buffer.bindArray();
        index_buffer.bind();
        offset_buffer.bind();

        g.gl.glDrawElementsInstanced(
            g.gl.GL_TRIANGLES,
            @intCast(num_indices),
            index_buffer.indexType(),
            null,
            @intCast(wiggle_coefs.len),
        );

        index_buffer.unbind();
        vertex_buffer.unbindArray();
        offset_buffer.unbind();

        running = window.running();
    }
}
