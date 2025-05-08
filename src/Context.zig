//!
//! Holds all data used in API calls
//!

const std = @import("std");
const Context = @This();

const AudioAnalyzer = @import("audio/AudioAnalyzer.zig");
const AudioConfig = @import("audio/Config.zig");
const AudioCapturer = @import("audio/AudioCapturer.zig");
const AudioSplixer = @import("audio/AudioSplixer.zig");
const Config = @import("audio/Config.zig");
const Client = @import("Client.zig");
const GuiState = @import("GuiState.zig");
const Error = @import("Error.zig");
const FFT = @import("audio/fft.zig").FastFourierTransform;
const Flags = @import("flags.zig").Flags;

/// The current error message
err: Error,

/// The state associated with GUI registered by current visualizer
gui_state: GuiState,

/// The currently selected visualizer, or null if none is selected
client: ?Client,

/// The audio capture backend, if a source process is selected, otherwise null
capturer: ?AudioCapturer,

/// Audio analyzer
analyzer: AudioAnalyzer,

/// Enabled analysises for the current visualizer
flags: Flags,

// Windows size and state
window_width: i32,
window_height: i32,
window_did_resize: bool,

pub fn init(allocator: std.mem.Allocator) !Context {
    return Context{
        .err = Error{},
        .gui_state = GuiState.init(allocator),
        .client = null,
        .capturer = null,
        .analyzer = try AudioAnalyzer.init(allocator),
        .flags = Flags{},
        .window_width = 0,
        .window_height = 0,
        .window_did_resize = false,
    };
}

/// Connect to a process by PID
pub fn connect(self: *Context, process_id: []const u8, allocator: std.mem.Allocator) !void {
    if (self.capturer) |_| {
        unreachable;
    }

    const config: AudioConfig = .{ .process_id = process_id };
    self.capturer = try AudioCapturer.init(config, allocator);
    try self.capturer.?.start();
}

/// Disconnect from connected process
pub fn disconnect(self: *Context, allocator: std.mem.Allocator) !void {
    try self.capturer.?.stop();
    self.capturer.?.deinit(allocator);
    self.capturer = null;
}

/// Run enabled analysis
pub fn processAudio(self: *Context) void {
    if (self.capturer) |*capturer| {
        const sample = capturer.sample();
        self.analyzer.analyze(sample, self.flags);
    }
}

pub fn deinit(self: *Context, allocator: std.mem.Allocator) void {
    self.gui_state.deinit();

    if (self.client) |*client| {
        client.unload();
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
