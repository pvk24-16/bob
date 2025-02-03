const std = @import("std");
const fft = @import("fft.zig").sfft;

const tau = std.math.tau;

pub fn AudioAnalyzer(comptime capacity: usize) type {
    if (capacity == 0) @compileError("Capacity must be greater than 0");
    if (capacity & (capacity - 1) != 0) @compileError("Capacity must be a power of 2");

    return struct {
        const Analyzer = @This();

        fft_size: usize = capacity,
        bins: usize = capacity / 2,
        re: [capacity]f32 = undefined,
        im: [capacity]f32 = undefined,
        prev_re: [capacity]f32 = undefined,
        prev_im: [capacity]f32 = undefined,

        smoothing_constant: f32 = 0.8,

        /// Create audio analyzer.
        pub fn init() Analyzer {
            var analyzer = Analyzer{};
            @memset(&analyzer.re, 0.0);
            @memset(&analyzer.im, 0.0);
            @memset(&analyzer.prev_re, 0.0);
            @memset(&analyzer.prev_im, 0.0);
            return analyzer;
        }

        /// Destroy audio analyzer. Zeros out memory.
        pub fn deinit(self: *Analyzer) void {
            self.* = Analyzer{};
            @memset(&self.re, 0.0);
            @memset(&self.im, 0.0);
            @memset(&self.prev_re, 0.0);
            @memset(&self.prev_im, 0.0);
        }

        // Assumend mono channel, would require
        // down sampling otherwise.
        /// Process audio data.
        pub fn process(self: *Analyzer, data: []f32) void {

            // Copy previous data for temporal smooth.
            @memcpy(&self.prev_re, &self.re);
            @memcpy(&self.prev_im, &self.im);
            // Copy data to float array, zero out imaginary part.
            @memcpy(&self.re, data);
            @memset(&self.im, 0.0);

            self.blackmanWindow();
            fft(&self.re, &self.im, .forward);
            self.re[0] = 0.0;
            self.im[0] = 0.0;
            self.temporalSmooth();
        }

        /// Get processed fourier data.
        pub fn results(self: *Analyzer, re: []f32, im: []f32) void {
            if (re.len != self.bins or im.len != self.bins) @panic("Bin length missmatch");
            @memcpy(re, self.re[0..self.bins]);
            @memcpy(im, self.im[0..self.bins]);
        }

        inline fn blackmanWindow(self: *Analyzer) void {
            const N: f32 = @floatFromInt(capacity);
            const a: f32 = 0.16;
            const a0: f32 = (1 - a) / 2;
            const a1: f32 = 1.0 / 2.0;
            const a2: f32 = a / 2.0;

            for (&self.re) |*n| {
                const w = a0 - a1 * @cos(tau * n.* / N) + a2 * @cos(2 * tau * n.* / N);
                n.* = n.* * w;
            }
        }

        inline fn temporalSmooth(self: *Analyzer) void {
            for (0..capacity) |i| {
                const a_re: f32 = self.smoothing_constant * self.prev_re[i];
                const b_re: f32 = (1.0 - self.smoothing_constant) * @abs(self.re[i]);
                const a_im: f32 = self.smoothing_constant * self.prev_im[i];
                const b_im: f32 = (1.0 - self.smoothing_constant) * @abs(self.im[i]);
                var res_re = a_re + b_re;
                var res_im = a_im + b_im;
                if (std.math.isNan(res_re) or std.math.isInf(res_re)) res_re = 1.0;
                if (std.math.isNan(res_im) or std.math.isInf(res_im)) res_im = 1.0;
                self.re[i] = res_re;
                self.im[i] = res_im;
            }
        }
    };
}
