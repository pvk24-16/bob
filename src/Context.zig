//! Holds all data used in API calls
//! TODO: add all the stuff

const std = @import("std");
const Context = @This();

const GuiState = @import("GuiState.zig");

gui_state: GuiState,

pub fn init(allocator: std.mem.Allocator) Context {
    return .{
        .gui_state = GuiState.init(allocator),
    };
}

pub fn deinit(self: *Context) void {
    self.gui_state.deinit();
}
