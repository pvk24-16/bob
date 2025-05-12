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

var shader_program: Shader = undefined;

pub const bob = @cImport({
    @cInclude("bob.h");
});

pub const glad = @cImport({
    @cInclude("glad/glad.h");
});

const Info = bob.bob_visualization_info;
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

export fn create() [*c]const u8 {
    // Initialize
    if (glad.gladLoadGLLoader(api.get_proc_address) == 0) {
        @panic("could not load gl loader");
    }

    // Intialize vertex array object
    glad.glGenVertexArrays(1, &vao);
    glad.glBindVertexArray(vao);

    // Initialize vertex buffer object
    glad.glGenBuffers(1, &vbo);
    glad.glBindBuffer(glad.GL_ARRAY_BUFFER, vbo);

    glad.glBufferData(glad.GL_ARRAY_BUFFER, 2 * @sizeOf(vec2), null, glad.GL_STREAM_DRAW);

    glad.glVertexAttribPointer(0, 2, glad.GL_FLOAT, glad.GL_FALSE, @sizeOf(vec2), null);
    glad.glEnableVertexAttribArray(0);

    shader_program = Shader.init(
        @embedFile("shaders/vertex.glsl"),
        @embedFile("shaders/fragment.glsl"),
    ) catch {
        @panic("Could not load shader");
    };

    over_time = std.mem.zeroes(@TypeOf(over_time));

    multiplier.register("multiplier", 0.5, 100.0, 30.0);

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
    glad.glBindVertexArray(vao);
    //glad.glUseProgram(program);
    glad.glBindBuffer(glad.GL_ARRAY_BUFFER, vbo);

    var vertices: [12]f32 = .{
        1,  1,
        1,  -1,
        -1, -1,

        -1, -1,
        -1, 1,
        1,  1,
    };

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

    const square_width = 1.3 / @as(f32, @floatFromInt(over_time[0].len));
    const square_height = 2.0 / @as(f32, @floatFromInt(over_time.len));
    const y_shift_by: f32 = -1;
    const x_shift_by: f32 = -0.5;
    shader_program.bind();
    for (0..over_time.len) |i| {
        const i_f: f32 = @floatFromInt(i);
        const index: usize = @intCast((over_time.len * 2 + over_time_index - 1 - i) % over_time.len);
        for (0..over_time[0].len) |j| {
            const j_f: f32 = @floatFromInt(j);
            vertices[0] = x_shift_by + j_f * square_width;
            vertices[1] = y_shift_by + i_f * square_height;

            vertices[2] = x_shift_by + j_f * square_width;
            vertices[3] = y_shift_by + i_f * square_height - square_height;

            vertices[4] = x_shift_by + j_f * square_width - square_width;
            vertices[5] = y_shift_by + i_f * square_height - square_height;

            vertices[6] = x_shift_by + j_f * square_width - square_width;
            vertices[7] = y_shift_by + i_f * square_height - square_height;

            vertices[8] = x_shift_by + j_f * square_width - square_width;
            vertices[9] = y_shift_by + i_f * square_height;

            vertices[10] = x_shift_by + j_f * square_width;
            vertices[11] = y_shift_by + i_f * square_height;

            // TODO: Using a uniform is bad for performance. But time is too short to fix it now.
            // Perhaps writing to a texture buffer would be the ideal way.
            const grayscale = @log10(over_time[index][j] * multiplier.value);
            const color: Vec3 = .{
                .x = grayscale,
                .y = grayscale,
                .z = grayscale,
            };
            shader_program.setVec3("f_color", color);

            //std.debug.print("{}\n", .{over_time[index][j]});
            if (over_time[index][j] > 0.001 and grayscale > 0.001) {
                glad.glBufferData(
                    glad.GL_ARRAY_BUFFER,
                    vertices.len * @sizeOf(f32),
                    &vertices,
                    glad.GL_STREAM_DRAW,
                );

                glad.glDrawArrays(
                    glad.GL_TRIANGLES,
                    0,
                    6,
                );
            }
        }
    }
    shader_program.unbind();

    glad.glDrawArrays(glad.GL_TRIANGLES, 0, 6);
}

export fn destroy() void {
    glad.glDeleteBuffers(1, &vbo);
    glad.glDeleteVertexArrays(1, &vao);
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
