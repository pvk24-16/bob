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

    /// Unbind shader.
    pub fn unbind(_: *Shader) void {
        gl.glUseProgram(0);
    }

    // Uniforms

    /// Pass boolean to uniform.
    pub fn setBool(self: *Shader, name: []const u8, val: bool) void {
        gl.glUniform1i(
            gl.glGetUniformLocation(self.program, @ptrCast(name)),
            @intFromBool(val),
        );
    }

    /// Pass signed 32-bit integer to uniform.
    pub fn setI32(self: *Shader, name: []const u8, val: i32) void {
        gl.glUniform1i(
            gl.glGetUniformLocation(self.program, @ptrCast(name)),
            val,
        );
    }

    /// Pass unsigned 32-bit integer to uniform.
    pub fn setU32(self: *Shader, name: []const u8, val: u32) void {
        gl.glUniform1ui(
            gl.glGetUniformLocation(self.program, @ptrCast(name)),
            val,
        );
    }

    /// Pass 32-bit float to uniform.
    pub fn setF32(self: *Shader, name: []const u8, val: f32) void {
        gl.glUniform1f(
            gl.glGetUniformLocation(self.program, @ptrCast(name)),
            val,
        );
    }

    /// Pass vec2 to uniform. TODO: implement math library.
    pub fn setVec2(self: *Shader, name: []const u8, x: f32, y: f32) void {
        gl.glUniform2f(
            gl.glGetUniformLocation(self.program, @ptrCast(name)),
            x,
            y,
        );
    }

    /// Pass vec3 to uniform. TODO: implement math library.
    pub fn setVec3(self: *Shader, name: []const u8, x: f32, y: f32, z: f32) void {
        gl.glUniform3f(
            gl.glGetUniformLocation(self.program, @ptrCast(name)),
            x,
            y,
            z,
        );
    }

    /// Pass vec4 to uniform. TODO: implement math library.
    pub fn setVec4(self: *Shader, name: []const u8, x: f32, y: f32, z: f32, w: f32) void {
        gl.glUniform4f(
            gl.glGetUniformLocation(self.program, @ptrCast(name)),
            x,
            y,
            z,
            w,
        );
    }
};

pub const ComputeShader = struct {
    io: u32 = undefined,
    quad_buffer: u32 = undefined,
    quad_attributes: u32 = undefined,
    /// Underlying shader.
    s: Shader = undefined,

    /// Create compute shader.
    pub fn init(vertex_code: []const u8, fragment_code: []const u8) !ComputeShader {
        var io: u32 = undefined;
        var buffer: u32 = undefined;
        var attributes: u32 = undefined;
        gl.glGenTextures(1, &io);

        gl.glGenBuffers(1, &buffer);
        gl.glGenVertexArrays(1, &attributes);

        gl.glBindVertexArray(attributes);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, buffer);
        gl.glBufferData(
            gl.GL_ARRAY_BUFFER,
            12 * @sizeOf(f32),
            @ptrCast(@alignCast(&[12]f32{
                1.0,  1.0,
                1.0,  -1.0,
                -1.0, -1.0,
                -1.0, -1.0,
                -1.0, 1.0,
                1.0,  1.0,
            })),
            gl.GL_STATIC_DRAW,
        );

        gl.glEnableVertexAttribArray(0);
        gl.glVertexAttribPointer(
            0,
            2,
            gl.GL_FLOAT,
            gl.GL_FALSE,
            2 * @sizeOf(f32),
            @ptrFromInt(0),
        );

        return ComputeShader{
            .io = io,
            .quad_buffer = buffer,
            .quad_attributes = attributes,
            .s = (try Shader.init(vertex_code, fragment_code)),
        };
    }

    /// Destroy compute shader.
    pub fn deinit(self: *ComputeShader) void {
        gl.glDeleteTextures(1, &self.io);
        gl.glDeleteBuffers(1, &self.quad_buffer);
        gl.glDeleteVertexArrays(1, &self.quad_attributes);
        self.s.deinit();
    }

    /// Write input data.
    pub fn write(self: *ComputeShader, comptime T: type, data: []T) void {
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.io);

        gl.glTexImage2D(
            gl.GL_TEXTURE_2D,
            0,
            gl.GL_RED,
            @sizeOf(T),
            data.len,
            0,
            gl.GL_RED,
            gl.GL_UNSIGNED_BYTE,
            data,
        );

        gl.glBindTexture(gl.GL_TEXTURE_2D, 0);
    }

    /// Perform computations.
    pub fn execute(self: *ComputeShader) void {
        gl.glBindVertexArray(self.quad_attributes);

        gl.glBindVertexArray(0);
    }
};
