/// Callback for communication between streams
pub const Callback = struct {
    fun: *const fn (data: *const anyopaque, size: usize, stream: *Stream) void,
    ctx: *Stream,
    pub fn call(self: *const Callback, data: *const anyopaque, size: usize) void {
        self.fun(data, size, self.ctx);
    }
};

pub const Error = error{};

pub const DummyStream = @import("audio/DummyStream.zig");

/// Generic stream object
pub const Stream = union(enum) {
    const Self = @This();

    dummy: DummyStream,

    /// Connect stream
    pub fn connect(self: *Self) Error!void {
        switch (self.*) {
            inline else => |*s| try s.connect(self),
        }
    }

    /// Deinitialize stream
    pub fn deinit(self: *Self) Error!void {
        switch (self.*) {
            inline else => |*s| try s.deinit(),
        }
    }

    /// Start stream
    pub fn start(self: *Self) Error!void {
        switch (self.*) {
            inline else => |*s| try s.start(),
        }
    }

    /// Stop stream
    pub fn stop(self: *Self) Error!void {
        switch (self.*) {
            inline else => |*s| try s.stop(),
        }
    }

    /// Get number of channels
    pub fn channels(self: *const Self) usize {
        return switch (self.*) {
            inline else => |*s| s.channels(),
        };
    }

    /// Get samplerate
    pub fn samplerate(self: *const Self) u32 {
        return switch (self.*) {
            inline else => |*s| s.samplerate(),
        };
    }

    /// Get pointer to callback field
    pub fn callbackPtr(self: *Self) *Callback {
        return switch (self.*) {
            inline else => |*s| s.callbackPtr(),
        };
    }
};
