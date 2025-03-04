const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn RingBuffer(comptime T: type) type {
    return struct {
        const Ring = @This();

        allocator: Allocator = undefined,
        ring: []T = undefined,
        scratch: []T = undefined,
        head: usize = undefined,
        capacity: usize = undefined,

        /// Create ring buffer.
        pub fn init(capacity: usize, allocator: Allocator) !Ring {
            var ring_buffer = Ring{};
            ring_buffer.allocator = allocator;
            ring_buffer.head = capacity;
            ring_buffer.capacity = capacity;
            ring_buffer.ring = try allocator.alloc(T, capacity);
            ring_buffer.scratch = try allocator.alloc(T, capacity);

            @memset(ring_buffer.ring, 0);
            @memset(ring_buffer.scratch, 0);

            return ring_buffer;
        }

        /// Destroy ring buffer.
        pub fn deinit(self: *Ring) void {
            self.allocator.free(self.ring);
            self.allocator.free(self.scratch);
        }

        /// Write data to ring buffer.
        pub fn write(self: *Ring, data: []T) void {
            if (data.len > self.capacity) {
                @memcpy(self.ring, data[data.len - self.capacity ..]);
                self.head = self.capacity;
                return;
            }

            const head = @mod(self.head + data.len, self.capacity);

            if (head < self.head) {
                const sep = data.len - head;
                @memcpy(self.ring[self.head..], data[0..sep]);
                @memcpy(self.ring[0..head], data[sep..]);
            } else {
                const end = self.head + data.len;
                @memcpy(self.ring[self.head..end], data);
            }

            self.head = head;
        }

        /// Return a slice holding data.
        pub fn read(self: *Ring) []T {
            @memcpy(self.scratch[self.capacity - self.head ..], self.ring[0..self.head]);
            @memcpy(self.scratch[0 .. self.capacity - self.head], self.ring[self.head..]);

            return self.scratch[0..];
        }
    };
}
