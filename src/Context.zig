//! Holds all data used in API calls
//! TODO: add all the stuff

const std = @import("std");
const Context = @This();

const GuiState = @import("GuiState.zig");
const Client = @import("Client.zig");

gui_state: GuiState,
client: ?Client,

pub fn init(allocator: std.mem.Allocator) Context {
    return .{
        .gui_state = GuiState.init(allocator),
        .client = null,
    };
}

pub fn deinit(self: *Context) void {
    self.gui_state.deinit();
}
