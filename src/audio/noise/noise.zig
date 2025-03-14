const std = @import("std");
const Config = @import("../Config.zig");

pub const RandomNoiseImpl = struct {
    rand: std.Random.DefaultPrng,
    buffer: []f32,

    pub fn init(config: Config, allocator: std.mem.Allocator) !RandomNoiseImpl {
        _ = config;
        return RandomNoiseImpl{
            .rand = std.Random.DefaultPrng.init(42),
            .buffer = try allocator.alloc(f32, Config.windowSize()),
        };
    }

    pub fn deinit(self: *RandomNoiseImpl, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
        self.* = undefined;
    }

    pub fn start(self: *RandomNoiseImpl) !void {
        _ = self;
    }

    pub fn stop(self: *RandomNoiseImpl) !void {
        _ = self;
    }

    pub fn sample(self: *RandomNoiseImpl) []const f32 {
        for (self.buffer) |*x| {
            x.* = self.rand.random().floatNorm(f32);
        }

        return self.buffer;
    }
};
