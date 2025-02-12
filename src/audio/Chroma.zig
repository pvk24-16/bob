//! Chromagram computation
//! Author: Ludvig Gunne Lindström
//! Based on: Real-time Chord Recognition for Live Performance,
//!           Adam M. Stark, Mark D. Plumbley

const std = @import("std");
const fft = @import("fft.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Chroma = @This();

const Config = struct {
    /// Size of frame
    frame_size: usize = 4096,
    /// Ratio between zero padded buffer size and frame
    padding_factor: usize = 16,
    /// a0 constant used in window function
    window_a0: f32 = 0.54, // Hamming window

    // The following fields may be modified after initialization

    /// Tuning of the lowest analyzed note (default is C3)
    low_c_freq: f32 = 130.81,
    /// Number of octaves to analyze
    num_octaves: usize = 6,
    /// Number of bins to search for peak on either side of a given frequency
    num_bins: usize = 4,
    /// Number of partials to take in to account
    num_partials: usize = 3,
};

config: Config,
allocator: Allocator,
buffer_size: usize,
real_buffer: []f32,
imag_buffer: []f32,
window_fn: []f32,
pitches: [12]f32,
chroma: [12]f32,
samplerate: u32,

pub fn init(allocator: Allocator, config: Config, samplerate: u32) !Chroma {
    const buffer_size = config.frame_size * config.padding_factor;

    const real_buffer = try allocator.alloc(f32, buffer_size);
    const imag_buffer = try allocator.alloc(f32, buffer_size);
    const window_fn = try allocator.alloc(f32, config.frame_size);

    const Nf: f32 = @floatFromInt(config.frame_size);
    for (window_fn, 0..) |*w, n| {
        const nf: f32 = @floatFromInt(n);
        const x = nf / Nf;
        const a0 = config.window_a0;
        w.* = a0 - (1 - a0) * std.math.cos(2.0 * std.math.pi * x);
    }

    var chroma: Chroma = .{
        .config = config,
        .allocator = allocator,
        .buffer_size = buffer_size,
        .real_buffer = real_buffer,
        .imag_buffer = imag_buffer,
        .window_fn = window_fn,
        .pitches = undefined,
        .chroma = undefined,
        .samplerate = samplerate,
    };

    // TODO: other cool temperaments?
    const mul = std.math.pow(f32, 2.0, 1.0 / 12.0);
    var freq = config.low_c_freq;
    for (&chroma.pitches) |*p| {
        p.* = freq;
        freq *= mul;
    }

    return chroma;
}

pub fn deinit(self: *Chroma) void {
    self.allocator.free(self.real_buffer);
    self.allocator.free(self.imag_buffer);
    self.allocator.free(self.window_fn);
}

/// Get the actual frame inside a buffer, without padding
fn frame(self: *Chroma, buffer: []f32) []f32 {
    const start = (self.buffer_size - self.config.frame_size) / 2;
    return buffer[start .. start + self.config.frame_size];
}

/// Get bin index corresponding to frequency
fn binIdFromFrequency(self: *Chroma, freq: f32) usize {
    const fs: f32 = @floatFromInt(self.samplerate);
    const N: f32 = @floatFromInt(self.buffer_size);
    const fi = N * freq / fs;
    return @intFromFloat(@round(fi));
}

pub fn execute(self: *Chroma, samples: []const f32) void {
    std.debug.assert(self.config.frame_size == samples.len);

    // Clear buffers
    @memset(self.real_buffer, 0.0);
    @memset(self.imag_buffer, 0.0);

    // Copy samples and apply windowing function
    const real_frame = self.frame(self.real_buffer);
    @memcpy(real_frame, samples);
    for (real_frame, self.window_fn) |*r, w| {
        r.* *= w;
    }

    // Apply FFT
    fft.sfft(self.real_buffer, self.imag_buffer, .forward);

    // Compute magnitude spectrum
    // TODO: another sqrt as specified in paper?
    // TODO: use vectors?
    for (self.real_buffer, self.imag_buffer) |*r, i| {
        r.* = @sqrt(@sqrt(r.* * r.* + i * i));
    }

    // Compute chromagram
    @memset(&self.chroma, 0.0);
    for (&self.chroma, 0..) |*c, n| {
        for (0..self.config.num_octaves) |o| {
            const fund = self.pitches[n] * std.math.pow(f32, 2.0, @floatFromInt(o));
            for (1..self.config.num_partials + 1) |h| {
                const hf: f32 = @floatFromInt(h);
                const freq = fund * hf;
                const bin_center = self.binIdFromFrequency(freq);
                const bins = self.real_buffer[bin_center - self.config.num_bins .. bin_center + self.config.num_bins];
                const peak = std.mem.max(f32, bins);
                c.* += peak / hf / hf;
            }
        }
    }

    // Normalize chromagram
    // var norm: f32 = 0.0;
    // for (self.chroma) |c| {
    //     norm += c * c;
    // }
    // norm = @sqrt(norm);
    // if (norm > 0.001) {
    //     for (&self.chroma) |*c| {
    //         c.* /= norm;
    //     }
    // }
    const max = std.mem.max(f32, &self.chroma);
    if (max > 0.001) {
        for (&self.chroma) |*c| {
            c.* /= max;
        }
    }
}
