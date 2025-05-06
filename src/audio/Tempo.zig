const std = @import("std");
const FFT = @import("fft.zig");
const Config = @import("Config.zig");
const Self = @This();

const c32 = std.math.Complex(f32);

const N: usize = 131072 * 2;
const sample_rate = Config.sample_rate;
const band_limits = [_]usize{ 0, 200, 400, 800, 1600, 3200 };
const n_bands: usize = band_limits.len;
const win_len: f32 = 0.4;
const n_pulses: usize = 5;
const bpm_min: f32 = 60;
const bpm_max: f32 = 240;
const bpm_acc: f32 = 1;
const n_bpm: usize = 1 + @as(usize, @ceil((bpm_max - bpm_min) / bpm_acc));

fn idx_to_bpm(idx: usize) f32 {
    return bpm_min + (bpm_max - bpm_min) * @as(f32, @floatFromInt(idx)) / (n_bpm - 1);
}

fn bpm_to_idx(bpm: f32) usize {
    if (n_bpm == 1) {
        return 0;
    } else {
        return @intFromFloat(@round((bpm - bpm_min) * (n_bpm - 1) / (bpm_max - bpm_min)));
    }
}

const Context = struct {
    mtx: std.Thread.Mutex,
    sem: std.Thread.Semaphore,
    buf_ptr: [2]*[N]f32,
    bpm: f32,
    quit: bool,
    buf: [2][N]f32,
    dft: [N]c32,
    bank: [n_bands][N]c32,
    hann: [N]c32,
    filt: [N]c32,
    bpm_graph: [2][n_bpm]f32,
};

thd: std.Thread,
ctx: *Context,
pos: usize,

pub fn init(alloc: std.mem.Allocator) !Self {
    const ctx: *Context = @ptrCast(try alloc.alloc(Context, 1));
    errdefer alloc.free(ctx[0..1]);

    ctx.mtx = .{};
    ctx.sem = .{};
    ctx.buf_ptr[0] = &ctx.buf[0];
    ctx.buf_ptr[1] = &ctx.buf[1];
    ctx.bpm = 0;
    ctx.quit = false;
    @memset(&ctx.buf[1], 0);
    @memset(&ctx.bpm_graph[1], 0);

    return .{
        .thd = try std.Thread.spawn(.{}, thread_main, .{ctx}),
        .ctx = ctx,
        .pos = 0,
    };
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    @atomicStore(bool, &self.ctx.quit, true, .release);
    self.ctx.sem.post();
    self.thd.join();

    alloc.free(self.ctx[0..1]);
}

fn fft_fwd(samples: []c32) void {
    FFT.fft(samples, .forward);
}

fn fft_inv(samples: []c32) void {
    FFT.fft(samples, .inverse);

    for (samples) |*s| {
        s.re /= N;
        s.im /= N;
    }
}

