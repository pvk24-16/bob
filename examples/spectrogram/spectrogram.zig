const std = @import("std");

const g = @import("render");
const math = g.math;
const Vec3 = math.Vec3;
const Shader = g.shader.Shader;

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

var multiplier: FloatParam = undefined;
var adjust: FloatParam = undefined;

var shader_program: Shader = undefined;

pub const bob = @cImport({
    @cInclude("bob.h");
});

pub const glad = @cImport({
    @cInclude("glad/glad.h");
});

const Info = bob.bob_visualizer_info;
const Bob = bob.bob_api;

export var api: Bob = undefined;

const vsource: [*]const u8 = @ptrCast(@alignCast(@embedFile("shaders/vertex.glsl")));
const fsource: [*]const u8 = @ptrCast(@alignCast(@embedFile("shaders/fragment.glsl")));

var info = Info{
    .name = "spectrogram",
    .description = "A simple spectrogram",
    .enabled = bob.BOB_AUDIO_FREQUENCY_DOMAIN_MONO,
};

var vao: glad.GLuint = undefined;
var vbo: glad.GLuint = undefined;
var program: glad.GLuint = undefined;

export fn get_info() [*c]const Info {
    return &info;
}

var over_time: [256][128]f32 = undefined;
var over_time_index: usize = 0;

var vertices: std.ArrayList(f32) = undefined;
var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};

export fn create() [*c]const u8 {
    // Initialize
    if (glad.gladLoadGLLoader(api.get_proc_address) == 0) {
        @panic("could not load gl loader");
    }

    var w: c_int = undefined;
    var h: c_int = undefined;
    _ = bob.api.get_window_size.?(api.context, &w, &h);
    glad.glViewport(0, 0, w, h);

    // Intialize vertex array object
    glad.glGenVertexArrays(1, &vao);
    glad.glBindVertexArray(vao);

    // Initialize vertex buffer object
    glad.glGenBuffers(1, &vbo);
    glad.glBindBuffer(glad.GL_ARRAY_BUFFER, vbo);

    glad.glBufferData(glad.GL_ARRAY_BUFFER, 2 * @sizeOf(vec2), null, glad.GL_STREAM_DRAW);

    glad.glVertexAttribPointer(0, 2, glad.GL_FLOAT, glad.GL_FALSE, 5 * @sizeOf(f32), null);
    glad.glEnableVertexAttribArray(0);
    glad.glVertexAttribPointer(1, 3, glad.GL_FLOAT, glad.GL_FALSE, 5 * @sizeOf(f32), @ptrFromInt(@sizeOf(vec2)));
    glad.glEnableVertexAttribArray(1);

    vertices = std.ArrayList(f32).init(gpa.allocator());

    shader_program = Shader.init(
        @embedFile("shaders/vertex.glsl"),
        @embedFile("shaders/fragment.glsl"),
    ) catch {
        return "Could not load shader";
    };

    over_time = std.mem.zeroes(@TypeOf(over_time));

    multiplier.register("multiplier", 0.5, 100.0, 30.0);
    adjust.register("adjust", -1.0, 1.0, -0.5);

    return null;
}

const vec2 = struct { x: f32, y: f32 };

// Convert from Mel scale to frequency (Hz).
fn melToFreq(mel: f64) f64 {
    return 700.0 * (std.math.pow(f64, 10.0, mel / 2595.0) - 1.0);
}

// Convert from frequency (Hz) to Mel scale.
fn freqToMel(freq: f64) f64 {
    return 2595.0 * std.math.log10(1.0 + freq / 700.0);
}

