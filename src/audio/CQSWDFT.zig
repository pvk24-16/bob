//! Constant Q Sliding Window Discrete Fourier Transform
//!
//! https://www.dafx.de/paper-archive/2008/papers/dafx08_63.pdf

const std = @import("std");
const CQSWDFT = @This();

const Config = @import("Config.zig");
const c32 = std.math.Complex(f32);

// frequency = minimum_frequency * bin_center_ratio ^ index

frame_lengths: []const usize,
frame_offsets: []const usize,
samples: []f32,
bins: []c32,

pub fn init(min_frequency: f32, max_frequency: f32, sample_rate: f32, resolution: f32, allocator: std.mem.Allocator) !CQSWDFT {
    const q: f32 = 1.0 / (std.math.pow(f64, 2.0, 1.0 / (resolution * 6.0)) - 1.0);
    const bin_center_ratio: f32 = 1.0 + (std.math.pow(f64, 2.0, 1.0 / (resolution * 6.0)) - 1.0);

    _ = sample_rate;
    _ = q;
    _ = bin_center_ratio;

    const frame_count = @ceil(@log2(max_frequency / min_frequency) * resolution * 6);

    const frame_lengths: []const usize = try allocator.alloc(usize, frame_count);
    errdefer allocator.free(frame_lengths);

    const frame_offsets: []const usize = try allocator.alloc(usize, frame_count);
    errdefer allocator.free(frame_offsets);

    const bins: []const usize = try allocator.alloc(usize, frame_count);
    errdefer allocator.free(bins);
    @memset(bins, 0);

    return CQSWDFT{
        .frame_lengths = frame_lengths,
        .frame_offsets = frame_offsets,
        .bins = bins,
    };
}

pub fn deinit(self: *CQSWDFT, allocator: std.mem.Allocator) void {
    allocator.free(self.samples);
    self.* = undefined;
}

pub fn update(self: *CQSWDFT, samples: []const f32) void {
    for (samples) |sample| {
        for (self.bins, self.frame_lengths, self.frame_offsets) |*bin, n, s| {
            _ = sample;
            _ = bin;
            _ = n;
            _ = s;
        }
    }

    // F(t + 1, k) = e ^ (2 * pi * i * Q / frame.len) * (F(t, k) + (e ^ (2 * pi * i * Q / frame.len) ))
}
