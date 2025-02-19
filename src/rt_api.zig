const std = @import("std");

const c = @cImport({
    @cInclude("bob.h");
});

fn checkSignature(comptime name: []const u8) void {
    const t1 = @TypeOf(@field(c.api, name));
    const t2 = ?*const @TypeOf(@field(@This(), name));
    if (t1 != t2) {
        @compileError("API signature mismatch for '" ++ name ++ "': "
        //
        ++ @typeName(t1) ++ " and " ++ @typeName(t2));
    }
}

const api_fn_names: []const []const u8 = &.{
    "get_time_data",
    "get_frequency_data",
    "get_chromagram",
    "get_pulse_data",
    "get_tempo",
};

comptime {
    for (api_fn_names) |name| checkSignature(name);
}

pub fn get_time_data(context: ?*anyopaque, channel: c_int) callconv(.C) c.bob_float_buffer {
    _ = .{ context, channel };
    const buffer: c.bob_float_buffer = std.mem.zeroes(c.bob_float_buffer);
    return buffer;
}

pub fn get_frequency_data(context: ?*anyopaque, channel: c_int) callconv(.C) c.bob_float_buffer {
    _ = .{ context, channel };
    const buffer: c.bob_float_buffer = std.mem.zeroes(c.bob_float_buffer);
    return buffer;
}

pub fn get_chromagram(context: ?*anyopaque, buf: [*c]f32, channel: c_int) callconv(.C) void {
    _ = .{ context, buf, channel };
}

pub fn get_pulse_data(context: ?*anyopaque, channel: c_int) callconv(.C) c.bob_float_buffer {
    _ = .{ context, channel };
    const buffer: c.bob_float_buffer = std.mem.zeroes(c.bob_float_buffer);
    return buffer;
}

pub fn get_tempo(context: ?*anyopaque, channel: c_int) callconv(.C) f32 {
    _ = .{ context, channel };
    return 0.0;
}

// ... more API functions

pub fn fill(context: ?*anyopaque, client_api_ptr: *@TypeOf(c.api)) void {
    client_api_ptr.context = context;
    inline for (api_fn_names) |name| {
        @field(client_api_ptr.*, name) = @field(@This(), name);
    }
}
