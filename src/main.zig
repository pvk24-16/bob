const std = @import("std");
const audio = @import("audio.zig");

pub fn main() !void {
    var input_stream: audio.Stream = undefined;
    const output_callback: audio.Callback = undefined;

    var dummy: audio.Stream = audio.DummyStream.init(42, &input_stream);
    try dummy.connect();

    dummy.callbackPtr().* = output_callback;
    try dummy.start();
    try dummy.stop();
}
