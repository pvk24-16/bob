const std = @import("std");
const AudioAnalyzer = @This();

const FFT = @import("fft.zig").FastFourierTransform;

spectral_analyzer: FFT,

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
