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
    .enabled = c.bob.BOB_AUDIO_FREQUENCY_DOMAIN_STEREO | c.bob.BOB_AUDIO_TIME_DOMAIN_STEREO | c.bob.BOB_AUDIO_PULSE_MONO,
};

var vao: c.glad.GLuint = undefined;
var vbo: c.glad.GLuint = undefined;
var program: c.glad.GLuint = undefined;

// We'll need more vertices for the circle and corners
var vertices: [360 * 6]f32 = undefined; // 360 degrees * 6 vertices per segment
var corner_vertices: [4 * 6]f32 = undefined; // 4 corners * 6 vertices per corner

export fn get_info() [*c]const Info {
    return &info;
}

export fn create() [*c]const u8 {
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

    const pulse: c.bob.bob_float_buffer = api.get_pulse_data.?(
        api.context,
        c.bob.BOB_MONO_CHANNEL,
    );

    const segments = 180; // Half circle for each channel

    // Clear the screen
    c.glad.glClearColor(0, 0, 0, 1);
    c.glad.glClear(c.glad.GL_COLOR_BUFFER_BIT);

    // Generate circle vertices
    var vertex_index: usize = 0;
    for (0..segments) |i| {
        const angle1 = @as(f32, @floatFromInt(i)) * std.math.pi / @as(f32, @floatFromInt(segments));
        const angle2 = @as(f32, @floatFromInt(i + 1)) * std.math.pi / @as(f32, @floatFromInt(segments));

        // Left channel (top half)
        const left_volume = freqs_left.ptr[i * freqs_left.size / segments] * 20;
        vertices[vertex_index] = 0.3 * std.math.cos(angle1);
        vertices[vertex_index + 1] = 0.3 * std.math.sin(angle1);
        vertices[vertex_index + 2] = (0.3 + left_volume * 1.5) * std.math.cos(angle1);
        vertices[vertex_index + 3] = (0.3 + left_volume * 1.5) * std.math.sin(angle1);
        vertices[vertex_index + 4] = (0.3 + left_volume * 1.5) * std.math.cos(angle2);
        vertices[vertex_index + 5] = (0.3 + left_volume * 1.5) * std.math.sin(angle2);
        vertex_index += 6;

        // Right channel (bottom half)
        const right_volume = freqs_right.ptr[i * freqs_right.size / segments] * 20;
        vertices[vertex_index] = 0.3 * std.math.cos(angle1 + std.math.pi);
        vertices[vertex_index + 1] = 0.3 * std.math.sin(angle1 + std.math.pi);
        vertices[vertex_index + 2] = (0.3 + right_volume * 1.5) * std.math.cos(angle1 + std.math.pi);
        vertices[vertex_index + 3] = (0.3 + right_volume * 1.5) * std.math.sin(angle1 + std.math.pi);
        vertices[vertex_index + 4] = (0.3 + right_volume * 1.5) * std.math.cos(angle2 + std.math.pi);
        vertices[vertex_index + 5] = (0.3 + right_volume * 1.5) * std.math.sin(angle2 + std.math.pi);
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
    var pulse_intensity: f32 = 0;
    for (0..pulse.size) |i| {
        pulse_intensity += pulse.ptr[i];
    }
    pulse_intensity = pulse_intensity / @as(f32, @floatFromInt(pulse.size));
    const corner_size = 0.2 + pulse_intensity * 0.3;

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
