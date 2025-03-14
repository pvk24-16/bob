const std = @import("std");
const g = @import("opengl-abstraction/src/lib.zig");
const bob = @cImport({
    @cInclude("bob.h");
});
const math = g.math;
const Window = g.window.Window;
const Shader = g.shader.Shader;
const objparser = g.obj_parser;
const texture = g.texture;
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

const Vertex = struct { pos: Vec3 };

/// Struct for storing user data.
/// Define "global" values needed by the visualizer.
/// Create an instance of `UserData` in `create()`, and use it in `update()` and `destroy()`.
/// If you do not need any user data you can remove this struct.
// const UserData = extern struct {};

var radius_handle: c_int = undefined;
var num_pts_handle: c_int = undefined;

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
    _ = g.gl.gladLoadGLLoader(api.get_proc_address);
    radius_handle = api.register_float_slider.?(api.context, "Radius", 0.0, 2.0, 1.0);
    num_pts_handle = api.register_float_slider.?(api.context, "Num pts", 0.0, 10000.0, 1000.0);
    return null;
}

/// Update called each frame.
/// Audio analysis data is passed in `data`.
export fn update(_: *anyopaque) void {
    var default_shader = Shader.init(
        @embedFile("shaders/sphere.vert"),
        @embedFile("shaders/sphere.frag"),
    ) catch unreachable;

    default_shader.bind();

    // Generate vertex/index buffers

    const r = api.get_ui_float_value.?(api.context, radius_handle);
    const pts = api.get_ui_float_value.?(api.context, num_pts_handle);

    const num_pts: u32 = @intFromFloat(std.math.round(pts));
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const vertices = fibo_sphere(num_pts, r, allocator);
    defer allocator.free(vertices);

    // var vertices = [_]Vec3{
    //     .{ .x = 0.8, .y = 0.8, .z = -1.0 },
    //     .{ .x = 0.8, .y = -0.8, .z = -1.0 },
    //     .{ .x = -0.8, .y = -0.8, .z = -1.0 },
    //     .{ .x = -0.8, .y = 0.8, .z = -1.0 },
    // };

    var vertex_buffer = VertexBuffer(Vec3).init();
    defer vertex_buffer.deinit();

    vertex_buffer.bind();

    vertex_buffer.write(vertices, .static);
    vertex_buffer.enableAttribute(0, 3, .float, false, 0);

    var indices: [6]u32 = .{ 0, 1, 2, 0, 2, 3 };

    var index_buffer = IndexBuffer(u32).init();
    defer index_buffer.deinit();
    index_buffer.bind();
    index_buffer.write(&indices, .static);
    index_buffer.unbind();

    default_shader.bind();

    default_shader.setMat4(
        "perspectiveMatrix",
        Mat4.perspective(90, 0.1, 10.0),
    );
    default_shader.setMat4(
        "transformMatrix",
        Mat4.identity().translate(0.0, 0.0, -2.0),
    );

    g.gl.glEnable(g.gl.GL_DEPTH_TEST);
    g.gl.glEnable(g.gl.GL_CULL_FACE);
    g.gl.glCullFace(g.gl.GL_BACK);

    // "main loop"

    default_shader.setF32("time", @floatCast(g.glfw.glfwGetTime()));
    g.gl.glClearColor(0.3, 0.5, 0.7, 1.0);
    g.gl.glClear(g.gl.GL_COLOR_BUFFER_BIT);
    g.gl.glClear(g.gl.GL_DEPTH_BUFFER_BIT);

    index_buffer.bind();
    vertex_buffer.bind();

    // g.gl.glDrawElements(
    //     g.gl.GL_TRIANGLES,
    //     @intCast(indices.len),
    //     index_buffer.indexType(),
    //     null,
    // );
    g.gl.glPointSize(2.0);
    g.gl.glDrawArrays(
        g.gl.GL_POINTS,
        0,
        @intCast(vertices.len),
    );

    index_buffer.unbind();
    vertex_buffer.unbind();
}

/// Perform potential visualization cleanup.
export fn destroy(user_data: *anyopaque) void {
    _ = user_data; // Avoid unused variable error
}

fn fibo_sphere(n: u32, radius: f32, allocator: std.mem.Allocator) []Vec3 {
    const n_f: f32 = @floatFromInt(n);

    var pts = allocator.alloc(Vec3, n) catch unreachable;
    const phi = std.math.pi * (std.math.sqrt(5.0) - 1.0);

    for (0..n) |i| {
        const i_f: f32 = @floatFromInt(i);
        const y = 1.0 - (i_f / (n_f - 1.0)) * 2.0;
        const r = std.math.sqrt(1 - y * y);

        const theta = phi * i_f;

        const x = std.math.cos(theta) * r;
        const z = std.math.sin(theta) * r;

        pts[i] = .{ .x = radius * x, .y = radius * y, .z = radius * z };
    }
    return pts;
}
