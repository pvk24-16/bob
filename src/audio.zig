pub const Error = error{
    AlreadyConnected,
    NotConnected,
};

pub const DummyStream = @import("audio/DummyStream.zig");

/// Generic stream object
pub const Stream = union(enum) {
    dummy: DummyStream,

    pub fn connect(source: *Stream, sink: *Stream) Error!void {
        try source.connectSink(sink);
        try sink.connectSource(source);
    }

    pub fn disconnect(source: *Stream, sink: *Stream) Error!void {
        try source.disconnectSink();
        try sink.disconnectSource();
    }

    pub fn connectSource(self: *Stream, other: *Stream) Error!void {
        switch (self.*) {
            inline else => |*s| try s.connectSource(other),
        }
    }

    pub fn connectSink(self: *Stream, other: *Stream) Error!void {
        switch (self.*) {
            inline else => |*s| try s.connectSink(other),
        }
    }

    pub fn disconnectSource(self: *Stream) Error!void {
        switch (self.*) {
            inline else => |*s| try s.disconnectSource(),
        }
    }

    pub fn disconnectSink(self: *Stream) Error!void {
        switch (self.*) {
            inline else => |*s| try s.disconnectSink(),
        }
    }

    pub fn process(self: *Stream, data: []const u8) !void {
        switch (self.*) {
            inline else => |*s| try s.process(data),
        }
    }

    pub fn deinit(self: *Stream) Error!void {
        switch (self.*) {
            inline else => |*s| try s.deinit(),
        }
    }

    pub fn start(self: *Stream) Error!void {
        switch (self.*) {
            inline else => |*s| try s.start(),
        }
    }

    pub fn stop(self: *Stream) Error!void {
        switch (self.*) {
            inline else => |*s| try s.stop(),
        }
    }

    pub fn channels(self: *const Stream) usize {
        return switch (self.*) {
            inline else => |*s| s.channels(),
        };
    }

    pub fn samplerate(self: *const Stream) u32 {
        return switch (self.*) {
            inline else => |*s| s.samplerate(),
        };
    }
};
