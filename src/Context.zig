//! Holds all data used in API calls
//! TODO: add all the stuff

const std = @import("std");
const Context = @This();

const GuiState = @import("GuiState.zig");
const Client = @import("Client.zig");
const AudioCapturer = @import("audio/capture.zig").AudioCapturer;
const Error = @import("Error.zig");
const AudioSplixer = @import("audio/AudioSplixer.zig");
const AudioConfig = @import("audio/Config.zig");

gui_state: GuiState,
client: ?Client,
capturer: ?AudioCapturer,
err: Error,
splixer: ?AudioSplixer,

pub fn init(allocator: std.mem.Allocator) Context {
    return .{
        .gui_state = GuiState.init(allocator),
        .client = null,
        .capturer = null,
        .err = Error.init(allocator),
        .splixer = null,
    };
}

pub fn connect(self: *Context, process_id: []const u8, allocator: std.mem.Allocator) !void {
    const config: AudioConfig = .{ .process_id = process_id };
    self.capturer = try AudioCapturer.init(config, allocator);
    self.splixer = try AudioSplixer.init(config.windowSize(), allocator);
    try self.capturer.?.start();
}

pub fn disconnect(self: *Context, allocator: std.mem.Allocator) !void {
    try self.capturer.?.stop();
    self.capturer.?.deinit(allocator);
    self.capturer = null;
    self.splixer.?.deinit(allocator);
    self.splixer = null;
}

pub fn processAudio(self: *Context) void {
    if (self.capturer) |*capturer| {
        self.splixer.?.mix(capturer.sample());
    }
    // TODO: chroma etc...
}

pub fn deinit(self: *Context, allocator: std.mem.Allocator) void {
    self.gui_state.deinit();
    if (self.client) |*client|
        client.unload();
    if (self.capturer) |*capturer|
        capturer.deinit(allocator);
    if (self.splixer) |*splixer|
        splixer.deinit(allocator);
    self.err.deinit();
}
