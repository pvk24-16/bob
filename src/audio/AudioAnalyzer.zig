const std = @import("std");
const AudioAnalyzer = @This();

const AudioCapturer = @import("AudioCapturer.zig");
const AudioSplixer = @import("AudioSplixer.zig");
const FFT = @import("fft.zig").FastFourierTransform;

capturer: AudioCapturer,
splixer: AudioSplixer,
fft: FFT,
