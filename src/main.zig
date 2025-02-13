const std = @import("std");
const g = @import("graphics/graphics.zig");

const AudioCapture = @import("audio/capture.zig").AudioCapturer;
const AudioAnalyzer = @import("audio/audio_analyzer.zig").AudioAnalyzer;
const RingBuffer = @import("audio/RingBuffer.zig").RingBuffer;

const gl = g.gl;
const glfw = g.glfw;

const vec2 = struct { x: f32 = 0, y: f32 = 0 };

const fft_size: comptime_int = 2048;
const bin_size: comptime_int = fft_size / 2;

fn resize(x: i32, y: i32, _: ?*anyopaque) void {
    gl.glViewport(0, 0, x, y);
}

fn keyCallback(key: i32, _: i32, action: i32, _: i32, userdata: ?*anyopaque) void {
    const running: *bool = @ptrCast(@alignCast(userdata.?));

    if (key == glfw.GLFW_KEY_ESCAPE and action == glfw.GLFW_PRESS) {
        running.* = false;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();
    const pid_str = args.next() orelse @panic("No PID provided");

    // --- Audio capture ---
    var cap = try AudioCapture.init(.{
        .process_id = pid_str,
        .sample_rate = 44100,
        .channel_count = 2,
        .window_time = 5,
    }, allocator);
    defer cap.deinit(allocator);

    try cap.start();
    defer cap.stop() catch {};

    // --- Audio analysis ---
    var analyzer = AudioAnalyzer(fft_size).init();
    defer analyzer.deinit();

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
    gl.glBufferData(gl.GL_ARRAY_BUFFER, (bin_size + 1) * @sizeOf(vec2) + 1, null, gl.GL_STREAM_DRAW);

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

    var line: [bin_size + 1]vec2 = undefined;
    line[bin_size] = .{ .x = 1.0, .y = -0.5 };
    for (0..bin_size) |i| {
        const f: f32 = @floatFromInt(i);
        line[i].x = -1.0 + 2 * f / @as(f32, @floatFromInt(bin_size));
        line[i].y = -0.5;
    }

    var sample_ring = try RingBuffer(f32).init(2048, allocator);
    defer sample_ring.deinit();

    var real: [bin_size]f32 = undefined;
    var imaginary: [bin_size]f32 = undefined;

    // --- Main loop ---
    while (running) {
        window.update();
        if (glfw.glfwWindowShouldClose(window.window_handle) == glfw.GLFW_TRUE) {
            running = false;
        }

        const sample = cap.sample();
        sample_ring.write(@constCast(sample));
        analyzer.process(sample_ring.ring);
        analyzer.results(&real, &imaginary);
        for (1..bin_size) |i| {
            line[i].y = @sqrt(real[i] * real[i] + imaginary[i] * imaginary[i]);
            line[i].y *= @floatFromInt(fft_size);
            line[i].y = -1.5 / (@sqrt(30 * line[i].y) + 1) + 1.5;
            line[i].y -= 0.5;
        }

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
    }
}
