//!
//! Detect breaks in audio source (silent parts)
//!

const std = @import("std");
const Breaks = @This();

in_break: bool = false,

/// The value that is passed to visualizer
/// This is reset when read, or when audio comes back on
client_flag: bool = false,

pub fn execute(self: *Breaks, samples: []const f32) void {

    // TODO: make configurable?
    const hi_threshold: f32 = 0.0001;
    const lo_threshold: f32 = 0.00000001;
    const threshold: f32 = if (self.in_break) hi_threshold else lo_threshold;

    var mean: f32 = 0.0;

    if (samples.len == 0)
        return;

    for (samples) |sample| {
        mean += sample * sample;
    }
    mean /= @as(f32, @floatFromInt(samples.len));

    const in_break = mean < threshold;

    if (!self.in_break and in_break)
        self.client_flag = true;

    if (self.in_break and !in_break)
        self.client_flag = false;

    self.in_break = in_break;
}
