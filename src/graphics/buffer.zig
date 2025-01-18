const std = @import("std");
const gl = @import("c.zig").gl;

pub const Error = error{};

pub const Kind = enum(u32) {
    vertex = gl.GL_ARRAY_BUFFER,
    element = gl.GL_ELEMENT_ARRAY_BUFFER,
    uniform = gl.GL_UNIFORM_BUFFER,
    shader_storage = gl.GL_SHADER_STORAGE_BUFFER,
};

/// How often is the data modified.
pub const Pattern = enum(u32) {
    frequent = gl.GL_STREAM_DRAW,
    occasional = gl.GL_DYNAMIC_DRAW,
    one_time = gl.GL_STATIC_DRAW,
};

pub fn Buffer(comptime T: type, comptime kind: Kind) type {
    switch (kind) {
        .vertex => {},
        else => @compileError("Not implemented"),
    }

    return struct {
        const Self = @This();

        buffer_id: usize = undefined,

        /// Creates a buffer.
        pub fn init() Self {
            const id: usize = undefined;
            gl.glGenBuffers(1, @ptrCast(&id));

            return Self{
                .buffer_id = id,
            };
        }

        /// Destroys the buffer.
        pub fn deinit(self: *Self) void {
            gl.glDeleteBuffers(1, @ptrCast(&self.buffer_id));
        }

        /// Map data to buffer.
        pub fn map(self: *Self, data: []T, pattern: Pattern) void {
            const k = @intFromEnum(kind);
            gl.glBindBuffer(k, self.buffer_id);

            gl.glBufferData(
                k,
                data.len * @sizeOf(T),
                @ptrCast(data.ptr),
                @intFromEnum(pattern),
            );

            gl.glBindBuffer(k, 0);
        }
    };
}
