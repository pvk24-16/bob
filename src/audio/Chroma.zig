const std = @import("std");
const FastFourierTransform = @import("fft.zig").FastFourierTransform;
const Config = @import("Config.zig");

const Chroma = @This();

const padding_factor_log2: usize = 2;

window_size: usize,
fft: FastFourierTransform,
chroma: [12]f32,
c3: f32 = 130.81,
num_octaves: usize = 6,
num_bins: usize = 4,
num_partials: usize = 3,
pitches: [12]f32,
samplerate: u32,

pub fn init(allocator: std.mem.Allocator, window_size: usize) !Chroma {
    var self: Chroma = .{
        .window_size = window_size,
        .fft = try FastFourierTransform.init(
            std.math.log2_int_ceil(usize, window_size),
            padding_factor_log2,
            .blackman_harris,
            1.0,
            allocator,
        ),
        .chroma = .{0.0} ** 12,
        .pitches = undefined,
        .samplerate = Config.sample_rate,
    };
    self.initPitches();
    return self;
}

pub fn deinit(self: *Chroma, allocator: std.mem.Allocator) void {
    self.fft.deinit(allocator);
}

fn initPitches(self: *Chroma) void {
    const mul = std.math.pow(f32, 2.0, 1.0 / 12.0);
    var freq = self.c3;
    for (&self.pitches) |*p| {
        p.* = freq;
        freq *= mul;
    }
}

fn binIdFromFrequency(self: *Chroma, freq: f32, size: usize) usize {
    const fs: f32 = @floatFromInt(self.samplerate);
    const N: f32 = @floatFromInt(size);
    const fi = N * freq / fs;
    return @intFromFloat(@round(fi));
}

pub fn execute(self: *Chroma, samples: []const f32) void {

    // Apply FFT
    self.fft.write(samples);
    self.fft.evaluate();
    const spect = self.fft.read();

    // Apply square root
    for (spect) |*s| {
        s.* = @sqrt(s.*);
    }

    // Compute chromagram
    @memset(&self.chroma, 0.0);
    for (&self.chroma, 0..) |*c, n| {
        for (0..self.num_octaves) |o| {
            const fund = self.pitches[n] * std.math.pow(f32, 2.0, @floatFromInt(o));
            for (1..self.num_partials + 1) |h| {
                const hf: f32 = @floatFromInt(h);
                const freq = fund * hf;
                const bin_center = self.binIdFromFrequency(freq, spect.len);
                const bins = spect[bin_center - self.num_bins .. bin_center + self.num_bins];
                const peak = std.mem.max(f32, bins);
                c.* += peak / hf / hf;
            }
        }
    }

    // Normalize chromagram
    const max = std.mem.max(f32, &self.chroma);
    if (max > 0.1) {
        for (&self.chroma) |*c| {
            c.* /= max;
        }
    }
}