fn find_tempo(ctx: *Context) void {
    // Filterbank step
    {
        ctx.mtx.lock();
        for (0..N) |i| {
            ctx.dft[i] = c32.init(ctx.buf_ptr[1][i], 0);
        }
        ctx.mtx.unlock();
    }
    fft_fwd(&ctx.dft);
    ctx.dft[0] = c32.init(0, 0);

    var band_lo: [n_bands]usize = undefined;
    var band_hi: [n_bands]usize = undefined;

    for (0..n_bands - 1) |i| {
        band_lo[i] = band_limits[i + 0] * N / sample_rate;
        band_hi[i] = band_limits[i + 1] * N / sample_rate;
    }
    band_lo[n_bands - 1] = band_limits[n_bands - 1] * N / sample_rate;
    band_hi[n_bands - 1] = N / 2;

    for (0..n_bands) |i| {
        const l = band_lo[i];
        const h = band_hi[i];
        @memset(&ctx.bank[i], c32.init(0, 0));
        @memcpy(ctx.bank[i][l..h], ctx.dft[l..h]);
        @memcpy(ctx.bank[i][N - h .. N - l], ctx.dft[N - h .. N - l]);
        fft_inv(&ctx.bank[i]);
    }

    // Smoothing step
    const hann_len: usize = win_len * sample_rate;

    @memset(&ctx.hann, c32.init(0, 0));
    for (0..hann_len) |i| {
        const f: f32 = @floatFromInt(i);
        const c = std.math.cos(f * std.math.pi / (hann_len * 2));
        ctx.hann[i] = c32.init(c * c, 0);
    }
    fft_fwd(&ctx.hann);

    for (0..n_bands) |i| {
        for (&ctx.bank[i]) |*s| {
            s.* = c32.init(@abs(s.re), 0);
        }
        fft_fwd(&ctx.bank[i]);

        for (&ctx.bank[i], ctx.hann) |*s, t| {
            s.* = s.mul(t);
        }
        fft_inv(&ctx.bank[i]);
    }

    // Diff-rect step
    for (0..n_bands) |i| {
        var p: f32 = 0;
        var q: f32 = 0;

        for (0..N) |j| {
            if (j < 4) {
                q = 0;
            } else {
                q = @max(ctx.bank[i][j].re - p, 0);
            }

            p = ctx.bank[i][j].re;
            ctx.bank[i][j] = c32.init(q, 0);
        }

        fft_fwd(&ctx.bank[i]);
    }

    // Time comb step
    var e_max: f32 = 0;
    var s_bpm: f32 = 0;
    var bpm_e: [N]f32 = undefined;

    for (0..n_bpm) |bpm_i| {
        const bpm = idx_to_bpm(bpm_i);
        const step: usize = @intFromFloat(@round(60 * sample_rate / bpm));
        var e: f32 = 0;

        @memset(&ctx.filt, c32.init(0, 0));
        for (0..n_pulses) |i| {
            ctx.filt[i * step] = c32.init(1, 0);
        }
        fft_fwd(&ctx.filt);

        for (0..n_bands) |i| {
            for (ctx.bank[i], ctx.filt) |s, t| {
                const v = s.mul(t);
                e += v.re * v.re + v.im * v.im;
            }
        }

        if (e > e_max) {
            e_max = e;
            s_bpm = bpm;
        }

        bpm_e[bpm_i] = e;
    }

    {
        ctx.mtx.lock();
        for (0..n_bpm) |bpm_i| {
            ctx.bpm_graph[1][bpm_i] = bpm_e[bpm_i] / e_max;
        }
        ctx.mtx.unlock();
    }

    @atomicStore(f32, &ctx.bpm, s_bpm, .release);
}

fn thread_main(ctx: *Context) void {
    while (true) {
        ctx.sem.wait();

        if (@atomicLoad(bool, &ctx.quit, .acquire)) {
            return;
        } else {
            find_tempo(ctx);
        }
    }
}

pub fn execute(self: *Self, samples: []const f32) void {
    var p: usize = 0;

    while (p < samples.len) {
        const n = @min(N - self.pos, samples.len - p);
        @memcpy(self.ctx.buf_ptr[0][self.pos .. self.pos + n], samples[p .. p + n]);
        self.pos += n;
        p += n;

        if (self.pos == N) {
            self.ctx.mtx.lock();
            const buf_ptr = self.ctx.buf_ptr;
            self.ctx.buf_ptr[0] = buf_ptr[1];
            self.ctx.buf_ptr[1] = buf_ptr[0];
            self.ctx.mtx.unlock();
            self.ctx.sem.post();

            self.pos = 0;
        }
    }
}

pub fn get_bpm(self: *const Self) f32 {
    return @atomicLoad(f32, &self.ctx.bpm, .acquire);
}

pub fn get_bpm_graph(self: *const Self) []const f32 {
    {
        self.ctx.mtx.lock();
        @memcpy(&self.ctx.bpm_graph[0], &self.ctx.bpm_graph[1]);
        self.ctx.mtx.unlock();
    }
    return &self.ctx.bpm_graph[0];
}
