const std = @import("std");

pub const AudioSplixer = struct {
    left: []f32,
    right: []f32,
    center: []f32,
    capacity: usize,

    pub fn init(capacity: usize, allocator: std.mem.Allocator) !AudioSplixer {
        const buf = try allocator.alloc(f32, capacity * 3);

        return AudioSplixer{
            .left = buf[capacity * 2 .. capacity * 2],
            .right = buf[capacity..capacity],
            .center = buf[0..0],
            .capacity = capacity,
        };
    }

    pub fn deinit(self: *AudioSplixer, allocator: std.mem.Allocator) void {
        allocator.free(self.center.ptr[0 .. self.capacity * 3]);
        self.* = undefined;
    }

    pub fn mix(self: *AudioSplixer, stereo: []const f32) void {
        std.debug.assert(stereo.len <= self.capacity << 1);

        self.left.len = stereo.len;
        self.right.len = stereo.len;
        self.center.len = stereo.len;

        for (0..stereo.len >> 1) |i| {
            const l = stereo[(i << 1) + 0];
            const r = stereo[(i << 1) + 1];

            self.left[i] = l;
            self.right[i] = r;
            self.center[i] = (l + r) / 2;
        }
    }

    pub fn getLeft(self: *const AudioSplixer) []const f32 {
        return self.left;
    }

    pub fn getRight(self: *const AudioSplixer) []const f32 {
        return self.right;
    }

    pub fn getCenter(self: *const AudioSplixer) []const f32 {
        return self.center;
    }
};
