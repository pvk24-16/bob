const FFT: type = @import("fft.zig").FastFourierTransform;
const s: f32 = @floatFromInt(@import("Config.zig").sample_rate);

// https://sites.tufts.edu/eeseniordesignhandbook/2015/music-mood-classification/

// high zero crossing rate AND  THEN high energy

const Mood = enum {
    // +-intensity +-timbre ++pitch ++rhythm
    happy,
    //  +intensity +-timbre  +pitch  +rhythm
    exuberant,
    // ++intensity +-timbre +-pitch  +rhythm
    energetic,
    //  +intensity ++timbre  -pitch ++rhythm
    frantic,
    // +-intensity --timbre --pitch  -rhythm
    anxious,
    //  -intensity  -timbre  -pitch  -rhythm
    depression,
    // --intensity --timbre +-pitch --rhythm
    calm,
    //  -intensity  -timbre  +pitch  -rhythm
    contentment,
    // Intensity increases with rms
    // Timbre increases with zero-crossing rate and
    // Rhythm increases with tempo
};

// Tempo
// Chroma
// Loudness: rms
// Brightness: centroid

pub fn get_mood(fft: *FFT) f32 {
    _ = fft;
}

pub fn energy(fft: *FFT) f32 {
    var sum: f32 = 0.0;

    for (fft.read()) |x| {
        sum += x * x;
    }

    return sum / s;
}

pub fn rootMeanSquare(fft: *FFT) f32 {
    var sum: f32 = 0.0;

    for (fft.read()) |x| {
        sum += x * x;
    }

    return @sqrt(sum / @as(f32, @floatFromInt(fft.outputLength())));
}

pub fn zeroCrossingRate(fft: *FFT) f32 {
    const n = fft.outputLength();
    var sum: u32 = 0;

    for (fft.read()[1..], fft.read()[0 .. n - 1]) |x, y| {
        const a: i32 = @intFromBool(x >= 0.0);
        const b: i32 = @intFromBool(y >= 0.0);
        sum += @abs(a - b);
    }

    return s * @as(f32, @floatFromInt(sum)) / @as(f32, @floatFromInt(n));
}

pub fn spectralCentroid(fft: *FFT) f32 {
    var sum_1 = 0;
    var sum_2 = 0;

    for (fft.read(), 0..) |x, i| {
        sum_1 += x * @as(f32, @floatFromInt(i));
        sum_2 += x;
    }

    return (0.5 * s * sum_1) / (sum_2 * (@as(f32, @floatFromInt(fft.outputLength())) - 1));
}

pub fn spectralFlatness(fft: *FFT) f32 {
    const n: f32 = @floatFromInt(fft.outputLength());
    var geo: f32 = 0;
    var arith: f32 = 0;

    for (fft.read()) |m| {
        geo += @log(@max(m, 1e-12));
        arith += m;
    }

    const geometric_mean = @exp(geo / n);
    const arithmetic_mean = arith / n;

    return geometric_mean / arithmetic_mean;
}

// Typical proportions: 0.95, 0.90, 0.75, 0.50
pub fn spectralRolloff(fft: *FFT, comptime proportion: f32) f32 {
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
