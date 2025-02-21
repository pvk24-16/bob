const std = @import("std");
const Context = @import("Context.zig");
const GuiState = @import("GuiState.zig");

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
    "register_float_slider",
    "register_checkbox",
    "ui_element_is_updated",
    "get_ui_float_value",
    "get_ui_bool_value",
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

pub fn register_float_slider(context: ?*anyopaque, name: [*c]const u8, min: f32, max: f32, default_value: f32) callconv(.C) c_int {
    const context_: *Context = @alignCast(@ptrCast(context orelse unreachable));
    const element: GuiState.GuiElement = .{
        .name = name,
        .data = .{ .float_slider = .{
            .value = default_value,
            .min = min,
            .max = max,
            .default = default_value,
        } },
    };
    const result = context_.gui_state.registerElement(element);
    return result catch -1;
}

pub fn register_checkbox(context: ?*anyopaque, name: [*c]const u8, default_value: c_int) callconv(.C) c_int {
    const context_: *Context = @alignCast(@ptrCast(context orelse unreachable));
    const element: GuiState.GuiElement = .{
        .name = name,
        .data = .{ .checkbox = .{
            .value = default_value != 0,
            .default = default_value != 0,
        } },
    };
    const result = context_.gui_state.registerElement(element);
    return result catch -1;
}

pub fn ui_element_is_updated(context: ?*anyopaque, handle: c_int) callconv(.C) c_int {
    const context_: *Context = @alignCast(@ptrCast(context orelse unreachable));
    const id: GuiState.InternalIndexType = @intCast(handle);
    const elems = context_.gui_state.getElements();
    return @intFromBool(elems[id].update);
}

pub fn get_ui_float_value(context: ?*anyopaque, handle: c_int) callconv(.C) f32 {
    const context_: *Context = @alignCast(@ptrCast(context orelse unreachable));
    const id: GuiState.InternalIndexType = @intCast(handle);
    const elems = context_.gui_state.getElements();
    const elem = &elems[id];
    const value: f32 = switch (elem.data) {
        .float_slider => |s| s.value,
        else => return 0.0, // TODO: some error code?
    };
    elem.update = false;
    return value;
}

pub fn get_ui_bool_value(context: ?*anyopaque, handle: c_int) callconv(.C) c_int {
    const context_: *Context = @alignCast(@ptrCast(context orelse unreachable));
    const id: GuiState.InternalIndexType = @intCast(handle);
    const elems = context_.gui_state.getElements();
    const elem = &elems[id];
    const value = switch (elem.data) {
        .checkbox => |b| b.value,
        else => return 0, // TODO: some error code?
    };
    elem.update = false;
    return @intFromBool(value);
}

pub fn fill(context: ?*anyopaque, client_api_ptr: *@TypeOf(c.api)) void {
    client_api_ptr.context = context;
    inline for (api_fn_names) |name| {
        @field(client_api_ptr.*, name) = @field(@This(), name);
    }
}
