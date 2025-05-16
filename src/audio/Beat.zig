const std = @import("std");
const FFT = @import("fft.zig").FastFourierTransform;
const Config = @import("Config.zig");

const Self = @This();

const H: usize = 43;
const C_dflt: f32 = 1.185;
const Vl_dflt: f32 = -6.968;
const max_bins: usize = 64;

num_bins: usize,
bin_ints: [max_bins][2]usize,
bin_vals: [max_bins]f32,
fft: FFT,
C: f32,
Vl: f32,
Ei: [max_bins][H]f32,
Eh: [max_bins]f32,

pub fn init(alloc: std.mem.Allocator) !Self {
    var num_bins: usize = 0;
    var bin_ints: [max_bins][2]usize = undefined;
    const fft_len = 2048;

    {
        const b: f32 = std.math.pow(f32, 2.0, 8.0 / 12.0);
        var n: f32 = b;
        var i: usize = 0;
        var j: usize = 0;

        while (j < fft_len) {
            var k = j;

            while (k == j) {
                n = n * b;
                k = @intFromFloat(n);
            }

            bin_ints[i][0] = j;
            bin_ints[i][1] = k;
            i += 1;
            j = k;
        }

        num_bins = i;
    }

    return .{
        .num_bins = num_bins,
        .bin_ints = bin_ints,
        .bin_vals = undefined,
        .fft = try FFT.init(
            12,
            2,
            .rectangular,
            1.0,
            alloc,
        ),
        .C = C_dflt,
        .Vl = Vl_dflt,
        .Ei = .{.{0} ** H} ** max_bins,
        .Eh = .{0} ** max_bins,
    };
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.fft.deinit(alloc);
}

pub fn execute(self: *Self, samples: []const f32) void {
    self.fft.write(samples);
    self.fft.evaluate();
    const spect = self.fft.read();

    for (0..self.num_bins) |i| {
        const int = self.bin_ints[i];

        self.bin_vals[i] = 0;

        for (int[0]..int[1]) |j| {
            self.bin_vals[i] += spect[j];
        }

        self.bin_vals[i] = self.bin_vals[i] / @as(f32, @floatFromInt(int[1] - int[0]));
    }

    const C = self.C;
    const V = std.math.pow(f32, 10, self.Vl);
    const B = self.num_bins;

    for (0..B) |i| {
        const s = self.bin_vals[i];
        var a: f32 = 0;
        var v: f32 = 0;

        for (0..H) |j| {
            a = a + self.Ei[i][j];
        }

        a = a / H;

        for (0..H) |j| {
            const p = self.Ei[i][j] - a;

            v = v + p * p;
        }

        v = v / H;

        for (0..H - 1) |j| {
            self.Ei[i][j + 1] = self.Ei[i][j];
        }
        self.Ei[i][0] = s;

        if (s > C * a and v > V) {
            self.Eh[i] = 1;
        } else {
            self.Eh[i] = 0;
        }
    }
}
