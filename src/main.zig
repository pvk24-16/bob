const std = @import("std");
const audio = @import("audio.zig");

pub fn main() !void {
    var dummy_1: audio.Stream = audio.DummyStream.init(42);
    var dummy_2: audio.Stream = audio.DummyStream.init(69);
    try audio.Stream.connect(&dummy_1, &dummy_2);
    try dummy_1.start();
    try audio.Stream.disconnect(&dummy_1, &dummy_2);
}
