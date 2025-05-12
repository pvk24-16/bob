const std = @import("std");
const c = @import("c.zig");

const Info = c.bob.bob_visualizer_info;
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

export fn get_info() [*c]const Info {
    return &info;
}

export fn create() [*c]const u8 {
    // Initialize
    if (c.glad.gladLoadGLLoader(api.get_proc_address) == 0) {
        @panic("could not load gl loader");
    }

    // // Intialize vertex array object
    c.glad.glGenVertexArrays(1, &vao);
    c.glad.glBindVertexArray(vao);

    // // Initialize vertex buffer object
    c.glad.glGenBuffers(1, &vbo);
    c.glad.glBindBuffer(c.glad.GL_ARRAY_BUFFER, vbo);

    c.glad.glBufferData(c.glad.GL_ARRAY_BUFFER, 2 * @sizeOf(vec2), null, c.glad.GL_STREAM_DRAW);

    c.glad.glVertexAttribPointer(0, 2, c.glad.GL_FLOAT, c.glad.GL_FALSE, @sizeOf(vec2), null);
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

const vec2 = struct { x: f32, y: f32 };

export fn update() void {
    c.glad.glBindVertexArray(vao);
    c.glad.glUseProgram(program);
    c.glad.glBindBuffer(c.glad.GL_ARRAY_BUFFER, vbo);

    const data = api.get_frequency_data.?(api.context, c.bob.BOB_MONO_CHANNEL);
    const bins: []const f32 = data.ptr[0 .. data.size / 4];
    const step: f32 = 2.0 / @as(f32, @floatFromInt(data.size / 4));

    c.glad.glClearColor(0, 0, 0, 1);
    c.glad.glClear(c.glad.GL_COLOR_BUFFER_BIT);

    var line: [2]vec2 = .{
        vec2{ .x = -1.0, .y = -0.9 },
        vec2{ .x = -1.0 + step, .y = undefined },
    };

    for (bins) |v| {
        line[1].y = 10 * v - 0.9;

        // Update segment
        c.glad.glBufferSubData(
            c.glad.GL_ARRAY_BUFFER,
            0,
            2 * @sizeOf(vec2),
            @ptrCast(line[0..].ptr),
        );

        c.glad.glDrawArrays(c.glad.GL_LINES, 0, 2);

        line[0] = line[1];
        line[1].x += step;
    }
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
            @compileError("Type mismatch for '" ++ name ++ "': "
            //
            ++ @typeName(A) ++ " and " ++ @typeName(B));
        }
    }
}
