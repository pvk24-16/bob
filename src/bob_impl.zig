const std = @import("std");
const bob = @import("bob.zig");
const glfw = @import("graphics/glfw.zig");
const Context = @import("Context.zig");
const GuiState = @import("GuiState.zig");

fn checkSignature(comptime name: []const u8) void {
    const t1 = @TypeOf(@field(bob.api, name));
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
    "register_int_slider",
    "register_checkbox",
    "ui_element_is_updated",
    "get_ui_float_value",
    "get_ui_int_value",
    "get_ui_bool_value",
    "register_colorpicker",
    "get_ui_colorpicker_value",
    "set_chromagram_c3",
    "set_chromagram_num_octaves",
    "set_chromagram_num_partials",
};

comptime {
    for (api_fn_names) |name| checkSignature(name);
}

pub fn get_time_data(context: ?*anyopaque, channel: c_int) callconv(.C) bob.bob_float_buffer {
    const ctx: *const Context = @ptrCast(@alignCast(context.?));
    const data = switch (channel) {
        bob.BOB_MONO_CHANNEL => ctx.analyzer.splixer.getCenter(),
        bob.BOB_LEFT_CHANNEL => ctx.analyzer.splixer.getLeft(),
        bob.BOB_RIGHT_CHANNEL => ctx.analyzer.splixer.getRight(),
        else => @panic("API function called with invalid BOB_*_CHANNEL"),
    };

    const buffer: bob.bob_float_buffer = .{
        .ptr = @ptrCast(data.ptr),
        .size = data.len,
    };

    return buffer;
}

pub fn get_frequency_data(context: ?*anyopaque, channel: c_int) callconv(.C) bob.bob_float_buffer {
    // _ = .{ context, channel };
    // const buffer: bob.bob_float_buffer = std.mem.zeroes(bob.bob_float_buffer);
    const ctx: *const Context = @ptrCast(@alignCast(context.?));

    const data = switch (channel) {
        bob.BOB_MONO_CHANNEL => ctx.analyzer.spectral_analyzer_center.read(),
        bob.BOB_LEFT_CHANNEL => ctx.analyzer.spectral_analyzer_left.read(),
        bob.BOB_RIGHT_CHANNEL => ctx.analyzer.spectral_analyzer_right.read(),
        else => @panic("Bad API call"),
    };

    const buffer: bob.bob_float_buffer = .{
        .ptr = @ptrCast(data.ptr),
        .size = data.len,
    };
    return buffer;
}

pub fn get_chromagram(context: ?*anyopaque, buf: [*c]f32, channel: c_int) callconv(.C) void {
    const ctx: *const Context = @ptrCast(@alignCast(context.?));

    const data = switch (channel) {
        bob.BOB_MONO_CHANNEL => &ctx.analyzer.chroma_center.chroma,
        bob.BOB_LEFT_CHANNEL => &ctx.analyzer.chroma_left.chroma,
        bob.BOB_RIGHT_CHANNEL => &ctx.analyzer.chroma_right.chroma,
        else => @panic("Bad API call"),
    };

    var buf_slice: []f32 = undefined;
    buf_slice.ptr = @ptrCast(buf);
    buf_slice.len = 12;

    @memcpy(buf_slice, data);
}

pub fn get_pulse_data(context: ?*anyopaque, channel: c_int) callconv(.C) bob.bob_float_buffer {
    _ = .{ context, channel };
    const buffer: bob.bob_float_buffer = std.mem.zeroes(bob.bob_float_buffer);
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

pub fn register_int_slider(context: ?*anyopaque, name: [*c]const u8, min: c_int, max: c_int, default_value: c_int) callconv(.C) c_int {
    const context_: *Context = @alignCast(@ptrCast(context orelse unreachable));
    const element: GuiState.GuiElement = .{
        .name = name,
        .data = .{ .int_slider = .{
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

pub fn register_colorpicker(context: ?*anyopaque, name: [*c]const u8, default_color: [*c]f32) callconv(.C) c_int {
    const context_: *Context = @alignCast(@ptrCast(context orelse unreachable));
    var element: GuiState.GuiElement = .{
        .name = name,
        .data = .{ .colorpicker = .{
            .rgb = undefined,
        } },
    };

    var default_slice: []f32 = undefined;
    default_slice.ptr = @ptrCast(default_color.?);
    default_slice.len = 3;
    @memcpy(&element.data.colorpicker.rgb, default_slice);

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

pub fn get_ui_int_value(context: ?*anyopaque, handle: c_int) callconv(.C) c_int {
    const context_: *Context = @alignCast(@ptrCast(context orelse unreachable));
    const id: GuiState.InternalIndexType = @intCast(handle);
    const elems = context_.gui_state.getElements();
    const elem = &elems[id];
    const value: c_int = switch (elem.data) {
        .int_slider => |s| s.value,
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

pub fn get_ui_colorpicker_value(context: ?*anyopaque, handle: c_int, color: [*c]f32) callconv(.C) void {
    const context_: *Context = @alignCast(@ptrCast(context orelse unreachable));
    const id: GuiState.InternalIndexType = @intCast(handle);
    const elems = context_.gui_state.getElements();
    const elem = &elems[id];
    const value = switch (elem.data) {
        .colorpicker => |b| &b.rgb,
        else => return, // TODO: some error code?
    };

    var color_slice: []f32 = undefined;
    color_slice.ptr = @ptrCast(color.?);
    color_slice.len = 3;
    @memcpy(color_slice, value);

    elem.update = false;
}
pub fn set_chromagram_c3(context: ?*anyopaque, pitch: f32) callconv(.C) void {
    const context_: *Context = @alignCast(@ptrCast(context.?));
    context_.analyzer.chroma_left.c3 = pitch;
    context_.analyzer.chroma_right.c3 = pitch;
    context_.analyzer.chroma_center.c3 = pitch;
}

pub fn set_chromagram_num_octaves(context: ?*anyopaque, num: usize) callconv(.C) void {
    const context_: *Context = @alignCast(@ptrCast(context.?));
    context_.analyzer.chroma_left.num_octaves = num;
    context_.analyzer.chroma_right.num_octaves = num;
    context_.analyzer.chroma_center.num_octaves = num;
}

pub fn set_chromagram_num_partials(context: ?*anyopaque, num: usize) callconv(.C) void {
    const context_: *Context = @alignCast(@ptrCast(context.?));
    context_.analyzer.chroma_left.num_partials = num;
    context_.analyzer.chroma_right.num_partials = num;
    context_.analyzer.chroma_center.num_partials = num;
}

pub fn fill(context: ?*anyopaque, client_api_ptr: *@TypeOf(bob.api)) void {
    client_api_ptr.context = context;
    client_api_ptr.get_proc_address = @ptrCast(&glfw.glfwGetProcAddress);
    inline for (api_fn_names) |name| {
        @field(client_api_ptr.*, name) = @field(@This(), name);
    }
}
