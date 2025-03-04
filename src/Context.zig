//! Holds all data used in API calls
//! TODO: add all the stuff

const std = @import("std");
const Context = @This();

const GuiState = @import("GuiState.zig");
const Client = @import("Client.zig");
const AudioCapturer = @import("audio/capture.zig").AudioCapturer;

gui_state: GuiState,
client: ?Client,
capturer: ?AudioCapturer,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Context {
    return .{
        .gui_state = GuiState.init(allocator),
        .client = null,
        .capturer = null,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Context) void {
    self.gui_state.deinit();
    if (self.client) |*client|
        client.unload();
    if (self.capturer) |*capturer|
        capturer.deinit(self.allocator);
}
