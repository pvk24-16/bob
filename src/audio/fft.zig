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
