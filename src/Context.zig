//! Holds all data used in API calls
//! TODO: add all the stuff
const std = @import("std");
const Context = @This();

const AudioAnalyzer = @import("audio/AudioAnalyzer.zig");
const AudioConfig = @import("audio/Config.zig");
const AudioCapturer = @import("audio/AudioCapturer.zig");
const AudioSplixer = @import("audio/AudioSplixer.zig");
const Config = @import("audio/Config.zig");
const Visualizer = @import("Visualizer.zig");
const GuiState = @import("GuiState.zig");
const Error = @import("Error.zig");
const FFT = @import("audio/fft.zig").FastFourierTransform;
const Flags = @import("flags.zig").Flags;

err: Error,
gui_state: GuiState,
visualizer: ?Visualizer,
capturer: ?AudioCapturer,
analyzer: AudioAnalyzer,
flags: Flags,
window_width: i32,
window_height: i32,
window_did_resize: bool,

pub fn init(allocator: std.mem.Allocator) !Context {
    return Context{
        .err = Error{},
        .gui_state = GuiState.init(allocator),
        .visualizer = null,
        .capturer = null,
        .analyzer = try AudioAnalyzer.init(allocator),
        .flags = Flags{},
        .window_width = 0,
        .window_height = 0,
        .window_did_resize = false,
    };
}

pub fn connect(self: *Context, process_id: []const u8, allocator: std.mem.Allocator) !void {
    if (self.capturer) |_| {
        unreachable;
    }

    const config: AudioConfig = .{ .process_id = process_id };
    self.capturer = try AudioCapturer.init(config, allocator);
    try self.capturer.?.start();
}

pub fn disconnect(self: *Context, allocator: std.mem.Allocator) !void {
    try self.capturer.?.stop();
    self.capturer.?.deinit(allocator);
    self.capturer = null;
}

pub fn processAudio(self: *Context) void {
    if (self.capturer) |*capturer| {
        const sample = capturer.sample();
        self.analyzer.analyze(sample, self.flags);
    }
}

pub fn deinit(self: *Context, allocator: std.mem.Allocator) void {
    self.gui_state.deinit();

    if (self.visualizer) |*visualizer| {
        visualizer.unload();
    }

    if (self.capturer) |*capturer| {
        capturer.stop() catch {
            std.debug.print("Failed to stop capturer.", .{});
        };
        capturer.deinit(allocator);
    }

    self.err.clear(allocator);
    self.analyzer.deinit(allocator);
}
