const std = @import("std");
const gl = @import("c.zig").gl;

pub const Error = error{
    shader_compile_error,
    shader_link_error,
};

pub const Shader = struct {
    program: u32 = undefined,

    /// Creates a regular shader program.
    /// Tip, use @embedFile()!
    pub fn init(vertex_code: []const u8, fragment_code: []const u8) !Shader {
        const program_id = id: {
            var s: c_int = 1;
            var info_log: [512:0]u8 = .{0} ** 512;

            const vertex_shader = gl.glCreateShader(gl.GL_VERTEX_SHADER);
            const fragment_shader = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);

            gl.glShaderSource(vertex_shader, 1, @ptrCast(&vertex_code.ptr), null);
            gl.glCompileShader(vertex_shader);
            gl.glGetShaderiv(vertex_shader, gl.GL_COMPILE_STATUS, &s);
            if (s == 0) {
                gl.glGetShaderInfoLog(vertex_shader, info_log.len, null, &info_log);
                std.log.err("Vertex shader compile error: {s}", .{&info_log});
                return Error.shader_compile_error;
            }

            gl.glShaderSource(fragment_shader, 1, @ptrCast(&fragment_code.ptr), null);
            gl.glCompileShader(fragment_shader);
            gl.glGetShaderiv(fragment_shader, gl.GL_COMPILE_STATUS, &s);
            if (s == 0) {
                gl.glGetShaderInfoLog(fragment_shader, info_log.len, null, &info_log);
                std.log.err("Fragment shader compile error: {s}", .{&info_log});
                return Error.shader_compile_error;
            }

            const program = gl.glCreateProgram();
            gl.glAttachShader(program, vertex_shader);
            gl.glAttachShader(program, fragment_shader);
            gl.glLinkProgram(program);

            gl.glGetProgramiv(program, gl.GL_LINK_STATUS, &s);
            if (s == 0) {
                gl.glGetProgramInfoLog(program, info_log.len, null, &info_log);
                std.log.err("Program linking error: {s}", .{&info_log});
            }

            gl.glDeleteShader(vertex_shader);
            gl.glDeleteShader(fragment_shader);

            break :id program;
        };

        return Shader{
            .program = program_id,
        };
    }

    /// Destroys the shader.
    pub fn deinit(self: *Shader) void {
        gl.glDeleteProgram(self.program);
    }

    /// Bind shader for usage.
    pub fn bind(self: *Shader) void {
        gl.glUseProgram(self.program);
    }
};
