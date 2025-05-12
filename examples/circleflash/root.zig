const std = @import("std");
const c = @import("c.zig");

const Info = c.bob.bob_visualization_info;
const Bob = c.bob.bob_api;

export var api: Bob = undefined;

const vsource: [*]const u8 = @ptrCast(@alignCast(@embedFile("vertex.glsl")));
const fsource: [*]const u8 = @ptrCast(@alignCast(@embedFile("fragment.glsl")));

var info = Info{
    .name = "circleflash",
    .description = "Circular frequency visualization with stereo channels and pulsing corners.",
    .enabled = c.bob.BOB_AUDIO_FREQUENCY_DOMAIN_STEREO | c.bob.BOB_AUDIO_TIME_DOMAIN_STEREO | c.bob.BOB_AUDIO_PULSE_MONO | c.bob.BOB_AUDIO_MOOD_MONO,
};

var vao: c.glad.GLuint = undefined;
var vbo: c.glad.GLuint = undefined;
var program: c.glad.GLuint = undefined;

// We'll need more vertices for the circle and corners
var vertices: [360 * 6]f32 = undefined; // 360 degrees * 6 vertices per segment
var corner_vertices: [4 * 6]f32 = undefined; // 4 corners * 6 vertices per corner

var frequency_multiplier_handle: c_int = undefined;
var min_height_handle: c_int = undefined;
var beat_multiplier_handle: c_int = undefined;

var r: f32 = 0.0;
var g: f32 = 0.0;
var b: f32 = 0.0;

export fn get_info() [*c]const Info {
    return &info;
}

