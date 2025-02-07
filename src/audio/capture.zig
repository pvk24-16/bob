const std = @import("std");
const os_tag = @import("builtin").os.tag;
const Allocator = std.mem.Allocator;

// Requires Tiger-style initialization.
const AudioCapture = @This();

const Impl = switch (os_tag) {
    .windows => @import("windows/capture.zig"),
    .linux => @import("linux/capture.zig"),
    else => @compileError("OS not supported " ++ @tagName(os_tag)),
};

impl: Impl = .{},

/// Create audio capture.
pub inline fn init(
    self: *AudioCapture,
    process_str: []const u8,
    capacity: usize,
    allocator: Allocator,
) !void {
    try self.impl.init(process_str, capacity, allocator);
}

/// Destroy audio capture.
pub inline fn deinit(self: *AudioCapture) void {
    self.impl.deinit();
}

/// Get an audio sample.
pub inline fn getSample(self: *AudioCapture) []f32 {
    self.impl.base.mutex.lock();
    defer self.impl.base.mutex.unlock();
    return self.impl.base.ring.read();
}

/// Start capture.
pub inline fn startCapture(self: *AudioCapture) !void {
    try self.impl.startCapture();
}

/// Stop capture.
pub inline fn stopCapture(self: *AudioCapture) !void {
    try self.impl.stopCapture();
}

/// Retrieve sample rate.
pub inline fn sampleRate(self: *AudioCapture) u32 {
    return self.impl.sampleRate();
}
