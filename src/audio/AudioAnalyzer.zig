const std = @import("std");
const AudioAnalyzer = @This();

const Config = @import("Config.zig");
const AudioSplixer = @import("AudioSplixer.zig");
const FFT = @import("fft.zig").FastFourierTransform;
const Flags = @import("../flags.zig").Flags;

splixer: AudioSplixer,
spectral_analyzer_left: FFT,
spectral_analyzer_right: FFT,
spectral_analyzer_center: FFT,

pub fn init(allocator: std.mem.Allocator) !AudioAnalyzer {
    var splixer = try AudioSplixer.init(Config.windowSize(), allocator);
    errdefer splixer.deinit(allocator);

    var spectral_analyzer_left = try FFT.init(std.math.log2_int_ceil(usize, 4096), 2, .blackman_nuttall, 0.2, allocator);
    errdefer spectral_analyzer_left.deinit(allocator);

    var spectral_analyzer_right = try FFT.init(std.math.log2_int_ceil(usize, 4096), 2, .blackman_nuttall, 0.2, allocator);
    errdefer spectral_analyzer_right.deinit(allocator);

    var spectral_analyzer_center = try FFT.init(std.math.log2_int_ceil(usize, 4096), 2, .blackman_nuttall, 0.2, allocator);
    errdefer spectral_analyzer_center.deinit(allocator);

    return AudioAnalyzer{
        .splixer = splixer,
        .spectral_analyzer_left = spectral_analyzer_left,
        .spectral_analyzer_right = spectral_analyzer_right,
        .spectral_analyzer_center = spectral_analyzer_center,
    };
}

pub fn deinit(self: *AudioAnalyzer, allocator: std.mem.Allocator) void {
    self.splixer.deinit(allocator);
    self.spectral_analyzer_left.deinit(allocator);
    self.spectral_analyzer_right.deinit(allocator);
    self.spectral_analyzer_center.deinit(allocator);
    self.* = undefined;
}

pub fn analyze(self: *AudioAnalyzer, stereo: []const f32, flags: Flags) void {
    self.splixer.mix(stereo);

    if (flags.frequency_mono) {
        self.spectral_analyzer_center.write(self.splixer.getCenter());
        self.spectral_analyzer_center.evaluate();
        // std.log.debug("Mono result {any}", .{self.spectral_analyzer_center.read()[100..116]});
    }

    if (flags.frequency_stereo) {
        self.spectral_analyzer_left.write(self.splixer.getLeft());
        self.spectral_analyzer_right.write(self.splixer.getRight());
        self.spectral_analyzer_left.evaluate();
        self.spectral_analyzer_right.evaluate();
    }
}
