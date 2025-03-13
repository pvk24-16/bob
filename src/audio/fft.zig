const std = @import("std");
const math = std.math;
pub const c32 = math.Complex(f32);

pub const Direction = enum { forward, inverse };

inline fn isPowerOfTwo(n: usize) bool {
    return n & (n - 1) == 0;
}

/// In place fast fourier transform.
pub fn fft(data: []c32, direction: Direction) void {
    if (data.len < 2) unreachable;
    if (!isPowerOfTwo(data.len)) unreachable;
    fft_shuffle(data);
    fft_eval(data, direction);
}

/// Bit-reversal.
inline fn fft_shuffle(data: []c32) void {
    const mid: u32 = @intCast(data.len >> 1);
    const mask: u32 = @intCast(data.len - 1);

    var i: u32 = 0;
    var j: u32 = 0;
    while (i < data.len) {
        if (j > i) {
            const tmp: c32 = data[i];
            data[i] = data[j];
            data[j] = tmp;
        }

        const lszb: u32 = ~i & (i +% 1);
        const mszb: u32 = mid / lszb;
        const bits: u32 = mask & ~(mszb -% 1);

        j ^= bits;
        i += 1;
    }
}

inline fn fft_eval(data: []c32, dir: Direction) void {
    const log2_n: u32 = @intCast(math.log2_int(usize, data.len));
    const tau: f32 = if (dir == .forward) -math.tau else math.tau;

    var m: u32 = undefined;
    var m_mid: u32 = undefined;
    var n: u32 = undefined;
    var k: u32 = undefined;
    var i_e: u32 = undefined;
    var i_o: u32 = undefined;

    var theta: f32 = undefined;

    var wm: c32 = undefined;
    var wmk: c32 = undefined;
    var u: c32 = undefined;
    var t: c32 = undefined;

    var r: u32 = 1;
    while (r <= log2_n) {
        m = @as(u32, 1) << @truncate(r);
        m_mid = m >> 1;
        theta = tau / @as(f32, @floatFromInt(m));
        wm.re = @cos(theta);
        wm.im = @sin(theta);
        n = 0;
        while (n < data.len) {
            wmk.re = 1.0;
            wmk.im = 0.0;
            k = 0;
            while (k < m_mid) {
                i_e = n + k;
                i_o = i_e + m_mid;
                u = data[i_e];
                t = wmk.mul(data[i_o]);
                data[i_e] = u.add(t);
                data[i_o] = u.sub(t);
                t = wmk.mul(wm);
                wmk = t;
                k += 1;
            }
            n += m;
        }
        r += 1;
    }
}

/// In place fast fourier transform.
/// Real and imaginary parts are separated.
pub fn sfft(re: []f32, im: []f32, direction: Direction) void {
    if (re.len != im.len) unreachable;
    if (re.len < 2) unreachable;
    if (!isPowerOfTwo(re.len)) unreachable;
    sfft_shuffle(re, im);
    sfft_eval(re, im, direction);
}

inline fn sfft_shuffle(re: []f32, im: []f32) void {
    // We asserted real and imaginary prats have the same length.
    const mid: u32 = @intCast(re.len >> 1);
    const mask: u32 = @intCast(re.len - 1);

    var i: u32 = 0;
    var j: u32 = 0;
    while (i < re.len) {
        if (j > i) {
            const tmp_re: f32 = re[i];
            const tmp_im: f32 = im[i];
            re[i] = re[j];
            im[i] = im[j];
            re[j] = tmp_re;
            im[j] = tmp_im;
        }

        const lszb: u32 = ~i & (i +% 1);
        const mszb: u32 = mid / lszb;
        const bits: u32 = mask & ~(mszb -% 1);

        j ^= bits;
        i += 1;
    }
}

