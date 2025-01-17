//!
//! Dummy stream that just repeats each data chunk N times
//!
const audio = @import("../audio.zig");

n: usize,
sink: ?*audio.Stream = null,
source: ?*audio.Stream = null,

pub fn init(n: usize) audio.Stream {
    return .{ .dummy = .{ .n = n } };
}

pub fn connectSource(self: *@This(), other: *audio.Stream) audio.Error!void {
    if (self.source) |_| {
        return audio.Error.AlreadyConnected;
    }
    self.source = other;
}

pub fn connectSink(self: *@This(), other: *audio.Stream) audio.Error!void {
    if (self.sink) |_| {
        return audio.Error.AlreadyConnected;
    }
    self.sink = other;
}

pub fn disconnectSource(self: *@This()) audio.Error!void {
    if (self.source) |_| {
        self.source = null;
        return;
    }
    return audio.Error.NotConnected;
}

pub fn disconnectSink(self: *@This()) audio.Error!void {
    if (self.sink) |_| {
        self.sink = null;
        return;
    }
    return audio.Error.NotConnected;
}

pub fn process(self: *@This(), data: []const u8) !void {
    const sink = self.sink orelse return audio.Error.NotConnected;
    for (0..self.n) |_| {
        sink.process(data);
    }
}

pub fn deinit(self: *@This()) audio.Error!void {
    _ = self;
}

pub fn start(self: *@This()) audio.Error!void {
    const source = self.source orelse return audio.Error.NotConnected;
    try source.start();
}

pub fn stop(self: *@This()) audio.Error!void {
    const source = self.source orelse return audio.Error.NotConnected;
    try source.stop();
}

pub fn channels(self: *const @This()) usize {
    const source = self.source orelse return audio.Error.NotConnected;
    return source.channels();
}

pub fn samplerate(self: *const @This()) u32 {
    const source = self.source orelse return audio.Error.NotConnected;
    return source.samplerate();
}
