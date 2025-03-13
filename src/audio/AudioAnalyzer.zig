const std = @import("std");
const AudioAnalyzer = @This();

const FFT = @import("fft.zig").FastFourierTransform;
const Flags = @import("../flags.zig").Flags;

spectral_analyzer_left: FFT,
spectral_analyzer_right: FFT,
spectral_analyzer_center: FFT,

pub fn init(allocator: std.mem.Allocator) !AudioAnalyzer {
    const spectral_analyzer = try FFT.init(std.math.log2_int_ceil(usize, 4096), 2, .blackman_nuttall, 0.8, allocator);
    errdefer spectral_analyzer.deinit(allocator);

    return AudioAnalyzer{
        .spectral_analyzer = spectral_analyzer,
    };
}

pub fn deinit(self: *AudioAnalyzer, allocator: std.mem.Allocator) void {
    self.spectral_analyzer.deinit(allocator);
    self.* = undefined;
}

pub fn write(self: *AudioAnalyzer, left: []const f32, flags: Flags) void {}

pub fn read