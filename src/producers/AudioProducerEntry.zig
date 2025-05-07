name: [256:0]u8,

// This will a number on most reasonable platforms encoded in ASCII.
// TODO: Ideally, we'd just use a u64 here and assume that we aren't running on some super strange OS. But the rest of the code base already assumes text based PID.
process_id: [12:0]u8,

const std = @import("std");
pub const List = std.ArrayList(@This());
