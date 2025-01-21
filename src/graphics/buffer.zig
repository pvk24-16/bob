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
            _: *Self,
            index: usize,
            comptime component_count: usize,
            component_type: ComponentType,
            normalize: bool,
            offset: usize,
        ) void {
            if (component_count > 4 or component_count == 0) {
                @compileError("A vertex attribute may not have 0 or more than 4 components");
            }

            gl.glEnableVertexAttribArray(@intCast(index));
            gl.glVertexAttribPointer(
                @intCast(index),
                @intCast(component_count),
                @intFromEnum(component_type),
                @intFromBool(normalize),
                @sizeOf(T),
                @ptrFromInt(offset),
            );
        }

        /// Write data to buffer.
        pub fn write(_: *Self, data: []T, pattern: Pattern) void {
            gl.glBufferData(
                gl.GL_ARRAY_BUFFER,
                @intCast(data.len * @sizeOf(T)),
                @ptrCast(data),
                @intFromEnum(pattern),
            );
        }

        /// Bind vertex array and buffer.
        pub inline fn bind(self: *Self) void {
            gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.buffer);
            gl.glBindVertexArray(self.attribute);
        }

        /// Unbind vertex array and buffer.
        pub inline fn unbind(_: *Self) void {
            gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
            gl.glBindVertexArray(0);
        }

        /// Bind vertex array for drawing.
        pub inline fn bindArray(self: *Self) void {
            gl.glBindVertexArray(self.attribute);
        }

        /// Unbind vertex array.
        pub inline fn unbindArray(_: *Self) void {
            gl.glBindVertexArray(0);
        }
    };
}

pub fn ElementBuffer(comptime T: type) type {
    switch (T) {
        u8, u16, u32 => {},
        else => @compileError("Expected u8, u16 or u32, found: " ++ @typeName(T)),
    }

    return struct {
        const Self = @This();

        buffer: u32,
        /// Create element buffer.
        pub fn init() Self {
            var buffer: u32 = undefined;
            gl.glGenBuffers(1, @ptrCast(&buffer));

            return Self{ .buffer = buffer };
        }

        /// Destroy element buffer.
        pub fn deinit(self: *Self) void {
            gl.glDeleteBuffers(1, @ptrCast(&self.buffer));
        }

        /// Write data to element buffer.
        pub fn write(_: *Self, data: []T, pattern: Pattern) void {
            gl.glBufferData(
                gl.GL_ELEMENT_ARRAY_BUFFER,
                @intCast(data.len * @sizeOf(T)),
                @ptrCast(data),
                @intFromEnum(pattern),
            );
        }

        /// Bind element buffer.
        pub inline fn bind(self: *Self) void {
            gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.buffer);
        }

        /// Unbind element buffer.
        pub inline fn unbind(_: *Self) void {
            gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, 0);
        }

        /// Return gl enum representing index type.
        pub inline fn indexType(_: *Self) u32 {
            return comptime switch (T) {
                u8 => gl.GL_UNSIGNED_BYTE,
                u16 => gl.GL_UNSIGNED_SHORT,
                u32 => gl.GL_UNSIGNED_INT,
                else => unreachable,
            };
        }
    };
}

pub fn UniformBuffer(comptime T: type) type {
    return struct {
        const Self = @This();

        buffer: u32 = undefined,

        /// Createi and allocate uniform buffer.
        pub fn init() Self {
            var buffer: u32 = undefined;
            gl.glGenBuffers(1, @ptrCast(&buffer));

            return Self{ .buffer = buffer };
        }

        /// Destroy uniform buffer.
        pub fn deinit(self: *Self) void {
            gl.glDeleteBuffers(1, @ptrCast(&self.buffer));
        }

        /// Allocate uniform buffer.
        pub fn alloc(_: *Self, pattern: Pattern) void {
            gl.glBufferData(
                gl.GL_UNIFORM_BUFFER,
                @sizeOf(T),
                null,
                @intFromEnum(pattern),
            );
        }

        /// Write data to field.
        pub fn write(
            _: *Self,
            data: *anyopaque,
            field_offset: u32,
            field_size: u32,
        ) void {
            gl.glBufferSubData(gl.GL_UNIFORM_BUFFER, field_offset, field_size, data);
        }

        /// Link uniform buffer to shader.
        pub fn linkBlockBinding(_: *Self, uniform_name: []const u8, program_id: u32) void {
            const index = gl.glGetUniformBlockIndex(program_id, @ptrCast(uniform_name.ptr));
            gl.glUniformBlockBinding(program_id, index, 0);
        }

        /// Bind uniform buffer.
        pub inline fn bind(self: *Self) void {
            gl.glBindBuffer(gl.GL_UNIFORM_BUFFER, self.buffer);
        }

        /// Unbind uniform buffer.
        pub inline fn unbind(_: *Self) void {
            gl.glBindBuffer(gl.GL_UNIFORM_BUFFER, 0);
        }

        /// Bind uniform buffer range for writing.
        pub inline fn bindRange(self: *Self) void {
            gl.glBindBufferRange(gl.GL_UNIFORM_BUFFER, 0, self.buffer, 0, @sizeOf(T));
        }

        /// Unbind uniform buffer range.
        pub inline fn unbindRange(_: *Self) void {
            gl.glBindBufferRange(gl.GL_UNIFORM_BUFFER, 0, 0, 0, 0);
        }
    };
}
