// TODO Delete this.

const std = @import("std");

const RingBuffer = @import("RingBuffer.zig").RingBuffer(f32);
const Allocator = std.mem.Allocator;

const Base = @This();

pub const Error = error{
    start_capture,
    stop_capture,
    resume_capture,
    pause_capture,
};

ring: RingBuffer = undefined,
mutex: std.Thread.Mutex = .{},
thread: ?std.Thread = null,
capture_running: bool = false,

/// Create capture base.
pub fn init(capacity: usize, allocator: Allocator) !Base {
    return .{ .ring = try RingBuffer.init(capacity, allocator) };
}

/// Destroy capture base.
pub fn deinit(self: *Base) void {
    self.ring.deinit();
}
