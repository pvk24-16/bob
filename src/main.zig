const std = @import("std");
const g = @import("graphics/graphics.zig");

const AudioCapture = @import("audio/capture.zig").AudioCapturer;
const AudioAnalyzer = @import("audio/audio_analyzer.zig").AudioAnalyzer;
const RingBuffer = @import("audio/RingBuffer.zig").RingBuffer;
const Chroma = @import("audio/Chroma.zig");

const gl = g.gl;
const glfw = g.glfw;

const Vertex = extern struct {
    x: f32,
    y: f32,
    temp: f32,
    intensity: f32,
};

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
    const sample_rate: u32 = 44100;
    var cap = try AudioCapture.init(.{
        .process_id = pid_str,
        .sample_rate = sample_rate,
        .channel_count = 2,
        .window_time = 10,
    }, allocator);
    defer cap.deinit(allocator);

    try cap.start();
    defer cap.stop() catch {};

    // --- Window ---
    var running = true;
    var window = try g.window.Window(8).init();
    window.setUserPointer();
    defer window.deinit();

    glfw.glfwWindowHint(glfw.GLFW_SAMPLES, 4);

    try window.pushCallback(&resize, null, .resize);
    try window.pushCallback(&keyCallback, &running, .keyboard);

    // --- OpenGL ---
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
    gl.glEnable(gl.GL_BLEND);
    gl.glEnable(gl.GL_MULTISAMPLE);

    var vbo: u32 = 0;
    gl.glGenBuffers(1, @ptrCast(&vbo));
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo);

    // Create vertex positions
    var vertices: [12]Vertex = undefined;
    for (0.., &vertices) |i, *v| {
        // We multiply by 7 to get a perfect fifth between adjacent vertices
        const fi: f32 = @floatFromInt((7 * i % 12));
        const angle = 2.0 * std.math.pi * fi / 12.0;
        const r = 0.8;
        const x = r * std.math.cos(angle);
        const y = r * std.math.sin(angle);
        var temp = (2.0 * fi / 12.0 - 1);
        temp = 1.0 - temp * temp;
        const intensity = 0.0;
        v.* = .{
            .x = x,
            .y = y,
            .temp = temp,
            .intensity = intensity,
        };
    }

    // var ibo: u32 = 0;
    // gl.glGenBuffers(1, @ptrCast(&ibo));
    // gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, ibo);

    var index_buffer = std.ArrayList(u32).init(allocator);
    defer index_buffer.deinit();

    // Create connections between pitch classes
    for (0..12) |i| {
        for (i + 1..12) |j| {
            try index_buffer.append(@intCast(i));
            try index_buffer.append(@intCast(j));
        }
    }

    gl.glBufferData(
        gl.GL_ELEMENT_ARRAY_BUFFER,
        @intCast(@sizeOf(f32) * index_buffer.items.len),
        @ptrCast(index_buffer.items.ptr),
        gl.GL_STATIC_DRAW,
    );

    var vao: u32 = 0;
    gl.glGenVertexArrays(1, @ptrCast(&vao));
    gl.glBindVertexArray(vao);

    gl.glVertexAttribPointer(
        0,
        2,
        gl.GL_FLOAT,
        gl.GL_FALSE,
        @sizeOf(Vertex),
        @ptrFromInt(@offsetOf(Vertex, "x")),
    );
    gl.glVertexAttribPointer(
        1,
        1,
        gl.GL_FLOAT,
        gl.GL_FALSE,
        @sizeOf(Vertex),
        @ptrFromInt(@offsetOf(Vertex, "temp")),
    );
    gl.glVertexAttribPointer(
        2,
        1,
        gl.GL_FLOAT,
        gl.GL_FALSE,
        @sizeOf(Vertex),
        @ptrFromInt(@offsetOf(Vertex, "intensity")),
    );

    gl.glEnableVertexAttribArray(0);
    gl.glEnableVertexAttribArray(1);
    gl.glEnableVertexAttribArray(2);

    var shader = try g.shader.Shader.init(
        @embedFile("shaders/default.vert"),
        @embedFile("shaders/default.frag"),
    );
    defer shader.deinit();
    shader.bind();

    gl.glEnable(gl.GL_LINE_SMOOTH);
    gl.glLineWidth(2.0);

    var chroma = try Chroma.init(allocator, .{}, sample_rate);
    defer chroma.deinit();

    // --- Main loop ---
    while (running) {
        window.update();
        if (glfw.glfwWindowShouldClose(window.window_handle) == glfw.GLFW_TRUE) {
            running = false;
        }

        // Compute chromagram
        const frame = cap.sample();
        std.debug.assert(frame.len >= chroma.config.frame_size);
        chroma.execute(frame);

        // Update vertex intensities
        for (&vertices, chroma.chroma) |*v, c| {
            const speed = 0.07;
            const snap = 0.001;
            const target = std.math.pow(f32, c, 7.0);
            const diff = target - v.intensity;
            if (diff > snap) {
                v.intensity = target;
            } else {
                v.intensity += speed * diff;
            }
        }

        // Draw the stuff
        gl.glBufferData(
            gl.GL_ARRAY_BUFFER,
            @intCast(@sizeOf(Vertex) * vertices.len),
            @ptrCast((&vertices).ptr),
            gl.GL_STATIC_DRAW,
        );

        gl.glClearColor(0.1, 0.1, 0.1, 0.7);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        gl.glDrawElements(
            gl.GL_LINES,
            @intCast(index_buffer.items.len),
            gl.GL_UNSIGNED_INT,
            @ptrCast(index_buffer.items.ptr),
        );

        const stdout = std.io.getStdOut().writer();
        try stdout.print("\x1b[2K\r", .{});
        for (chroma.chroma) |c| {
            try stdout.print("{d:.2} ", .{c});
        }
    }
}
