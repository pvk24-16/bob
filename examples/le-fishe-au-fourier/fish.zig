const std = @import("std");
const g = @import("render");
const math = g.math;
const objparser = g.obj_parser;
const texture = g.texture;
const Window = g.window.Window;
const Shader = g.shader.Shader;
const VertexBuffer = g.buffer.VertexBuffer;
const Buffers = objparser.Buffers;
const IndexBuffer = g.buffer.ElementBuffer;
const ArrayBuffer = g.buffer.ArrayBuffer;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Vec4 = math.Vec4;

var st: i64 = undefined;
var shader_program: Shader = undefined;
var tex: u32 = undefined;
var buffers: Buffers = undefined;
var wiggle_buffer: ArrayBuffer(Vec4) = undefined;
var wiggle_coefs: []Vec4 = undefined;

const bob = @cImport({
    @cInclude("bob.h");
});

const VisualizationInfo = bob.bob_visualization_info;
const BobAPI = bob.bob_api;

/// Struct for storing user data.
/// Define "global" values needed by the visualizer.
/// Create an instance of `UserData` in `create()`, and use it in `update()` and `destroy()`.
/// If you do not need any user data you can remove this struct.
const UserData = extern struct {
    my_rgb: [3]u8, // Example: storing an rgb value
};

/// Export api variable, it will be populated with information by the API
export var api: BobAPI = undefined;

// Box-Muller Transform: Converts two uniform random numbers into a normal distribution
fn randomNormal(rng: *std.Random, mean: f32, stddev: f32) f32 {
    const u_1 = rng.float(f32);
    const u_2 = rng.float(f32);
    const z0 = @sqrt(-2.0 * @log(u_1)) * @cos(2.0 * std.math.pi * u_2); // Normal (0,1)
    return z0 * stddev + mean; // Scale and shift to desired mean/stddev
}

pub fn randomWiggleCoefs(
    allocator: std.mem.Allocator,
    count: usize,
    x_params: struct { mean: f32, stddev: f32 },
    y_params: struct { mean: f32, stddev: f32 },
    z_params: struct { mean: f32, stddev: f32 },
    w_params: struct { mean: f32, stddev: f32 },
) []Vec4 {
    var prng = std.crypto.random;

    const coefs = allocator.alloc(Vec4, count) catch unreachable;
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
) []Vec3 {
    var prng = std.crypto.random;

    const coefs = allocator.alloc(Vec3, count) catch unreachable;
    for (coefs) |*coef| {
        coef.* = Vec3{
            .x = randomNormal(&prng, x_params.mean, x_params.stddev),
            .y = randomNormal(&prng, y_params.mean, y_params.stddev),
            .z = randomNormal(&prng, z_params.mean, z_params.stddev),
        };
    }

    return coefs;
}

/// Include information about your visualization here
export fn get_info() callconv(.C) [*c]const VisualizationInfo {
    const info = std.heap.page_allocator.create(VisualizationInfo) catch unreachable;
    info.* = VisualizationInfo{
        .name = "Instert name here",
        .description = "Insert description here",
        .enabled = bob.BOB_AUDIO_TIME_DOMAIN_MONO | bob.BOB_AUDIO_FREQUENCY_DOMAIN_MONO,
    };
    return info;
}

/// Initialize visualization.
/// Audio analysis should be enabled here.
/// UI parameters should be registered here.
/// Return a pointer to user data, or NULL.
export fn create() callconv(.C) [*c]const u8 {
    if (g.gl.gladLoadGLLoader(api.get_proc_address) == 0) {
        @panic("could not load gl loader");
    }
    const allocator = std.heap.page_allocator;

    shader_program = Shader.init(
        @embedFile("shaders/fish.vert"),
        @embedFile("shaders/fish.frag"),
    ) catch {
        @panic("Could not load shader");
    };

    // Generate vertex/index buffers from .obj file
    tex = texture.createTexture("objects/fish_low_poly.png") catch |err| {
        std.debug.print("Could not create texture: {}", .{err});
        unreachable;
    };
    buffers = objparser.parseObj("objects/fish_low_poly.obj", allocator) catch |err| {
        std.debug.print("Could not parse obj: {}", .{err});
        unreachable;
    };
    const num_fish = 10000;

    // x : side-to-side amplitude
    // y : side-to-side wiggle
    // z : up-down amplitude
    // w : phase
    wiggle_coefs = randomWiggleCoefs(
        allocator,
        num_fish,
        .{ .mean = 0.5, .stddev = 0.3 },
        .{ .mean = 15.0, .stddev = 5.0 },
        .{ .mean = 0.1, .stddev = 1.0 },
        .{ .mean = 0.0, .stddev = 1.0 },
    );

    wiggle_buffer = ArrayBuffer(Vec4).init();

    wiggle_buffer.bind();
    wiggle_buffer.write(wiggle_coefs, .static);
    wiggle_buffer.enableAttribute(3, 4, .float, false, 0);
    wiggle_buffer.setDivisior(3, 1);

    // Random x,y,z offsetss
    const offsets = randomOffsets(
        allocator,
        num_fish,
        .{ .mean = 0.1, .stddev = 0.05 },
        .{ .mean = 0.1, .stddev = 0.15 },
        .{ .mean = 0.5, .stddev = 0.5 },
    );

    var offset_buffer = ArrayBuffer(Vec3).init();

    offset_buffer.bind();
    offset_buffer.write(offsets, .static);
    offset_buffer.enableAttribute(4, 3, .float, false, 0);
    offset_buffer.setDivisior(4, 1);

    st = std.time.microTimestamp();
    return null;
}

/// Update called each frame.
export fn update() void {
    var vertex_buffer = buffers.vertex_buffer.with_tex;
    var index_buffer = buffers.index_buffer;
    const num_indices = buffers.index_count;

    shader_program.bind();

    shader_program.setMat4(
        "scaleRotateMatrix",
        Mat4.identity()
            .scale(0.008),
    );

    shader_program.setMat4(
        "translateMatrix",
        Mat4.identity()
            .translate(0.5, 0.0, 0.0),
    );

    shader_program.setMat4(
        "perspectiveMatrix",
        Mat4.perspective(90, 0.1, 20.0),
    );

    shader_program.setTexture("tex", tex, 0);

    g.gl.glEnable(g.gl.GL_DEPTH_TEST);
    g.gl.glEnable(g.gl.GL_CULL_FACE);
    g.gl.glCullFace(g.gl.GL_BACK);

    const t: f32 = @floatCast((@as(f64, @floatFromInt(std.time.microTimestamp() - st))) / 1_000_000.0);
    shader_program.setF32("time", t);
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
}

/// Perform potential visualization cleanup.
export fn destroy() void {
    wiggle_buffer.deinit();
    buffers.deinit();
    shader_program.deinit();
}

// Verify that type signatures are correct
comptime {
    for (&.{ "api", "get_info", "create", "update", "destroy" }) |name| {
        const A = @TypeOf(@field(bob, name));
        const B = @TypeOf(@field(@This(), name));
        if (A != B) {
            @compileError("Type mismatch for '" ++ name ++ "': "
            //
            ++ @typeName(A) ++ " and " ++ @typeName(B));
        }
    }
}
