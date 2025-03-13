const std = @import("std");
const g = @import("opengl-abstraction/src/lib.zig");
const bob = @cImport({
    @cInclude("bob.h");
});
const math = g.math;
const Window = g.window.Window;
const Shader = g.shader.Shader;
const VertexBuffer = g.buffer.VertexBuffer;
const IndexBuffer = g.buffer.ElementBuffer;
const ArrayBuffer = g.buffer.ArrayBuffer;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Vec4 = math.Vec4;

const VisualizationInfo = bob.bob_visualization_info;
const AudioFlags = bob.bob_audio_flags;
const Channels = bob.bob_channel;
const BobAPI = bob.bob_api;

/// Struct for storing user data.
/// Define "global" values needed by the visualizer.
/// Create an instance of `UserData` in `create()`, and use it in `update()` and `destroy()`.
/// If you do not need any user data you can remove this struct.
const UserData = extern struct {
    my_float: f32,
};

/// Export api variable, it will be populated with information by the API
export var api: BobAPI = undefined;

/// Include information about your visualization here
export fn get_info() *VisualizationInfo {
    const info = std.heap.page_allocator.create(VisualizationInfo) catch unreachable;
    info.* = VisualizationInfo{
        .name = "Sphere",
        .description = "Insert description here",
        .enabled = bob.BOB_AUDIO_TIME_DOMAIN_MONO | bob.BOB_AUDIO_FREQUENCY_DOMAIN_MONO,
    };
    return info;
}

/// Initialize visualization.
/// Audio analysis should be enabled here.
/// UI parameters should be registered here.
/// Return a pointer to user data, or NULL.
export fn create() ?*anyopaque {
    _ = api.register_float_slider.?(api.context, "Radius", 0.0, 1.0, 0.5);
    return null;
}

/// Update called each frame.
/// Audio analysis data is passed in `data`.
export fn update(_: *anyopaque) void {
    // const default_shader = Shader.init(
    //     @embedFile("shaders/sphere.vert"),
    //     @embedFile("shaders/sphere.frag"),
    // ) catch unreachable;

    // default_shader.bind();

    // // Generate vertex/index buffers

    // var vertices: [4]Vec3 = .{
    //     Vec3{ .x = -1.0, .y = -1.0, .z = 1.0 },
    //     Vec3{ .x = -1.0, .y = 1.0, .z = 1.0 },
    //     Vec3{ .x = 1.0, .y = 1.0, .z = 1.0 },
    //     Vec3{ .x = 1.0, .y = -1.0, .z = 1.0 },
    // };

    // var indices: [6]u8 = .{ 0, 1, 2, 0, 2, 3 };

    _ = VertexBuffer(Vec3).init();
    // vertex_buffer.enableAttribute(0, 3, .float, false, 0);
    // vertex_buffer.write(&vertices, .static);

    // var index_buffer = IndexBuffer(u8).init();
    // index_buffer.write(&indices, .static);

    // default_shader.bind();

    // default_shader.setMat4(
    //     "perspectiveMatrix",
    //     Mat4.identity(),
    // );

    // g.gl.glEnable(g.gl.GL_DEPTH_TEST);
    // g.gl.glEnable(g.gl.GL_CULL_FACE);
    // g.gl.glCullFace(g.gl.GL_BACK);

    // // "main loop"

    // default_shader.setF32("time", @floatCast(g.glfw.glfwGetTime()));
    // g.gl.glClearColor(0.0, 0.1, 0.35, 1.0);
    // g.gl.glClear(g.gl.GL_COLOR_BUFFER_BIT);
    // g.gl.glClear(g.gl.GL_DEPTH_BUFFER_BIT);

    // vertex_buffer.bindArray();
    // index_buffer.bind();

    // g.gl.glDrawElements(
    //     g.gl.GL_TRIANGLES,
    //     @intCast(indices.len),
    //     index_buffer.indexType(),
    //     null,
    // );

    // index_buffer.unbind();
    // vertex_buffer.unbindArray();
}

/// Perform potential visualization cleanup.
export fn destroy(user_data: *anyopaque) void {
    _ = user_data; // Avoid unused variable error
}

// Box-Muller Transform: Converts two uniform random numbers into a normal distribution
fn randomNormal(rng: *std.Random, mean: f32, stddev: f32) f32 {
    const u_1 = rng.float(f32);
    const u_2 = rng.float(f32);
    const z0 = @sqrt(-2.0 * @log(u_1)) * @cos(2.0 * std.math.pi * u_2); // Normal (0,1)
    return z0 * stddev + mean; // Scale and shift to desired mean/stddev
}