export fn create() [*c]const u8 {
    // Sliders
    frequency_multiplier_handle = api.register_float_slider.?(api.context, "Frequency Multiplier", 0.0, 50.0, 20.0);
    min_height_handle = api.register_float_slider.?(api.context, "Min Height", 0.0, 0.1, 0.002);
    beat_multiplier_handle = api.register_float_slider.?(api.context, "Beat Multiplier", 0.0, 100.0, 2.0);

    // Initialize
    if (c.glad.gladLoadGLLoader(api.get_proc_address) == 0) {
        @panic("could not load gl loader");
    }

    // Initialize vertex array object
    c.glad.glGenVertexArrays(1, &vao);
    c.glad.glBindVertexArray(vao);

    // Initialize vertex buffer object
    c.glad.glGenBuffers(1, &vbo);
    c.glad.glBindBuffer(c.glad.GL_ARRAY_BUFFER, vbo);

    // Set up vertex attributes
    c.glad.glVertexAttribPointer(
        0, // location = 0 in shader
        2, // 2 components (x, y)
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

    // Check for shader compilation errors
    var success: c.glad.GLint = undefined;
    var infoLog: [512]u8 = undefined;
    c.glad.glGetShaderiv(vshader, c.glad.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        var length: c.glad.GLsizei = undefined;
        c.glad.glGetShaderInfoLog(vshader, 512, &length, &infoLog);
        const error_msg = std.fmt.allocPrint(std.heap.page_allocator, "Vertex shader compilation failed: {s}", .{infoLog[0..@intCast(length)]}) catch @panic("Failed to allocate error message");
        @panic(error_msg);
    }

    // Initialize fragment shader
    const fshader: c.glad.GLuint = c.glad.glCreateShader(c.glad.GL_FRAGMENT_SHADER);
    c.glad.glShaderSource(fshader, 1, &fsource, null);
    c.glad.glCompileShader(fshader);

    // Check for shader compilation errors
    c.glad.glGetShaderiv(fshader, c.glad.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        var length: c.glad.GLsizei = undefined;
        c.glad.glGetShaderInfoLog(fshader, 512, &length, &infoLog);
        const error_msg = std.fmt.allocPrint(std.heap.page_allocator, "Fragment shader compilation failed: {s}", .{infoLog[0..@intCast(length)]}) catch @panic("Failed to allocate error message");
        @panic(error_msg);
    }

    // Initialize program
    program = c.glad.glCreateProgram();
    c.glad.glAttachShader(program, vshader);
    c.glad.glAttachShader(program, fshader);
    c.glad.glLinkProgram(program);

    // Check for program linking errors
    c.glad.glGetProgramiv(program, c.glad.GL_LINK_STATUS, &success);
    if (success == 0) {
        var length: c.glad.GLsizei = undefined;
        c.glad.glGetProgramInfoLog(program, 512, &length, &infoLog);
        const error_msg = std.fmt.allocPrint(std.heap.page_allocator, "Shader program linking failed: {s}", .{infoLog[0..@intCast(length)]}) catch @panic("Failed to allocate error message");
        @panic(error_msg);
    }

    // Deinitialize shaders
    c.glad.glDeleteShader(vshader);
    c.glad.glDeleteShader(fshader);

    return null;
}

export fn update() void {
    c.glad.glBindVertexArray(vao);
    c.glad.glUseProgram(program);
    c.glad.glBindBuffer(c.glad.GL_ARRAY_BUFFER, vbo);

    const freqs_left: c.bob.bob_float_buffer = api.get_frequency_data.?(
        api.context,
        c.bob.BOB_LEFT_CHANNEL,
    );
    const freqs_right: c.bob.bob_float_buffer = api.get_frequency_data.?(
        api.context,
        c.bob.BOB_RIGHT_CHANNEL,
    );

    const segments = 180; // Half circle for each channel

    const mood: c_int = api.get_mood.?(api.context, c.bob.BOB_MONO_CHANNEL);
    processMoodRgb(mood);

    // Clear the screen
    c.glad.glClearColor(r / 2, g / 2, b / 2, 1);
    c.glad.glClear(c.glad.GL_COLOR_BUFFER_BIT);

    const frequency_multiplier = api.get_ui_float_value.?(api.context, frequency_multiplier_handle);
    const min_height = api.get_ui_float_value.?(api.context, min_height_handle);

    // Generate circle vertices
    var vertex_index: usize = 0;
    for (0..segments) |i| {
        const angle1 = @as(f32, @floatFromInt(i)) * std.math.pi / @as(f32, @floatFromInt(segments));
        const angle2 = @as(f32, @floatFromInt(i + 1)) * std.math.pi / @as(f32, @floatFromInt(segments));

        // Left channel (top-left half)
        var left_volume = freqs_left.ptr[i * freqs_left.size / segments] * frequency_multiplier;
        if (left_volume < min_height) {
            left_volume = min_height;
        }
        vertices[vertex_index] = 0.3 * std.math.cos(angle1 - std.math.pi / 2.0);
        vertices[vertex_index + 1] = 0.3 * std.math.sin(angle1 - std.math.pi / 2.0);
        vertices[vertex_index + 2] = (0.3 + left_volume * 1.5) * std.math.cos(angle1 - std.math.pi / 2.0);
        vertices[vertex_index + 3] = (0.3 + left_volume * 1.5) * std.math.sin(angle1 - std.math.pi / 2.0);
        vertices[vertex_index + 4] = (0.3 + left_volume * 1.5) * std.math.cos(angle2 - std.math.pi / 2.0);
        vertices[vertex_index + 5] = (0.3 + left_volume * 1.5) * std.math.sin(angle2 - std.math.pi / 2.0);
        vertex_index += 6;

        // Right channel (top-right half)
        var right_volume = freqs_right.ptr[i * freqs_right.size / segments] * frequency_multiplier;
        if (right_volume < min_height) {
            right_volume = min_height;
        }
        vertices[vertex_index] = 0.3 * std.math.cos(angle1 + std.math.pi / 2.0);
        vertices[vertex_index + 1] = 0.3 * std.math.sin(angle1 + std.math.pi / 2.0);
        vertices[vertex_index + 2] = (0.3 + right_volume * 1.5) * std.math.cos(angle1 + std.math.pi / 2.0);
        vertices[vertex_index + 3] = (0.3 + right_volume * 1.5) * std.math.sin(angle1 + std.math.pi / 2.0);
        vertices[vertex_index + 4] = (0.3 + right_volume * 1.5) * std.math.cos(angle2 + std.math.pi / 2.0);
        vertices[vertex_index + 5] = (0.3 + right_volume * 1.5) * std.math.sin(angle2 + std.math.pi / 2.0);
        vertex_index += 6;
    }

    // Update vertex buffer with circle data
    c.glad.glBufferData(
        c.glad.GL_ARRAY_BUFFER,
        @intCast(vertex_index * @sizeOf(f32)),
        &vertices,
        c.glad.GL_STREAM_DRAW,
    );

    // Draw the circle
    c.glad.glDrawArrays(c.glad.GL_TRIANGLES, 0, @intCast(vertex_index / 2));

    // Generate corner vertices for pulsing effect
    const pulse: c.bob.bob_float_buffer = api.get_pulse_data.?(
        api.context,
        c.bob.BOB_MONO_CHANNEL,
    );
    const beat_multiplier = api.get_ui_float_value.?(api.context, beat_multiplier_handle);

    // Find the maximum pulse value instead of average for more dramatic effect
    var pulse_intensity: f32 = 0;
    for (0..pulse.size) |i| {
        if (pulse.ptr[i] > pulse_intensity) {
            pulse_intensity = pulse.ptr[i];
        }
    }

    // Make the corners more responsive to beats
    var corner_size = 0.2 + pulse_intensity * beat_multiplier * 2.0;
    if (corner_size > 0.5) {
        corner_size = 0.5;
    }

    // Top-left corner
    corner_vertices[0] = -1.0;
    corner_vertices[1] = 1.0;
    corner_vertices[2] = -1.0 + corner_size;
    corner_vertices[3] = 1.0;
    corner_vertices[4] = -1.0 + corner_size;
    corner_vertices[5] = 1.0 - corner_size;

    // Top-right corner
    corner_vertices[6] = 1.0 - corner_size;
    corner_vertices[7] = 1.0;
    corner_vertices[8] = 1.0;
    corner_vertices[9] = 1.0;
    corner_vertices[10] = 1.0;
    corner_vertices[11] = 1.0 - corner_size;

    // Bottom-left corner
    corner_vertices[12] = -1.0;
    corner_vertices[13] = -1.0 + corner_size;
    corner_vertices[14] = -1.0 + corner_size;
    corner_vertices[15] = -1.0 + corner_size;
    corner_vertices[16] = -1.0 + corner_size;
    corner_vertices[17] = -1.0;

    // Bottom-right corner
    corner_vertices[18] = 1.0 - corner_size;
    corner_vertices[19] = -1.0;
    corner_vertices[20] = 1.0;
    corner_vertices[21] = -1.0;
    corner_vertices[22] = 1.0;
    corner_vertices[23] = -1.0 + corner_size;

    // Update vertex buffer with corner data
    c.glad.glBufferData(
        c.glad.GL_ARRAY_BUFFER,
        @intCast(corner_vertices.len * @sizeOf(f32)),
        &corner_vertices,
        c.glad.GL_STREAM_DRAW,
    );

    // Draw the corners
    c.glad.glDrawArrays(c.glad.GL_TRIANGLES, 0, @intCast(corner_vertices.len / 2));
}

export fn destroy() void {
    c.glad.glDeleteBuffers(1, &vbo);
    c.glad.glDeleteVertexArrays(1, &vao);
    c.glad.glDeleteProgram(program);
}

fn processMoodRgb(mood: c_int) void {
    const scale = 0.9;

    switch (mood) {
        c.bob.BOB_HAPPY => {
            r = scale * r + (1.0 - scale) * 0.71;
            g = scale * g + (1.0 - scale) * 0.62;
            b = scale * b + (1.0 - scale) * 0.00;
        },
        c.bob.BOB_EXUBERANT => {
            r = scale * r + (1.0 - scale) * 0.80;
            g = scale * g + (1.0 - scale) * 0.40;
            b = scale * b + (1.0 - scale) * 0.10;
        },
        c.bob.BOB_ENERGETIC => {
            r = scale * r + (1.0 - scale) * 0.70;
            g = scale * g + (1.0 - scale) * 0.10;
            b = scale * b + (1.0 - scale) * 0.10;
        },
        c.bob.BOB_FRANTIC => {
            r = scale * r + (1.0 - scale) * 0.60;
            g = scale * g + (1.0 - scale) * 0.10;
            b = scale * b + (1.0 - scale) * 0.40;
        },
        c.bob.BOB_ANXIOUS => {
            r = scale * r + (1.0 - scale) * 0.10;
            g = scale * g + (1.0 - scale) * 0.10;
            b = scale * b + (1.0 - scale) * 0.50;
        },
        c.bob.BOB_DEPRESSION => {
            r = scale * r + (1.0 - scale) * 0.10;
            g = scale * g + (1.0 - scale) * 0.10;
            b = scale * b + (1.0 - scale) * 0.30;
        },
        c.bob.BOB_CALM => {
            r = scale * r + (1.0 - scale) * 0.10;
            g = scale * g + (1.0 - scale) * 0.50;
            b = scale * b + (1.0 - scale) * 0.20;
        },
        c.bob.BOB_CONTENTMENT => {
            r = scale * r + (1.0 - scale) * 0.30;
            g = scale * g + (1.0 - scale) * 0.30;
            b = scale * b + (1.0 - scale) * 0.30;
        },
        else => unreachable,
    }
}

// Verify that type signatures are correct
comptime {
    for (&.{ "api", "get_info", "create", "update", "destroy" }) |name| {
        const A = @TypeOf(@field(c.bob, name));
        const B = @TypeOf(@field(@This(), name));
        if (A != B) {
            @compileError("Type mismatch for '" ++ name ++ "': " ++ @typeName(A) ++ " and " ++ @typeName(B));
        }
    }
}