inline fn sfft_eval(re: []f32, im: []f32, dir: Direction) void {
    // We made sure real and imaginary part ahve the same length.
    const log2_n: u32 = @intCast(math.log2_int(usize, re.len));
    const tau: f32 = if (dir == .forward) -math.tau else math.tau;

    var m: u32 = undefined;
    var m_mid: u32 = undefined;
    var n: u32 = undefined;
    var k: u32 = undefined;
    var i_e: u32 = undefined;
    var i_o: u32 = undefined;

    var theta: f32 = undefined;

    var wm: c32 = undefined;
    var wmk: c32 = undefined;
    var u: c32 = undefined;
    var t: c32 = undefined;
    var tmp: c32 = undefined;

    var r: u32 = 1;
    while (r <= log2_n) {
        m = @as(u32, 1) << @truncate(r);
        m_mid = m >> 1;
        theta = tau / @as(f32, @floatFromInt(m));
        wm.re = @cos(theta);
        wm.im = @sin(theta);
        n = 0;
        while (n < re.len) {
            wmk.re = 1.0;
            wmk.im = 0.0;
            k = 0;
            while (k < m_mid) {
                i_e = n + k;
                i_o = i_e + m_mid;

                u.re = re[i_e];
                u.im = im[i_e];

                t = wmk.mul(.{
                    .re = re[i_o],
                    .im = im[i_o],
                });

                tmp = u.add(t);
                re[i_e] = tmp.re;
                im[i_e] = tmp.im;

                tmp = u.sub(t);
                re[i_o] = tmp.re;
                im[i_o] = tmp.im;

                t = wmk.mul(wm);
                wmk = t;
                k += 1;
            }
            n += m;
        }
        r += 1;
    }
}

pub const FastFourierTransform = struct {
    result: []f32,
    scratch: []c32,
    window: []f32,
    cursor: usize,
    window_coefficients: []const f32,
    bit_reversal_lookup_table: []const u32,
    smoothing_factor: f32,
    scaling_factor: f32,

    /// The user guarantees `init` and `deinit` are called with the same allocator.
    pub fn init(capacity_log2: usize, padding_log2: usize, window_function: WindowFunction, smoothing_factor: f32, allocator: std.mem.Allocator) !FastFourierTransform {
        const capacity: usize = std.math.pow(usize, 2, capacity_log2);
        const padding: usize = capacity * std.math.pow(usize, 2, padding_log2) - capacity;

        const result: []f32 = try allocator.alloc(f32, (capacity + padding) / 2);
        errdefer allocator.free(result);

        const scratch: []c32 = try allocator.alloc(c32, capacity + padding);
        errdefer allocator.free(scratch);

        const window: []f32 = try allocator.alloc(f32, capacity);
        errdefer allocator.free(window);

        const window_coefficients: []f32 = try allocator.alloc(f32, capacity);
        errdefer allocator.free(window_coefficients);

        const bit_reversal_lookup_table: []u32 = try initBitReversalLookupTable(capacity, allocator);
        errdefer allocator.free(bit_reversal_lookup_table);

        @memset(result, 0);
        @memset(scratch, c32.init(0, 0));
        @memset(window, 0);

        for (0..capacity) |i| {
            window_coefficients[i] = window_function.call(capacity, i);
        }

        return FastFourierTransform{
            .result = result,
            .scratch = scratch,
            .window = window,
            .cursor = 0,
            .window_coefficients = window_coefficients,
            .bit_reversal_lookup_table = bit_reversal_lookup_table,
            .smoothing_factor = @max(0.0, @min(1.0, smoothing_factor)),
            .scaling_factor = window_function.scale() / @as(f32, @floatFromInt(result.len)),
        };
    }

    /// The user guarantees `init` and `deinit` are called with the same allocator.
    pub fn deinit(self: *FastFourierTransform, allocator: std.mem.Allocator) void {
        allocator.free(self.result);
        allocator.free(self.scratch);
        allocator.free(self.window);
        allocator.free(self.window_coefficients);
        allocator.free(self.bit_reversal_lookup_table);

        self.* = undefined;
    }

    /// Writes time domain data.
    pub fn write(self: *FastFourierTransform, buffer: []const f32) void {
        if (buffer.len == 0) {
            return;
        }

        if (buffer.len >= self.window.len) {
            @memcpy(self.window[0..], buffer[buffer.len - self.window.len ..]);

            self.cursor = 0;

            return;
        }

        const next_cursor = buffer.len + self.cursor;

        if (next_cursor > self.window.len) {
            @memcpy(self.window[self.cursor..], buffer[0 .. self.window.len - self.cursor]);
            @memcpy(self.window[0 .. next_cursor - self.window.len], buffer[self.window.len - self.cursor ..]);
        } else {
            @memcpy(self.window[self.cursor..next_cursor], buffer);
        }

        self.cursor = next_cursor & (self.window.len - 1);
    }

    /// Reads frequency domain data as magnitudes.
    pub fn read(self: *FastFourierTransform) []f32 {
        @memset(self.scratch[self.window.len..], c32.init(0, 0));

        const end = self.window.len - self.cursor;

        for (self.window[self.cursor..], self.window_coefficients[0..end], self.bit_reversal_lookup_table[0..end]) |x, c, i| {
            self.scratch[i] = c32.init(c * x, 0);
        }

        for (self.window[0..self.cursor], self.window_coefficients[end..], self.bit_reversal_lookup_table[end..]) |x, c, i| {
            self.scratch[i] = c32.init(c * x, 0);
        }

        // Don't mind if I do...
        fft_eval(self.scratch, .forward);

        // Exponential Moving Average (EMA) smoothing
        for (self.scratch[0 .. self.scratch.len >> 1], 0..) |z, i| {
            self.result[i] = self.smoothing_factor * self.scaling_factor * z.magnitude() + (1.0 - self.smoothing_factor) * self.result[i];
        }

        return self.result;
    }

    /// Zeroes internal buffers.
    pub fn clear(self: *FastFourierTransform) void {
        @memset(self.result, 0);
        @memset(self.scratch, c32.init(0, 0));
        @memset(self.window, 0);

        self.cursor = 0;
    }

    pub fn inputLength(self: *FastFourierTransform) usize {
        return self.window.len;
    }

    pub fn outputLength(self: *FastFourierTransform) usize {
        return self.result.len;
    }

    fn initBitReversalLookupTable(capacity: usize, allocator: std.mem.Allocator) ![]u32 {
        // Capacity must be a power of two.
        std.debug.assert(@popCount(capacity) == 1);

        var table = try allocator.alloc(u32, capacity);
        errdefer allocator.free(table);

        const mid: u32 = @intCast(capacity >> 1);
        const mask: u32 = @intCast(capacity - 1);

        var i: u32 = 0;
        var j: u32 = 0;

        while (i < capacity) {
            table[i] = j;

            const lszb: u32 = ~i & (i +% 1);
            const mszb: u32 = mid / lszb;
            const bits: u32 = mask & ~(mszb -% 1);

            j ^= bits;
            i += 1;
        }

        return table;
    }
};

