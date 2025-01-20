const std = @import("std");
const gl = @import("c.zig").gl;

pub const Error = error{};

pub const Pattern = enum(u32) {
    stream = gl.GL_STREAM_DRAW,
    dynamic = gl.GL_DYNAMIC_DRAW,
    static = gl.GL_STATIC_DRAW,
};

pub fn VertexBuffer(comptime T: type) type {
    return struct {
        pub const ComponentType = enum(u32) {
            double = gl.GL_DOUBLE,
            float = gl.GL_FLOAT,
            integer = gl.GL_INT,
            unsigned = gl.GL_UNSIGNED_INT,
            bool = gl.GL_BOOL,
        };

        const Self = @This();

        buffer: u32 = undefined,
        attribute: u32 = undefined,

        /// Generate vertex buffer.
        pub fn init() Self {
            var buffer: u32 = undefined;
            var attribute: u32 = undefined;
            gl.glGenBuffers(1, @ptrCast(&buffer));
            gl.glGenVertexArrays(1, @ptrCast(&attribute));

            return Self{
                .buffer = buffer,
                .attribute = attribute,
            };
        }

        /// Destroy vertex buffer.
        pub fn deinit(self: *Self) void {
            gl.glDeleteVertexArrays(1, @ptrCast(&self.attribute));
            gl.glDeleteBuffers(1, @ptrCast(&self.buffer));
        }

        /// Enable a vertex attribute.
        pub fn enableAttribute(
            self: *Self,
            index: usize,
            comptime component_count: usize,
            component_type: ComponentType,
            normalize: bool,
            offset: usize,
        ) void {
            if (component_count > 4 or component_count == 0) {
                @compileError("A vertex attribute may not have 0 or more than 4 components");
            }

            gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.buffer);
            gl.glBindVertexArray(@intCast(self.attribute));

            gl.glEnableVertexAttribArray(@intCast(index));
            gl.glVertexAttribPointer(
                @intCast(index),
                @intCast(component_count),
                @intFromEnum(component_type),
                @intFromBool(normalize),
                @sizeOf(T),
                @ptrFromInt(offset),
            );

            gl.glBindVertexArray(0);
            gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
        }

        /// Write data to buffer.
        pub fn write(self: *Self, data: []T, pattern: Pattern) void {
            gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.buffer);
            gl.glBufferData(
                gl.GL_ARRAY_BUFFER,
                @intCast(data.len * @sizeOf(T)),
                @ptrCast(data),
                @intFromEnum(pattern),
            );
            gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
        }

        /// Bind vertex array for drawing.
        pub inline fn bind(self: *Self) void {
            gl.glBindVertexArray(self.attribute);
        }

        /// Unbind vertex array.
        pub inline fn unbind(_: *Self) void {
            gl.glBindVertexArray(0);
        }
    };
}
