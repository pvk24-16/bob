const std = @import("std");
const g = @import("render");
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

const VisualizationInfo = bob.bob_visualizer_info;
const AudioFlags = bob.bob_audio_flags;
const Channels = bob.bob_channel;
const BobAPI = bob.bob_api;

// Global variables
var radius_handle: c_int = undefined;
var num_pts_handle: c_int = undefined;
var shader_program: Shader = undefined;
var vertex_buffer: VertexBuffer(Vec3) = undefined;
var num_vertices: u32 = undefined;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const gpa_allocator = gpa.allocator();
var st: i64 = undefined;

/// Export api variable, it will be populated with information by the API
export var api: BobAPI = undefined;

/// Include information about your visualizer here
export fn get_info() callconv(.C) [*c]const VisualizationInfo {
    const info = std.heap.page_allocator.create(VisualizationInfo) catch unreachable;
    info.* = VisualizationInfo{
        .name = "Sphere",
        .description = "Insert description here",
        .enabled = bob.BOB_AUDIO_TIME_DOMAIN_MONO | bob.BOB_AUDIO_FREQUENCY_DOMAIN_MONO,
    };
    return info;
}

/// Initialize visualizer.
/// Audio analysis should be enabled here.
/// UI parameters should be registered here.
/// Return a pointer to user data, or NULL.
export fn create() [*c]const u8 {
    st = std.time.microTimestamp();
    _ = g.gl.gladLoadGLLoader(api.get_proc_address);
    radius_handle = api.register_float_slider.?(api.context, "Radius", 0.0, 2.0, 1.0);
    num_pts_handle = api.register_float_slider.?(api.context, "Num pts", 0.0, 10000.0, 1000.0);

    // Initialize shaders
    shader_program = Shader.init(
        @embedFile("shaders/sphere.vert"),
        @embedFile("shaders/sphere.frag"),
    ) catch unreachable;

    shader_program.bind();

    shader_program.setMat4(
        "perspectiveMatrix",
        Mat4.perspective(90, 16.0/9.0, 0.1, 10.0),
    );
    shader_program.setMat4(
        "transformMatrix",
        Mat4.identity().translate(0.0, 0.0, -2.0),
    );

    shader_program.unbind();

    vertex_buffer = VertexBuffer(Vec3).init();

    num_vertices = update_vertices();

    return null;
}

/// Update called each frame.
/// Audio analysis data is passed in `data`.
export fn update() void {

    // Generate vertex/index buffers

    if (is_updated(radius_handle) or is_updated(num_pts_handle)) {
        num_vertices = update_vertices();
    }

    // "main loop"

    shader_program.bind();

    const t: f32 = @floatCast((@as(f64, @floatFromInt(std.time.microTimestamp() - st))) / 1_000_000.0);
    shader_program.setF32("time", t);

    g.gl.glClearColor(0.3, 0.5, 0.7, 1.0);
    g.gl.glClear(g.gl.GL_COLOR_BUFFER_BIT);
    g.gl.glClear(g.gl.GL_DEPTH_BUFFER_BIT);

    vertex_buffer.bind();

    g.gl.glPointSize(2.0);
    g.gl.glDrawArrays(
        g.gl.GL_POINTS,
        0,
        @intCast(num_vertices),
    );

    vertex_buffer.unbind();
    shader_program.unbind();
}

/// Perform potential visualizer cleanup.
export fn destroy() void {
    _ = gpa.deinit();
}

fn is_updated(ui_element_handle: c_int) bool {
    if (api.ui_element_is_updated.?(api.context, ui_element_handle) > 0) {
        return true;
    }
    return false;
}

fn update_vertices() u32 {
    const radius = api.get_ui_float_value.?(api.context, radius_handle);
    const pts = api.get_ui_float_value.?(api.context, num_pts_handle);
    const num_pts: u32 = @intFromFloat(std.math.round(pts));

    const vertices = fibo_sphere(num_pts, radius, gpa_allocator);
    defer gpa_allocator.free(vertices);
    vertex_buffer.bind();

    vertex_buffer.write(vertices, .static);
    vertex_buffer.enableAttribute(0, 3, .float, false, 0);

    vertex_buffer.unbind();

    return num_pts;
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
