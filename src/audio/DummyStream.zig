//!
//! Dummy stream that just repeats each data chunk N times
//!
const audio = @import("../audio.zig");

n: usize,
input: *audio.Stream,
callback: audio.Callback,

pub fn init(n: usize, input: *audio.Stream) audio.Stream {
    return .{
        .dummy = .{
            .n = n,
            .input = input,
            .callback = undefined,
        },
    };
}

pub fn deinit(self: *@This()) audio.Error!void {
    _ = self;
}

pub fn callbackPtr(self: *@This()) *audio.Callback {
    return &self.callback;
}

pub fn start(self: *@This()) audio.Error!void {
    try self.input.start();
}

pub fn stop(self: *@This()) audio.Error!void {
    try self.input.stop();
}

pub fn channels(self: *const @This()) usize {
    return self.input.channels();
}

pub fn samplerate(self: *const @This()) u32 {
    return self.input.samplerate();
}

pub fn connect(self: *@This(), stream: *audio.Stream) audio.Error!void {
    self.input.callbackPtr().* = .{
        .fun = callbackFun,
        .ctx = stream,
    };
}

fn callbackFun(data: *const anyopaque, size: usize, stream: *audio.Stream) void {
    for (0..stream.dummy.n) |_| {
        stream.callbackPtr().call(data, size);
    }
}
