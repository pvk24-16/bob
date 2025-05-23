const std = @import("std");
const builtin = @import("builtin");

/// The audio format is ieee 32-bit float.
const AudioCapturer = @This();

const Config = @import("Config.zig");

pub const Impl = switch (builtin.os.tag) {
    .linux => @import("linux/capture.zig").LinuxImpl,
    .windows => @import("windows/capture.zig").WindowsImpl,
    .macos => @import("mac/capture.zig").MacOSImpl,
    else => @compileError("Unsupported operating system " ++ @tagName(builtin.os.tag)),
};

impl: Impl,

pub fn init(config: Config, allocator: std.mem.Allocator) !AudioCapturer {
    return AudioCapturer{
        .impl = try Impl.init(config, allocator),
    };
}

pub fn deinit(self: *AudioCapturer, allocator: std.mem.Allocator) void {
    self.impl.deinit(allocator);
    self.* = undefined;
}

pub fn start(self: *AudioCapturer) !void {
    return self.impl.start();
}

pub fn stop(self: *AudioCapturer) !void {
    return self.impl.stop();
}

pub fn sample(self: *AudioCapturer) []const f32 {
    return self.impl.sample();
}
