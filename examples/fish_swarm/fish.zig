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

const FloatParam = struct {
    const Self = @This();

    handle: c_int = undefined,
    value: f32 = undefined,

    pub fn register(self: *Self, name: [*c]const u8, min: f32, max: f32, default: f32) void {
        self.handle = api.register_float_slider.?(api.context, name, min, max, default);
        self.value = default;
    }

    pub fn update(self: *Self) bool {
        if (api.ui_element_is_updated.?(api.context, self.handle) > 0) {
            self.value = api.get_ui_float_value.?(api.context, self.handle);
            return true;
        }
        return false;
    }
};

const IntParam = struct {
    const Self = @This();

    handle: c_int = undefined,
    value: i32 = undefined,

    pub fn register(self: *Self, name: [*c]const u8, min: i32, max: i32, default: i32) void {
        self.handle = api.register_int_slider.?(api.context, name, min, max, default);
        self.value = default;
    }

    pub fn update(self: *Self) bool {
        if (api.ui_element_is_updated.?(api.context, self.handle) > 0) {
            self.value = api.get_ui_int_value.?(api.context, self.handle);
            return true;
        }
        return false;
    }
};

var alloc = std.heap.page_allocator;

// Visualizer data
var t: f32 = 0.0;
var st: i64 = undefined;
var shader_program: Shader = undefined;
var tex: u32 = undefined;
var buffers: Buffers = undefined;
var wiggle_buffer: ArrayBuffer(Vec4) = undefined;
var offset_buffer: ArrayBuffer(Vec3) = undefined;
var pulse_buffer: ArrayBuffer(f32) = undefined;
var prev_pulse_buffer: ArrayBuffer(f32) = undefined;
var pulse_data: []f32 = undefined;
var wiggle_coefs: []Vec4 = undefined;
var pulse_last_updated_time: f32 = 0;
var interpolation_time_seconds: f32 = 0.1;

// User controlled data
var speed: FloatParam = undefined;
var size: FloatParam = undefined;
var radius: FloatParam = undefined;
var num_fish: IntParam = undefined;
var updates_per_second: FloatParam = undefined;
var min_pulse: FloatParam = undefined;
var amplitude: FloatParam = undefined;
var x_rotation_coef: FloatParam = undefined;
var y_rotation_coef: FloatParam = undefined;
var z_rotation_coef: FloatParam = undefined;
var x_offset: FloatParam = undefined;
var y_offset: FloatParam = undefined;
var z_offset: FloatParam = undefined;
var x_stddev: FloatParam = undefined;
var y_stddev: FloatParam = undefined;
var z_stddev: FloatParam = undefined;

const bob = @cImport({
    @cInclude("bob.h");
});

const VisualizationInfo = bob.bob_visualizer_info;
const BobAPI = bob.bob_api;

/// Export api variable, it will be populated with information by the API
export var api: BobAPI = undefined;

// Box-Muller Transform: Converts two uniform random numbers into a normal distribution
fn randomNormal(rng: *std.Random, mean: f32, stddev: f32) f32 {
    const u_1 = rng.float(f32);
    const u_2 = rng.float(f32);
    const z0 = @sqrt(-2.0 * @log(u_1)) * @cos(2.0 * std.math.pi * u_2); // Normal (0,1)
    return z0 * stddev + mean; // Scale and shift to desired mean/stddev
}