pub const WindowFunction = enum {
    rectangular,
    triangualar,
    hann,
    hamming,
    nuttal,
    blackman,
    blackman_nuttall,
    blackman_harris,

    pub fn call(self: WindowFunction, n: usize, i: usize) f32 {
        const n_: f32 = @floatFromInt(n);
        const i_: f32 = @floatFromInt(i);

        return switch (self) {
            .rectangular => rectangularImpl(),
            .triangualar => triangularImpl(n_, i_),
            .hann => hannImpl(n_, i_),
            .hamming => hammingImpl(n_, i_),
            .nuttal => nuttallImpl(n_, i_),
            .blackman => blackmanImpl(n_, i_),
            .blackman_nuttall => blackmanNuttallImpl(n_, i_),
            .blackman_harris => blackmanHarrisImpl(n_, i_),
            else => @panic("Unimplemented window function"),
        };
    }

    pub fn scale(self: WindowFunction) f32 {
        return switch (self) {
            .rectangular => 1.0,
            .triangualar => 2.0,
            .hann => 2.0,
            .hamming => 1.85,
            .nuttal => 2.75,
            .blackman => 2.38,
            .blackman_nuttall => 2.75,
            .blackman_harris => 2.79,
            else => @panic("Unimplemented window function"),
        };
    }

    fn rectangularImpl() f32 {
        return 1.0;
    }

    fn triangularImpl(n: f32, i: f32) f32 {
        return 1.0 - @abs((i - (n / 2)) / (n / 2));
    }

    fn hannImpl(n: f32, i: f32) f32 {
        return @sin(std.math.pi * i / n) * @sin(std.math.pi * i / n);
    }

    fn hammingImpl(n: f32, i: f32) f32 {
        const a0 = 0.53836;
        const a1 = 0.46164;

        return a0 - a1 * std.math.cos(std.math.tau * i / n);
    }

    fn nuttallImpl(n: f32, i: f32) f32 {
        const cos = std.math.cos;
        const tau = std.math.tau;
        const a0 = 0.355768;
        const a1 = 0.487396;
        const a2 = 0.144232;
        const a3 = 0.012604;

        return a0 - a1 * cos(tau * i / n) + a2 * cos(2 * tau * i / n) - a3 * cos(3 * tau * i / n);
    }

    fn blackmanImpl(n: f32, i: f32) f32 {
        const cos = std.math.cos;
        const tau = std.math.tau;
        const a0 = 0.42659;
        const a1 = 0.49656;
        const a2 = 0.076849;

        return a0 - a1 * cos(tau * i / n) + a2 * cos(2 * tau * i / n);
    }

    fn blackmanNuttallImpl(n: f32, i: f32) f32 {
        const cos = std.math.cos;
        const tau = std.math.tau;
        const a0 = 0.3635819;
        const a1 = 0.4891775;
        const a2 = 0.1365995;
        const a3 = 0.0106411;

        return a0 - a1 * cos(tau * i / n) + a2 * cos(2 * tau * i / n) - a3 * cos(3 * tau * i / n);
    }

    fn blackmanHarrisImpl(n: f32, i: f32) f32 {
        const cos = std.math.cos;
        const tau = std.math.tau;
        const a0 = 0.35875;
        const a1 = 0.48829;
        const a2 = 0.14128;
        const a3 = 0.01168;

        return a0 - a1 * cos(tau * i / n) + a2 * cos(2 * tau * i / n) - a3 * cos(3 * tau * i / n);
    }
};

