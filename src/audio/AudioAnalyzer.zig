const std = @import("std");
const AudioAnalyzer = @This();

const Config = @import("Config.zig");
const AudioSplixer = @import("AudioSplixer.zig");
const FFT = @import("fft.zig").FastFourierTransform;
const Flags = @import("../flags.zig").Flags;
const Chroma = @import("Chroma.zig");
const Breaks = @import("Breaks.zig");
const Beat = @import("Beat.zig");
const Tempo = @import("Tempo.zig");

splixer: AudioSplixer,
spectral_analyzer_left: FFT,
spectral_analyzer_right: FFT,
spectral_analyzer_center: FFT,
chroma_left: Chroma,
chroma_right: Chroma,
chroma_center: Chroma,
breaks_left: Breaks,
breaks_right: Breaks,
breaks_center: Breaks,
beat_center: Beat,
tempo_center: Tempo,

pub fn init(allocator: std.mem.Allocator) !AudioAnalyzer {
    var splixer = try AudioSplixer.init(Config.windowSize(), allocator);
    errdefer splixer.deinit(allocator);

    var spectral_analyzer_left = try FFT.init(std.math.log2_int_ceil(usize, 4096), 2, .blackman_nuttall, 0.2, allocator);
    errdefer spectral_analyzer_left.deinit(allocator);

    var spectral_analyzer_right = try FFT.init(std.math.log2_int_ceil(usize, 4096), 2, .blackman_nuttall, 0.2, allocator);
    errdefer spectral_analyzer_right.deinit(allocator);

    var spectral_analyzer_center = try FFT.init(std.math.log2_int_ceil(usize, 4096), 2, .blackman_nuttall, 0.2, allocator);
    errdefer spectral_analyzer_center.deinit(allocator);

    var chroma_left = try Chroma.init(allocator, 4096);
    errdefer chroma_left.deinit(allocator);

    var chroma_right = try Chroma.init(allocator, 4096);
    errdefer chroma_right.deinit(allocator);

    var chroma_center = try Chroma.init(allocator, 4096);
    errdefer chroma_center.deinit(allocator);

    var beat_center = try Beat.init(allocator);
    errdefer beat_center.deinit(allocator);

    var tempo_center = try Tempo.init(allocator);
    errdefer tempo_center.deinit(allocator);

    return AudioAnalyzer{
        .splixer = splixer,
        .spectral_analyzer_left = spectral_analyzer_left,
        .spectral_analyzer_right = spectral_analyzer_right,
        .spectral_analyzer_center = spectral_analyzer_center,
        .chroma_left = chroma_left,
        .chroma_right = chroma_right,
        .chroma_center = chroma_center,
        .breaks_left = .{},
        .breaks_right = .{},
        .breaks_center = .{},
        .beat_center = beat_center,
        .tempo_center = tempo_center,
    };
}

pub fn deinit(self: *AudioAnalyzer, allocator: std.mem.Allocator) void {
    self.splixer.deinit(allocator);
    self.spectral_analyzer_left.deinit(allocator);
    self.spectral_analyzer_right.deinit(allocator);
    self.spectral_analyzer_center.deinit(allocator);
    self.chroma_left.deinit(allocator);
    self.chroma_right.deinit(allocator);
    self.chroma_center.deinit(allocator);
    self.beat_center.deinit(allocator);
    self.tempo_center.deinit(allocator);
    self.* = undefined;
}

pub fn analyze(self: *AudioAnalyzer, stereo: []const f32, flags: Flags) void {
    self.splixer.splix(stereo);

    const center = self.splixer.getCenter();
    const left = self.splixer.getLeft();
    const right = self.splixer.getRight();

    if (flags.frequency_mono) {
        self.spectral_analyzer_center.write(center);
        self.spectral_analyzer_center.evaluate();
    }

    if (flags.chromagram_mono) {
        self.chroma_center.execute(center);
    }

    if (flags.breaks_mono) {
        self.breaks_center.execute(center);
    }

    if (flags.pulse_mono) {
        self.beat_center.execute(self.splixer.getCenter());
    }

    if (flags.tempo_mono) {
        self.tempo_center.execute(self.splixer.getCenter());
    }

    if (flags.frequency_stereo) {
        self.spectral_analyzer_left.write(left);
        self.spectral_analyzer_right.write(right);
        self.spectral_analyzer_left.evaluate();
        self.spectral_analyzer_right.evaluate();
    }

    if (flags.chromagram_stereo) {
        self.chroma_left.execute(left);
        self.chroma_right.execute(right);
    }

    if (flags.breaks_stereo) {
        self.breaks_left.execute(left);
        self.breaks_right.execute(right);
    }
}
