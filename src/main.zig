const std = @import("std");
const g = @import("graphics/graphics.zig");

const AudioConfig = @import("audio/Config.zig");
const AudioCapture = @import("audio/capture.zig").AudioCapturer;
const AudioSplixer = @import("audio/splix.zig").AudioSplixer;
const FFT = @import("audio/fft.zig").FastFourierTransform;

const gl = g.gl;
const glfw = g.glfw;

const vec2 = struct { x: f32 = 0, y: f32 = 0 };

fn resize(x: i32, y: i32, _: ?*anyopaque) void {
    gl.glViewport(0, 0, x, y);
}

fn keyCallback(key: i32, _: i32, action: i32, _: i32, userdata: ?*anyopaque) void {
    const running: *bool = @ptrCast(@alignCast(userdata.?));

    if (key == glfw.GLFW_KEY_ESCAPE and action == glfw.GLFW_PRESS) {
        running.* = false;
    }
}

const fft_length = 1024;
const bin_length = 512;

pub fn main() !void {
    // -- Allocator --
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // -- Process ID --
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();
    const pid_str = args.next() orelse @panic("No PID provided");

    // --- Audio config ---
    const config = AudioConfig{
        .process_id = pid_str,
        .window_time = 100,
    };

    // --- Audio capture ---
    var cap = try AudioCapture.init(config, allocator);
    defer cap.deinit(allocator);

    try cap.start();
    defer cap.stop() catch {};

    // --- Audio splixing ---
    var splix = try AudioSplixer.init(config.windowSize(), allocator);
    defer splix.deinit(allocator);

    // --- Audio analysis ---
    var fft = try FFT.init(
        10,
        0,
        .blackman_harris,
        0.8,
        allocator,
    );
    defer fft.deinit(allocator);

    std.debug.assert(fft_length == fft.inputLength());
    std.debug.assert(bin_length == fft.outputLength());

    // --- Window ---
    var running = true;
    var window = try g.window.Window(8).init();
    window.setUserPointer();
    defer window.deinit();

    try window.pushCallback(&resize, null, .resize);
    try window.pushCallback(&keyCallback, &running, .keyboard);

    // --- OpenGL ---
    var line_vbo: u32 = 0;
    gl.glGenBuffers(1, @ptrCast(&line_vbo));
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, line_vbo);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, (bin_length + 1) * @sizeOf(vec2) + 1, null, gl.GL_STREAM_DRAW);

    var line_vao: u32 = 0;
    gl.glGenVertexArrays(1, @ptrCast(&line_vao));
    gl.glBindVertexArray(line_vao);
    gl.glEnableVertexAttribArray(0);
    gl.glVertexAttribPointer(0, 2, gl.GL_FLOAT, gl.GL_FALSE, @sizeOf(vec2), null);

    gl.glBindVertexArray(0);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);

    var shader = try g.shader.Shader.init(
        @embedFile("shaders/default.vert"),
        @embedFile("shaders/default.frag"),
    );
    defer shader.deinit();

    gl.glEnable(gl.GL_LINE_SMOOTH);
    gl.glLineWidth(1.25);

    var line: [bin_length + 1]vec2 = undefined;
    line[bin_length] = .{ .x = 1.0, .y = -0.5 };
    for (0..bin_length) |i| {
        line[i].x = xScaling(i, bin_length, .linear);
    }

    //const out = std.io.getStdOut().writer();
    //var buffer = std.io.bufferedWriter(out);
    //var writer = buffer.writer();

    var timer = try std.time.Timer.start();
    var render_median: u64 = 0;
    var render_median_buf = [7]u64{ 0, 0, 0, 0, 0, 0, 0 };
    var capture_median: u64 = 0;
    var capture_median_buf = [7]u64{ 0, 0, 0, 0, 0, 0, 0 };

    // --- Main loop ---
    while (running) {
        window.update();
        if (glfw.glfwWindowShouldClose(window.window_handle) == glfw.GLFW_TRUE) {
            running = false;
        }

        timer.reset();
        const sample = cap.sample();
        splix.mix(sample);
        const center = splix.getCenter();
        fft.write(center);
        const fft_result = fft.read();
        capture_median = rollingMedian(capture_median_buf[0..], timer.lap());
        // for (sample, 0..) |x, i| {
        //     if (i >= 4) break;
        //     try writer.print("{}\t", .{x});
        // }
        // try writer.print("\n", .{});
        // try buffer.flush();

        for (1..bin_length) |i| {
            line[i].y = fft_result[i];
        }

        timer.reset();

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, line_vbo);
        gl.glBufferSubData(gl.GL_ARRAY_BUFFER, 0, @sizeOf(vec2) * line.len, @ptrCast(line[0..]));
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);

        gl.glClearColor(0.0, 0.0, 0.0, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        shader.bind();
        gl.glBindVertexArray(line_vao);

        gl.glDrawArrays(gl.GL_LINE_STRIP, 0, @intCast(line.len));

        gl.glBindVertexArray(0);
        shader.unbind();

        render_median = rollingMedian(render_median_buf[0..], timer.lap());
    }

    // std.debug.print("avg capture time {} ms\n", .{capture_median / 1000000});
    // std.debug.print("avg render time {} ms\n", .{render_median / 1000000});
}

fn rollingMedian(buf: []u64, x: u64) u64 {
    buf[1 + (buf.len >> 1)] = x;
    std.mem.sort(u64, buf, {}, std.sort.asc(u64));

    var sum: u64 = 0;

    for (buf) |y| {
        sum += y;
    }

    return sum / buf.len;
}

fn xScaling(i: usize, n: usize, scaling: enum { linear, log2a, log2b, mel }) f32 {
    const i_f: f32 = @floatFromInt(i);
    const n_f: f32 = @floatFromInt(n);

    return switch (scaling) {
        .linear => -1.0 + 2 * i_f / n_f,
        .log2a => -1.0 + 2 * @log2(1 + i_f) / @log2(1 + n_f),
        .log2b => -1.0 + 2 * @log2(1 + i_f / n_f),
        .mel => -1.0 + 2 * (1127 * @log(1 + i_f / 700.0)) / n_f,
    };
}
