const std = @import("std");
const c = @import("c.zig");

const Info = c.bob.bob_visualization_info;
const Bob = c.bob.bob_api;

export var api: Bob = undefined;

const vsource: [*]const u8 = @ptrCast(@alignCast(@embedFile("vertex.glsl")));
const fsource: [*]const u8 = @ptrCast(@alignCast(@embedFile("fragment.glsl")));

var info = Info{
    .name = "logvol",
    .description = "Volume bars for multiple frequency bands with logarithmic scaling.",
    .enabled = c.bob.BOB_AUDIO_FREQUENCY_DOMAIN_MONO,
};

var vao: c.glad.GLuint = undefined;
var vbo: c.glad.GLuint = undefined;
var program: c.glad.GLuint = undefined;
var vertices: [12]f32 = .{
    1,  1,
    1,  -1,
    -1, -1,

    -1, -1,
    -1, 1,
    1,  1,
};

export fn get_info() *Info {
    return &info;
}

export fn create() ?*anyopaque {
    // Initialize
    if (c.glad.gladLoadGLLoader(api.get_proc_address) == 0) {
        @panic("could not load gl loader");
    }

    // Intialize vertex array object
    c.glad.glGenVertexArrays(1, &vao);
    c.glad.glBindVertexArray(vao);

    // Initialize vertex buffer object
    c.glad.glGenBuffers(1, &vbo);
    c.glad.glBindBuffer(c.glad.GL_ARRAY_BUFFER, vbo);

    c.glad.glBufferData(
        c.glad.GL_ARRAY_BUFFER,
        vertices.len * @sizeOf(f32),
        &vertices,
        c.glad.GL_STREAM_DRAW,
    );

    c.glad.glVertexAttribPointer(
        0,
        2,
        c.glad.GL_FLOAT,
        c.glad.GL_FALSE,
        2 * @sizeOf(f32),
        null,
    );
    c.glad.glEnableVertexAttribArray(0);

    // Initialize vertex shader
    const vshader: c.glad.GLuint = c.glad.glCreateShader(c.glad.GL_VERTEX_SHADER);
    c.glad.glShaderSource(vshader, 1, &vsource, null);
    c.glad.glCompileShader(vshader);

    // Initialize fragment shader
    const fshader: c.glad.GLuint = c.glad.glCreateShader(c.glad.GL_FRAGMENT_SHADER);
    c.glad.glShaderSource(fshader, 1, &fsource, null);
    c.glad.glCompileShader(fshader);

    // Initialize program
    program = c.glad.glCreateProgram();
    c.glad.glAttachShader(program, vshader);
    c.glad.glAttachShader(program, fshader);
    c.glad.glLinkProgram(program);

    // Deinitialize shaders
    c.glad.glDeleteShader(vshader);
    c.glad.glDeleteShader(fshader);

    return null;
}

export fn update(_: *anyopaque) void {
    c.glad.glBindVertexArray(vao);
    c.glad.glUseProgram(program);
    c.glad.glBindBuffer(c.glad.GL_ARRAY_BUFFER, vbo);

    const freqs: c.bob.bob_float_buffer = api.get_frequency_data.?(
        api.context,
        c.bob.BOB_MONO_CHANNEL,
    );

    const bins: f64 = @floatFromInt(freqs.size);
    const bars = 32;

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

    c.glad.glClearColor(0, 0, 0, 1);
    c.glad.glClear(c.glad.GL_COLOR_BUFFER_BIT);

    inline for (bounds[0..bars], bounds[1 .. bars + 1], 0..) |a, b, i| {
        var volume: f32 = 0;

        for (freqs.ptr[a..b]) |x| {
            volume += x;
        }

        // volume /= @floatFromInt(b - a);

        const step = 2.0 / @as(comptime_float, bars);
        const left = @as(comptime_float, @floatFromInt(i)) * step - 1.0;
        const right = @as(comptime_float, @floatFromInt(i + 1)) * step - 1.0;

        vertices[1] = volume - 0.9;
        vertices[9] = volume - 0.9;
        vertices[11] = volume - 0.9;

        vertices[0] = right;
        vertices[2] = right;
        vertices[10] = right;

        vertices[4] = left;
        vertices[6] = left;
        vertices[8] = left;

        c.glad.glBufferData(
            c.glad.GL_ARRAY_BUFFER,
            vertices.len * @sizeOf(f32),
            &vertices,
            c.glad.GL_STREAM_DRAW,
        );

        c.glad.glDrawArrays(
            c.glad.GL_TRIANGLES,
            0,
            6,
        );
    }

    c.glad.glDrawArrays(c.glad.GL_TRIANGLES, 0, 6);
}

/// Perform potential visualization cleanup.
export fn destroy(_: *anyopaque) void {
    c.glad.glDeleteBuffers(1, &vbo);
    c.glad.glDeleteVertexArrays(1, &vao);
    c.glad.glDeleteProgram(program);
}

// Convert from frequency (Hz) to Mel scale.
fn freqToMel(freq: f64) f64 {
    return 2595.0 * std.math.log10(1.0 + freq / 700.0);
}

// Convert from Mel scale to frequency (Hz).
fn melToFreq(mel: f64) f64 {
    return 700.0 * (std.math.pow(f64, 10.0, mel / 2595.0) - 1.0);
}

fn volumeBars() void {}
