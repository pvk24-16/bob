const std = @import("std");
const RingBuffer = @import("audio/RingBuffer.zig").RingBuffer;

pub fn main() !void {
    try std.io.getStdOut().writeAll("Hello, my name is Bob\n");

    // Quick demo of ring buffer.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ring = try RingBuffer(u8).init(16, allocator);
    defer ring.deinit();

    // Initialized with all zeros.
    std.log.info("{any}", .{ring.ring});

    // Read gives a slice pointing to a scratch buffer.
    // Hence it is safe for the user to mutate data.
    {
        const data = ring.read();
        data[2] = 7;
        data[3] = 8;
        data[4] = 9;
        std.log.info("{any}", .{data});
        std.log.info("{any}", .{ring.ring});
    }

    {
        // Write some data.
        var write_data = [_]u8{ 4, 8, 100, 42 };
        ring.write(&write_data);
    }

    // Queue like behavior.
    std.log.info("{any}", .{ring.read()});

    // It is safe to write more than buffer capacity.
    {
        var write_data = [_]u8{
            4,   8,   100, 42,
            5,   22,  99,  221,
            187, 33,  22,  90,
            77,  250, 182, 8,
            3,   7,   8,   133,
        };
        ring.write(&write_data);
    }

    std.log.info("{any}", .{ring.read()});
}
