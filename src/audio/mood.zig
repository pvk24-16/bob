const std = @import("std");
const FFT = @import("fft.zig").FastFourierTransform;
const Tempo = @import("Tempo.zig");

const s: f32 = @floatFromInt(@import("Config.zig").sample_rate);

// https://sites.tufts.edu/eeseniordesignhandbook/2015/music-mood-classification/
// Intensity increases with rms
// Timbre increases with zero-crossing rate
// Pitch increases with spectral centroid

const max_pitch = 1000.0;
const max_rhythm = 250.0;

// Must be kept in sync with the bob api
pub const Mood = enum(c_int) {
    happy = 0,
    exuberant = 1,
    energetic = 2,
    frantic = 3,
    anxious = 4,
    depression = 5,
    calm = 6,
    contentment = 7,

    fn values(comptime self: Mood) [2]comptime_float {
        return switch (self) {
            .happy => .{ 0.2055, 0.4418 }, // 967.47 / max_pitch, 209.01 / max_rhythm
            .exuberant => .{ 0.3170, 0.4265 }, // 611.94 / max_pitch, 177.7 / max_rhythm
            .energetic => .{ 0.4564, 0.3190 }, // 381.65 / max_pitch, 163.14 / max_rhythm
            .frantic => .{ 0.2827, 0.6376 }, // 239.78 / max_pitch, 189.03 / max_rhythm
            .anxious => .{ 0.2245, 0.1572 }, // 95.654 / max_pitch, 137.23 / max_rhythm
            .depression => .{ 0.1177, 0.2280 }, // 212.65 / max_pitch, 122.65 / max_rhythm
            .calm => .{ 0.0658, 0.1049 }, // 383.49 / max_pitch, 72.23 / max_rhythm
            .contentment => .{ 0.1482, 0.2114 }, // 756.65 / max_pitch, 101.73 / max_rhythm
        };
    }
};

pub const MoodAnalyzer = struct {
    fft: FFT,
    scratch: []f32, // harmonic_product_spectrum and zero_crossing_rate
    mood: Mood,
    scores: [8]f32,

    pub fn init(allocator: std.mem.Allocator) !MoodAnalyzer {
        var fft = try FFT.init(11, 1, .hann, 0.5, allocator);
        errdefer fft.deinit(allocator);

        const scratch = try allocator.alloc(f32, @max(fft.inputLength(), fft.outputLength()));
        errdefer allocator.free(scratch);

        return MoodAnalyzer{
            .fft = fft,
            .scratch = scratch,
            .mood = .happy,
            .scores = .{0.0} ** 8,
        };
    }

    pub fn deinit(self: *MoodAnalyzer, allocator: std.mem.Allocator) void {
        self.fft.deinit(allocator);
        allocator.free(self.scratch);
    }

    pub fn analyze(self: *MoodAnalyzer, audio: []const f32) void {
        const alpha = 0.01;

        self.fft.write(audio);
        self.fft.evaluate();

        const intensity: f32 = rootMeanSquare(self.fft.read());
        const timbre: f32 = self.spectralFlatness();
        const values = [_]f32{ intensity, timbre };

        inline for (std.meta.fields(Mood)) |m| {
            const mood: Mood = @field(Mood, m.name);
            var dist: f32 = 0.0;

            inline for (values, mood.values()) |x, y| {
                dist += (x - y) * (x - y);
            }

            const score = 1.0 / (dist + 1e-6);
            self.scores[@intFromEnum(mood)] = alpha * score + (1.0 - alpha) * self.scores[@intFromEnum(mood)];
        }

        var best_mood = Mood.happy;
        var best_score: f32 = 0.0;

        inline for (std.meta.fields(Mood)) |m| {
            const mood: Mood = @field(Mood, m.name);

            if (self.scores[@intFromEnum(mood)] > best_score) {
                best_mood = mood;
                best_score = self.scores[@intFromEnum(mood)];
            }
        }

        self.mood = best_mood;
    }

    pub fn read(self: *const MoodAnalyzer) Mood {
        return self.mood;
    }

    fn rootMeanSquare(magnitudes: []const f32) f32 {
        var sum: f32 = 0.0;

        for (magnitudes) |x| {
            sum += x * x; // Already normalized
        }

        return @sqrt(sum);
    }

    fn zeroCrossingRate(self: *const MoodAnalyzer) f32 {
        var sum: u32 = 0;

        const end = self.scratch.len - self.fft.cursor;

        for (self.fft.window[self.fft.cursor..], 0..) |x, i| {
            self.scratch[i] = x;
        }

        for (self.fft.window[0..self.fft.cursor], end..) |x, i| {
            self.scratch[i] = x;
        }

        const n = self.fft.inputLength();

        for (self.scratch[1..n], self.scratch[0 .. n - 1]) |x, y| {
            const a: i32 = @intFromBool(x >= 0.0);
            const b: i32 = @intFromBool(y >= 0.0);
            sum += @abs(a - b);
        }

        return @as(f32, @floatFromInt(sum)) / @as(f32, @floatFromInt(n));
    }

    fn spectralFlatness(self: *const MoodAnalyzer) f32 {
        const n: f32 = @floatFromInt(self.fft.outputLength());
        var geo: f32 = 0;
        var arith: f32 = 0;

        for (self.fft.read()) |m| {
            geo += @log(@max(m, 1e-12));
            arith += m;
        }

        const geometric_mean = @exp(geo / n);
        const arithmetic_mean = @max(arith / n, 1e-12);

        return geometric_mean / arithmetic_mean;
    }

    fn spectralCentroid(self: *const MoodAnalyzer) f32 {
        var sum_1: f32 = 0;
        var sum_2: f32 = 0;

        for (self.fft.read(), 0..) |x, i| {
            sum_1 += x * @as(f32, @floatFromInt(i));
            sum_2 += x;
        }

        return (0.5 * s * sum_1) / (sum_2 * (@as(f32, @floatFromInt(self.fft.outputLength())) - 1));
    }
};