fn randomWiggleCoefs(
    allocator: *std.mem.Allocator,
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

fn randomOffsets(
    allocator: *std.mem.Allocator,
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

fn stretch_array(comptime T: type, arr: []T, new_len: usize) []T {
    // Create an array with the new length
    const result = std.heap.page_allocator.alloc(T, new_len) catch unreachable;

    const len = arr.len;
    const ratio = @as(f32, @floatFromInt(new_len)) / @as(f32, @floatFromInt(len));

    for (result, 0..) |*item, i| {
        const orig_index: usize = @intFromFloat(@as(f32, @floatFromInt(i)) / ratio);
        // Get the element from the original array based on the index
        if (orig_index < len) {
            item.* = arr[orig_index];
        } else {
            // If the computed index is out of bounds, use the last element
            item.* = arr[len - 1];
        }
    }

    return result;
}

fn get_pulse_data() []f32 {
    const pulses: bob.bob_float_buffer = api.get_pulse_data.?(
        api.context,
        bob.BOB_MONO_CHANNEL,
    );

    const data = pulses.ptr[0..pulses.size];

    return stretch_array(f32, @constCast(data), @intCast(num_fish.value));
}

fn register_params() void {
    x_rotation_coef.register("Rotation Coefficient (X)", 0.0, 10.0, 0.0);
    y_rotation_coef.register("Rotation Coefficient (Y)", 0.0, 10.0, 1.0);
    z_rotation_coef.register("Rotation Coefficient (Z)", 0.0, 10.0, 0.0);

    x_offset.register("Offset (X)", -2.0, 2.0, 0.0);
    y_offset.register("Offset (Y)", -2.0, 2.0, 0.0);
    z_offset.register("Offset (Z)", -2.0, 2.0, -1.0);

    x_stddev.register("Standard deviation (X)", 0.0, 2.0, 0.15);
    y_stddev.register("Standard deviation (Y)", 0.0, 2.0, 0.25);
    z_stddev.register("Standard deviation (Z)", 0.0, 2.0, 0.2);

    speed.register("speed", 0.0, 5.0, 1.0);
    size.register("size", 0.0, 0.2, 0.05);
    radius.register("radius", 0.0, 2.0, 0.5);
    num_fish.register("fish count", 1, 10000, 500);
    updates_per_second.register("Samples per second", 1.0, 60.0, 10.0);
    min_pulse.register("Min deviation", 0.0, 1.0, 0.1);
    amplitude.register("Amplitude", 0.0, 500.0, 100.0);
}

fn update_params() void {
    if (speed.update()) {
        pulse_last_updated_time = 0; // Make sure to reset interpolation
    }
    _ = size.update();
    _ = radius.update();
    if (num_fish.update() or
        x_rotation_coef.update() or
        y_rotation_coef.update() or
        z_rotation_coef.update() or
        x_offset.update() or
        y_offset.update() or
        z_offset.update() or
        x_stddev.update() or
        y_stddev.update() or
        z_stddev.update())
    {
        update_fish_buffers();
    }
    if (updates_per_second.update()) {
        interpolation_time_seconds = speed.value / updates_per_second.value;
        pulse_last_updated_time = 0; // Make sure to reset interpolation
    }
    _ = min_pulse.update();
    _ = amplitude.update();
}

/// Include information about your visualizer here
export fn get_info() callconv(.C) [*c]const VisualizationInfo {
    const info = std.heap.page_allocator.create(VisualizationInfo) catch unreachable;
    info.* = VisualizationInfo{
        .name = "Fish Swarm",
        .description = "Swarm of fish. Tweak the parameters to make them swim in interesting patterns!",
        .enabled = bob.BOB_AUDIO_PULSE_MONO,
    };
    return info;
}

fn set_const_uniforms() void {
    shader_program.setMat4(
        "perspectiveMatrix",
        Mat4.perspective(90, 0.1, 20.0),
    );

    tex = texture.createTexture("objects/fish_low_poly.png") catch |err| {
        std.debug.print("Could not create texture: {}", .{err});
        unreachable;
    };

    shader_program.setTexture("tex", tex, 0);
}
fn set_variable_uniforms() void {
    shader_program.setMat4(
        "scaleRotateMatrix",
        Mat4.identity()
            .scale(size.value),
    );

    shader_program.setMat4(
        "translateMatrix",
        Mat4.identity()
            .translate(radius.value, 0.0, 0.0),
    );

    const offset: Vec3 = .{
        .x = x_offset.value,
        .y = y_offset.value,
        .z = z_offset.value,
    };

    shader_program.setF32("time", t);
    shader_program.setF32("interpTime", interpolation_time_seconds);
    shader_program.setF32("amplitude", amplitude.value);
    shader_program.setF32("minPulse", min_pulse.value);
    shader_program.setF32("xRotationCoef", x_rotation_coef.value);
    shader_program.setF32("yRotationCoef", y_rotation_coef.value);
    shader_program.setF32("zRotationCoef", z_rotation_coef.value);
    shader_program.setVec3("absoluteOffset", offset);
}

fn update_fish_buffers() void {
    // x : side-to-side amplitude
    // y : side-to-side wiggle
    // z : up-down amplitude
    // w : phase
    wiggle_coefs = randomWiggleCoefs(
        &alloc,
        @intCast(num_fish.value),
        .{ .mean = 0.5, .stddev = 0.3 },
        .{ .mean = 5.0, .stddev = 1.0 },
        .{ .mean = 0.1, .stddev = 1.0 },
        .{ .mean = 0.0, .stddev = 1.0 },
    );

    wiggle_buffer.bind();
    wiggle_buffer.write(wiggle_coefs, .static);
    wiggle_buffer.enableAttribute(3, 4, .float, false, 0);
    wiggle_buffer.setDivisior(3, 1);

    alloc.free(wiggle_coefs);

    // Random x,y,z offsetss
    const offsets = randomOffsets(
        &alloc,
        @intCast(num_fish.value),
        .{ .mean = 0.0, .stddev = x_stddev.value },
        .{ .mean = 0.0, .stddev = y_stddev.value },
        .{ .mean = 0.0, .stddev = z_stddev.value },
    );

    offset_buffer.bind();
    offset_buffer.write(offsets, .static);
    offset_buffer.enableAttribute(4, 3, .float, false, 0);
    offset_buffer.setDivisior(4, 1);

    alloc.free(offsets);
}

/// Initialize visualizer.
/// Audio analysis should be enabled here.
/// UI parameters should be registered here.
/// Return a pointer to user data, or NULL.
export fn create() callconv(.C) [*c]const u8 {
    // Initialize
    if (g.gl.gladLoadGLLoader(api.get_proc_address) == 0) {
        @panic("could not load gl loader");
    }

    register_params();

    // Create shader
    shader_program = Shader.init(
        @embedFile("shaders/fish.vert"),
        @embedFile("shaders/fish.frag"),
    ) catch {
        @panic("Could not load shader");
    };

    buffers = objparser.parseObj("objects/fish_low_poly.obj", alloc) catch |err| {
        std.debug.print("Could not parse obj: {}", .{err});
        unreachable;
    };

    shader_program.bind();
    set_const_uniforms();

    // Buffers for fish
    wiggle_buffer = ArrayBuffer(Vec4).init();
    offset_buffer = ArrayBuffer(Vec3).init();

    update_fish_buffers();

    // Buffers for pulseuency data
    pulse_buffer = ArrayBuffer(f32).init();
    prev_pulse_buffer = ArrayBuffer(f32).init();

    pulse_data = get_pulse_data();

    pulse_buffer.bind();

    pulse_buffer.enableAttribute(5, 1, .float, false, 0);
    pulse_buffer.setDivisior(5, 1);
    pulse_buffer.write(pulse_data, .dynamic);

    prev_pulse_buffer.bind();

    prev_pulse_buffer.enableAttribute(6, 1, .float, false, 0);
    prev_pulse_buffer.setDivisior(6, 1);
    prev_pulse_buffer.write(pulse_data, .dynamic);

    st = std.time.microTimestamp();

    g.gl.glEnable(g.gl.GL_DEPTH_TEST);
    g.gl.glEnable(g.gl.GL_CULL_FACE);
    g.gl.glCullFace(g.gl.GL_BACK);

    return null;
}

/// Update called each frame.
export fn update() void {
    update_params();

    var screen_x: i32 = undefined;
    var screen_y: i32 = undefined;
    if (api.get_window_size) |get_window_size| {
        _ = get_window_size(api.context, &screen_x, &screen_y);
    }

    g.gl.glViewport(0, 0, screen_x, screen_y);

    var vertex_buffer = buffers.vertex_buffer.with_tex;
    var index_buffer = buffers.index_buffer;
    const num_indices = buffers.index_count;

    index_buffer.bind();
    vertex_buffer.bind();
    wiggle_buffer.bind();
    offset_buffer.bind();
    pulse_buffer.bind();
    shader_program.bind();

    t = @floatCast((@as(f32, @floatFromInt(std.time.microTimestamp() - st))) / 1_000_000.0);
    t *= speed.value;

    if (t - pulse_last_updated_time > interpolation_time_seconds) {
        prev_pulse_buffer.bind();
        prev_pulse_buffer.write(pulse_data, .dynamic);

        pulse_data = get_pulse_data();
        pulse_buffer.bind();
        pulse_buffer.write(pulse_data, .dynamic);

        shader_program.setF32("pulseTime", t);
        pulse_last_updated_time = t;
    }

    set_variable_uniforms();

    g.gl.glClearColor(0.0, 0.1, 0.35, 1.0);
    g.gl.glClear(g.gl.GL_COLOR_BUFFER_BIT);
    g.gl.glClear(g.gl.GL_DEPTH_BUFFER_BIT);

    g.gl.glDrawElementsInstanced(
        g.gl.GL_TRIANGLES,
        @intCast(num_indices),
        index_buffer.indexType(),
        null,
        @intCast(num_fish.value),
    );
}

/// Perform potential visualizer cleanup.
export fn destroy() void {
    g.gl.glDisable(g.gl.GL_DEPTH_TEST);
    g.gl.glDisable(g.gl.GL_CULL_FACE);
    g.gl.glCullFace(g.gl.GL_NONE);

    wiggle_buffer.deinit();
    offset_buffer.deinit();
    pulse_buffer.deinit();
    prev_pulse_buffer.deinit();
    shader_program.deinit();
    buffers.deinit();
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