export fn update() void {
    _ = multiplier.update();
    _ = adjust.update();
    glad.glBindVertexArray(vao);
    //glad.glUseProgram(program);
    glad.glBindBuffer(glad.GL_ARRAY_BUFFER, vbo);

    var w: c_int = undefined;
    var h: c_int = undefined;
    if (bob.api.get_window_size.?(api.context, &w, &h) != 0) {
        glad.glViewport(0, 0, w, h);
    }

    // This is mostly copy pasterino from logval.
    const freqs = api.get_frequency_data.?(api.context, bob.BOB_MONO_CHANNEL);
    const bins: f64 = @floatFromInt(freqs.size);
    const bars = over_time[0].len;

    // TODO: move to analyzer
    const sample_rate = 44100.0;
    const nyquist_freq = sample_rate / 2.0;

    const mel_lo = freqToMel(0);
    const mel_hi = freqToMel(nyquist_freq);
    const mel_step = (mel_hi - mel_lo) / bars;

    var bounds: [bars + 1]usize = undefined;

    bounds[0] = 0;
    bounds[bars] = freqs.size;

    inline for (1..bars) |i| {
        const j: comptime_float = @floatFromInt(i);
        const k: f64 = melToFreq(mel_lo + j * mel_step) / nyquist_freq * bins;

        bounds[i] = @intFromFloat(@round(k));
    }

    inline for (bounds[0..bars], bounds[1 .. bars + 1], 0..) |a, b, i| {
        var volume: f32 = 0;

        for (freqs.ptr[a..b]) |x| {
            volume += x;
        }

        over_time[over_time_index][i] = volume;
    }

    over_time_index = (over_time_index + 1) % over_time.len;

    glad.glClearColor(0, 0, 0, 1);
    glad.glClear(glad.GL_COLOR_BUFFER_BIT);
    vertices.clearRetainingCapacity();

    const square_width = 1.3 / @as(f32, @floatFromInt(over_time[0].len));
    const square_height = 2.0 / @as(f32, @floatFromInt(over_time.len));
    const y_shift_by: f32 = -1;
    const x_shift_by: f32 = adjust.value;
    shader_program.bind();
    for (0..over_time.len) |i| {
        const i_f: f32 = @floatFromInt(i);
        const index: usize = @intCast((over_time.len * 2 + over_time_index - 1 - i) % over_time.len);
        for (0..over_time[0].len) |j| {
            const j_f: f32 = @floatFromInt(j);

            const grayscale = @log10(over_time[index][j] * multiplier.value);
            const red = grayscale;
            const blue = if (grayscale < 0.5) grayscale else grayscale - 0.5;
            const green = 1.0 - 4.0 * std.math.pow(f32, grayscale - 0.5, 2.0);

            vertices.append(x_shift_by + j_f * square_width) catch unreachable;
            vertices.append(y_shift_by + i_f * square_height) catch unreachable;
            vertices.append(red) catch unreachable;
            vertices.append(blue) catch unreachable;
            vertices.append(green) catch unreachable;
            vertices.append(x_shift_by + j_f * square_width) catch unreachable;
            vertices.append(y_shift_by + i_f * square_height - square_height) catch unreachable;
            vertices.append(red) catch unreachable;
            vertices.append(blue) catch unreachable;
            vertices.append(green) catch unreachable;
            vertices.append(x_shift_by + j_f * square_width - square_width) catch unreachable;
            vertices.append(y_shift_by + i_f * square_height - square_height) catch unreachable;
            vertices.append(red) catch unreachable;
            vertices.append(blue) catch unreachable;
            vertices.append(green) catch unreachable;
            vertices.append(x_shift_by + j_f * square_width - square_width) catch unreachable;
            vertices.append(y_shift_by + i_f * square_height - square_height) catch unreachable;
            vertices.append(red) catch unreachable;
            vertices.append(blue) catch unreachable;
            vertices.append(green) catch unreachable;
            vertices.append(x_shift_by + j_f * square_width - square_width) catch unreachable;
            vertices.append(y_shift_by + i_f * square_height) catch unreachable;
            vertices.append(red) catch unreachable;
            vertices.append(blue) catch unreachable;
            vertices.append(green) catch unreachable;
            vertices.append(x_shift_by + j_f * square_width) catch unreachable;
            vertices.append(y_shift_by + i_f * square_height) catch unreachable;
            vertices.append(red) catch unreachable;
            vertices.append(blue) catch unreachable;
            vertices.append(green) catch unreachable;
        }
    }

    glad.glBufferData(
        glad.GL_ARRAY_BUFFER,
        @intCast(vertices.items.len * @sizeOf(f32)),
        @ptrCast(vertices.items),
        glad.GL_STREAM_DRAW,
    );

    glad.glDrawArrays(
        glad.GL_TRIANGLES,
        0,
        @intCast(vertices.items.len / 5),
    );
}

export fn destroy() void {
    glad.glDeleteBuffers(1, &vbo);
    glad.glDeleteVertexArrays(1, &vao);
    shader_program.deinit();
    vertices.deinit();
    _ = gpa.deinit();
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
