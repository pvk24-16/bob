const std = @import("std");

pub const RingBuffer = struct {
    buffer: []f32,
    ring: []f32,
    head: usize,
    tail: usize,

    /// Initializes a ring buffer, allocating memory.
    pub fn init(n: usize, allocator: std.mem.Allocator) !RingBuffer {
        const buffer = try allocator.alloc(f32, n);
        errdefer allocator.free(buffer);

        const ring = try allocator.alloc(f32, n + 1);
        errdefer allocator.free(ring);

        return RingBuffer{
            .buffer = buffer,
            .ring = ring,
            .head = 0,
            .tail = 0,
        };
    }

    /// Deinitializes a ring buffer, freeing memory.
    pub fn deinit(self: *RingBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
        allocator.free(self.ring);
        self.* = undefined;
    }

    /// Writes contents of buffer to the ring buffer, overwriting old content on overflow.
    pub fn send(self: *RingBuffer, buffer: []const f32) void {
        // Handle case where there are no items.
        if (buffer.len == 0) {
            return;
        }

        // Handle case where every item is replaced.
        if (self.capacity() <= buffer.len) {
            @memcpy(self.ring[0..self.capacity()], buffer[buffer.len - self.capacity() ..]);

            self.head = 0;
            self.tail = self.ring.len - 1;

            return;
        }

        var next_tail = self.tail + buffer.len;

        // Handle case where tail wraps around.
        if (next_tail >= self.ring.len) {
            next_tail -= self.ring.len; // Wrap around

            const remainder = self.ring.len - self.tail;

            @memcpy(self.ring[self.tail..], buffer[0..remainder]);
            @memcpy(self.ring[0..next_tail], buffer[remainder..]);

            self.head = @max(self.head, next_tail + 1); // Mod not required because next_tail < self.ring.len - 1
            self.tail = next_tail;

            return;
        }

        @memcpy(self.ring[self.tail..next_tail], buffer[0..]);

        // If tail is before head and the next tail is after head, then head must be moved, otherwise tail does not pass over head.
        self.head = if (self.tail < self.head and self.head <= next_tail) self.wrap(next_tail + 1) else self.head;
        self.tail = next_tail;
    }

    /// Writes contents of the ring buffer to the scratch buffer, returning the contents.
    pub fn receive(self: *RingBuffer) []const f32 {
        if (self.head == self.tail) {
            return self.buffer[0..0];
        }

        if (self.head < self.tail) {
            const length = self.tail - self.head;

            @memcpy(self.buffer[0 .. length], self.ring[self.head..self.tail]);

            self.tail = self.head;

            return self.buffer[0 .. length];
        }

        const remainder = self.ring.len - self.head;
        const length = remainder + self.tail;

        @memcpy(self.buffer[0..remainder], self.ring[self.head..]);
        @memcpy(self.buffer[remainder .. length], self.ring[0..self.tail]);

        self.tail = self.head;

        return self.buffer[0 .. length];
    }

    /// Returns true if the buffer is currently full, false otherwise.
    pub fn isFull(self: *RingBuffer) bool {
        return self.wrap(self.tail + 1) == self.head;
    }

    /// Returns true if the buffer is currently empty, false otherwise.
    pub fn isEmpty(self: *RingBuffer) bool {
        return self.tail == self.head;
    }

    /// Returns the number of items the ring buffer can hold.
    pub fn capacity(self: *RingBuffer) usize {
        return self.ring.len - 1;
    }

    pub fn wrap(self: *RingBuffer, i: usize) usize {
        return @mod(i, self.ring.len);
    }
};

pub const RollBuffer = struct {
    buf: []f32,
    cap: usize,
    cur: usize,

    /// Initialize, allocating memory.
    pub fn init(n: usize, allocator: std.mem.Allocator) !RollBuffer {
        const buf = try allocator.alloc(f32, n * 2);

        @memset(buf, 0);

        return RollBuffer{
            .buf = buf,
            .cap = n,
            .cur = 0,
        };
    }

    /// Deinitialize, freeing memory.
    pub fn deinit(self: *RollBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.buf);
        self.* = undefined;
    }

    /// Writes new content, overwriting old content on overflow.
    pub fn write(self: *RollBuffer, buf: []const f32) void {
        // Handle case where there are no items.
        if (buf.len == 0) {
            return;
        }

        // Handle case where every item is replaced.
        if (self.cap <= buf.len) {
            @memcpy(self.buf[0..self.cap], buf[buf.len - self.cap ..]);
            @memcpy(self.buf[self.cap..], buf[buf.len - self.cap ..]);

            self.cur = 0;

            return;
        }

        // Copy to middle section.
        @memcpy(self.buf[self.cur .. self.cur + buf.len], buf);

        const start = self.cap + self.cur;
        const end = self.cap + self.cur + buf.len;

        // Handle case where the cursor wraps around.
        if (end > self.buf.len) {
            const head = end - self.buf.len;
            const tail = self.buf.len - start;

            @memcpy(self.buf[start..], buf[0..tail]); // End section.
            @memcpy(self.buf[0..head], buf[tail..]); // Wrapped section.
        } else {
            @memcpy(self.buf[start..end], buf);
        }

        self.cur = @mod(self.cur + buf.len, self.cap);
    }

    /// Read content as a continous slice.
    pub fn read(self: *RollBuffer) []const f32 {
        return self.buf[self.cur..self.cur + self.cap];
    }

    /// Resets all values to zero.
    pub fn clear(self: *RollBuffer) void {
        @memset(self.buf, 0);
    }
};