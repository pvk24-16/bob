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

// Box-Muller Transform: Converts two uniform random numbers into a normal distribution
fn randomNormal(rng: *std.Random, mean: f32, stddev: f32) f32 {
    const u_1 = rng.float(f32);
    const u_2 = rng.float(f32);
    const z0 = @sqrt(-2.0 * @log(u_1)) * @cos(2.0 * std.math.pi * u_2);
    return z0 * stddev + mean;
}

pub fn randomWiggleCoefs(
    allocator: std.mem.Allocator,
    count: usize,
    x_params: struct { mean: f32, stddev: f32 },
    y_params: struct { mean: f32, stddev: f32 },
    z_params: struct { mean: f32, stddev: f32 },
    w_params: struct { mean: f32, stddev: f32 },
) ![]Vec4 {
    var prng = std.crypto.random;

    const coefs = try allocator.alloc(Vec4, count);
    for (coefs) |*coef| {
        coef.* = Vec4{
            .x = randomNormal(&prng, x_params.mean, x_params.stddev),
            .y = randomNormal(&prng, y_params.mean, y_params.stddev),
            .z = randomNormal(&prng, z_params.mean, z_params.stddev),
            .w = randomNormal(&prng, w_params.mean, w_params.stddev),
        };
    }

    return coefs;
}

pub fn randomOffsets(
    allocator: std.mem.Allocator,
    count: usize,
    x_params: struct { mean: f32, stddev: f32 },
    y_params: struct { mean: f32, stddev: f32 },
    z_params: struct { mean: f32, stddev: f32 },
) ![]Vec3 {
    var prng = std.crypto.random;

    const coefs = try allocator.alloc(Vec3, count);
    for (coefs) |*coef| {
        coef.* = Vec3{
            .x = randomNormal(&prng, x_params.mean, x_params.stddev),
            .y = randomNormal(&prng, y_params.mean, y_params.stddev),
            .z = randomNormal(&prng, z_params.mean, z_params.stddev),
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

    const tex = try texture.createTexture("objects/fish_low_poly.png");
    const allocator = std.heap.page_allocator;
    var buffers = try objparser.parseObj("objects/fish_low_poly.obj", allocator);
    defer buffers.deinit();

    var vertex_buffer = buffers.vertex_buffer.with_tex;
    var index_buffer = buffers.index_buffer;
    const num_indices = buffers.index_count;

    // Generate buffers for instancing data

    const num_fish = 100000;

    // x : side-to-side amplitude
    // y : side-to-side wiggle
    // z : up-down amplitude
    // w : phase
    const wiggle_coefs = try randomWiggleCoefs(
        allocator,
        num_fish,
        .{ .mean = 0.5, .stddev = 0.3 },
        .{ .mean = 15.0, .stddev = 5.0 },
        .{ .mean = 0.1, .stddev = 1.0 },
        .{ .mean = 0.0, .stddev = 1.0 },
    );

    var wiggle_buffer = ArrayBuffer(Vec4).init();
    defer wiggle_buffer.deinit();

    wiggle_buffer.bind();
    wiggle_buffer.write(wiggle_coefs, .static);
    wiggle_buffer.enableAttribute(3, 4, .float, false, 0);
    wiggle_buffer.setDivisior(3, 1);

    allocator.free(wiggle_coefs); // buffer already loaded to GPU, free CPU side data

    // Random x,y,z offsetss
    const offsets = try randomOffsets(
        allocator,
        num_fish,
        .{ .mean = 0.1, .stddev = 0.05 },
        .{ .mean = 0.1, .stddev = 0.15 },
        .{ .mean = 0.5, .stddev = 0.5 },
    );

    var offset_buffer = ArrayBuffer(Vec3).init();
    defer offset_buffer.deinit();

    offset_buffer.bind();
    offset_buffer.write(offsets, .static);
    offset_buffer.enableAttribute(4, 3, .float, false, 0);
    offset_buffer.setDivisior(4, 1);

    allocator.free(offsets); // buffer already loaded to GPU, free CPU side data

    default_shader.bind();

    default_shader.setMat4(
        "scaleRotateMatrix",
        Mat4.identity()
            .scale(0.008),
    );

    default_shader.setMat4(
        "translateMatrix",
        Mat4.identity()
            .translate(0.5, 0.0, 0.0),
    );

    default_shader.setMat4(
        "perspectiveMatrix",
        Mat4.perspective(90, 0.1, 20.0),
    );

    default_shader.setTexture("tex", tex, 0);

    g.gl.glEnable(g.gl.GL_DEPTH_TEST);
    g.gl.glEnable(g.gl.GL_CULL_FACE);
    g.gl.glCullFace(g.gl.GL_BACK);

    while (running) {
        window.update();

        default_shader.setF32("time", @floatCast(g.glfw.glfwGetTime()));
        g.gl.glClearColor(0.0, 0.1, 0.35, 1.0);
        g.gl.glClear(g.gl.GL_COLOR_BUFFER_BIT);
        g.gl.glClear(g.gl.GL_DEPTH_BUFFER_BIT);

        vertex_buffer.bindArray();
        index_buffer.bind();
        wiggle_buffer.bind();

        g.gl.glDrawElementsInstanced(
            g.gl.GL_TRIANGLES,
            @intCast(num_indices),
            index_buffer.indexType(),
            null,
            @intCast(wiggle_coefs.len),
        );

        index_buffer.unbind();
        vertex_buffer.unbindArray();
        wiggle_buffer.unbind();

        running = window.running();
    }
}