pub const ScalingFunction = enum {
    none,
    log,
    log2,
    log10,
    mel,

    pub fn call(self: ScalingFunction, x: f32) f32 {
        return switch (self) {
            .none => x,
            .log => @log(x),
            .log2 => @log2(x),
            .log10 => @log10(x),
            .mel => 2595.0 * std.math.log10(1 + x / 700.0),
        };
    }

    pub fn apply(self: ScalingFunction, buf: []f32) void {
        switch (self) {
            .none => {},
            .log => {
                for (0..buf.len) |i| buf[i] = @log(buf[i]);
            },
            .log2 => {
                for (0..buf.len) |i| buf[i] = @log2(buf[i]);
            },
            .log10 => {
                for (0..buf.len) |i| buf[i] = @log10(buf[i]);
            },
            .mel => {
                for (0..buf.len) |i| buf[i] = 2595.0 * std.math.log10(1 + buf[i] / 700.0);
            },
        }
    }
};

// TODO: Implement
pub const SmoothingFunction = enum {
    none,
    simple_moving_average,
    exponential_moving_average,
    gaussian,
    butterworth,
    chebyshev_golay,

    pub fn call(self: SmoothingFunction, n: usize, i: usize) f32 {
        _ = n;
        _ = i;

        return switch (self) {
            .none => noneImpl(),
            else => @compileError("Unimplemented"),
        };
    }

    fn noneImpl(i: usize, x: f32) f32 {
        _ = i;
        return x;
    }
};

// const mid: u32 = @intCast(self.window.len >> 1);
// const mask: u32 = @intCast(self.window.len - 1);

// var i: u32 = 0;
// var j: u32 = 0;

// while (i + self.cursor < self.window.len) {
//     if (i < j) {
//         const c = 1; //self.window_coefficients[i];
//         const x = self.window[i + self.cursor];

//         self.scratch[j] = c32.init(c * x, 0);
//     }

//     const lszb: u32 = ~i & (i +% 1);
//     const mszb: u32 = mid / lszb;
//     const bits: u32 = mask & ~(mszb -% 1);

//     j ^= bits;
//     i += 1;
// }

// while (i < self.window.len) {
//     if (i < j) {
//         const c = 1; //self.window_coefficients[i];
//         const x = self.window[i + self.cursor - self.window.len];

//         self.scratch[j] = c32.init(c * x, 0);
//     }

//     const lszb: u32 = ~i & (i +% 1);
//     const mszb: u32 = mid / lszb;
//     const bits: u32 = mask & ~(mszb -% 1);

//     j ^= bits;
//     i += 1;
// }
