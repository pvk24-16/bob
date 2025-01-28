const std = @import("std");
const gl = @import("c.zig").gl;
const math = @import("../math/math.zig");
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Mat4 = math.Mat4;

pub const Error = error{
    shader_compile_error,
    shader_link_error,
    failed_to_create_framebuffer,
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
    pub inline fn bind(self: *Shader) void {
        gl.glUseProgram(self.program);
    }

    /// Unbind shader.
    pub inline fn unbind(_: *Shader) void {
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
    pub fn setVec2(self: *Shader, name: []const u8, v: Vec2) void {
        gl.glUniform2f(
            gl.glGetUniformLocation(self.program, @ptrCast(name)),
            v.x,
            v.y,
        );
    }

    /// Pass vec3 to uniform. TODO: implement math library.
    pub fn setVec3(self: *Shader, name: []const u8, v: Vec3) void {
        gl.glUniform3f(
            gl.glGetUniformLocation(self.program, @ptrCast(name)),
            v.x,
            v.y,
            v.z,
        );
    }

    /// Pass vec4 to uniform. TODO: implement math library.
    pub fn setVec4(self: *Shader, name: []const u8, v: Vec4) void {
        gl.glUniform4f(
            gl.glGetUniformLocation(self.program, @ptrCast(name)),
            v.x,
            v.y,
            v.z,
            v.w,
        );
    }

    pub fn setMat4(self: *Shader, name: []const u8, mat: Mat4) void {
        gl.glUniformMatrix4fv(
            gl.glGetUniformLocation(self.program, @ptrCast(name)),
            1,
            gl.GL_FALSE,
            &(mat.arr),
        );
    }
};
