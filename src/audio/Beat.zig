const std = @import("std");
const FFT = @import("fft.zig").FastFourierTransform;
const Config = @import("Config.zig");

const Self = @This();

num_bins: usize,
bin_ints: [128][2]usize,
bin_vals: [128]f32,
fft: FFT,

pub fn init(alloc: std.mem.Allocator) !Self {
    var num_bins: usize = 0;
    var bin_ints: [128][2]usize = undefined;
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
}