// Tempo classification:
//  * fast: >120 bpm, +valence, +-arousal,
//  * medium: 76-120 bpm, -valence, +arousal
//  * slow: 60-76 bpm (we will generalize to <76), +-valence, +-arousal
//  * source: https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2018.02118/full

// Loudness classification:
//
//
//

// https://www.nature.com/articles/s41598-024-78156-1#:~:text=weak%20or%20non,EA%2C%20TA%2C%20dominance%2C%20and%20affiliation

fn energy(fft: *const FFT) f32 {
    var sum: f32 = 0.0;

    for (fft.read()) |x| {
        sum += x * x;
    }

    return sum / s;
}

// Typical proportions: 0.95, 0.90, 0.75, 0.50
fn spectralRolloff(fft: *const FFT, comptime proportion: f32) f32 {
    if (proportion < 0.0 or 1.0 < proportion) {
        @compileError("Spectral rolloff proportion must fall within 0.0 and 1.0");
    }

    var sum_1: f32 = 0;
    var sum_2: f32 = 0;

    for (fft.read()) |x| {
        sum_1 += x;
    }

    sum_1 *= proportion;

    for (fft.read(), 0..) |x, r| {
        sum_2 += x;

        if (sum_1 <= sum_2) {
            return 0.5 * s / @as(f32, @floatFromInt(r * (fft.outputLength() - 1)));
        }

        r += 1;
    }

    return 0.5 * s;
}

// // Pass the value returned by spectralCentroid, or recompute it by passing {}.
// pub fn spectralBandwidth(fft: *FFT, centroid: anytype) f32 {
//     const T: type = @TypeOf(centroid);
//     const c: f32 = switch (T) {
//         f32 => centroid,
//         void => spectralCentroid(fft),
//         else => @compileError("Expected f32 or void, found " ++ @typeName(T)),
//     };

//     const n: f32 = @floatFromInt(fft.inputLength());
//     var x: f32 = 0;
//     var y: f32 = 0;

//     for (fft.read(), 0..) |m, i| {
//         const f = @as(f32, @floatFromInt(i)) * s / n;
//         const t = f - c;
//         x += m * t * t;
//         y += m;
//     }

//     return @sqrt(x / y);
// }

// pub fn spectralCentroid(fft: *FFT) f32 {
//     const n: f32 = @floatFromInt(fft.inputLength());
//     var x: f32 = 0;
//     var y: f32 = 0;

//     for (fft.read(), 0..) |m, i| {
//         const f = @as(f32, @floatFromInt(i)) * s / n;

//         x += m * f;
//         y += m;
//     }

//     return x / y;
// }
