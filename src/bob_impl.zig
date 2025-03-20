const std = @import("std");
const bob = @import("bob.zig");
const glfw = @import("graphics/glfw.zig");
const Context = @import("Context.zig");
const GuiState = @import("GuiState.zig");
const context = &@import("Context.zig").context;

pub var get_proc_address: *const anyopaque = @ptrCast(&glfw.glfwGetProcAddress);

fn checkSignature(comptime name: []const u8) void {
    const t1 = @TypeOf(@field(bob, "bob_" ++ name));
    const t2 = @TypeOf(@field(@This(), name));

    if (t1 != t2) {
        @compileError("API signature mismatch for '" ++ name ++ "': "
        //
        ++ @typeName(t1) ++ " and " ++ @typeName(t2));
    }
}

comptime {
    checkSignature("get_window_size");
    @export(get_window_size, .{ .name = "bob_get_window_size", .linkage = .strong });

    // checkSignature("get_proc_address");
    @export(get_proc_address, .{ .name = "bob_get_proc_address", .linkage = .strong });

    checkSignature("get_time_data");
    @export(get_time_data, .{ .name = "bob_get_time_data", .linkage = .strong });

    checkSignature("get_frequency_data");
    @export(get_frequency_data, .{ .name = "bob_get_frequency_data", .linkage = .strong });

    checkSignature("get_chromagram");
    @export(get_chromagram, .{ .name = "bob_get_chromagram", .linkage = .strong });

    checkSignature("get_pulse_data");
    @export(get_pulse_data, .{ .name = "bob_get_pulse_data", .linkage = .strong });

    checkSignature("get_tempo");
    @export(get_tempo, .{ .name = "bob_get_tempo", .linkage = .strong });

    checkSignature("register_float_slider");
    @export(register_float_slider, .{ .name = "bob_register_float_slider", .linkage = .strong });

    checkSignature("register_int_slider");
    @export(register_int_slider, .{ .name = "bob_register_int_slider", .linkage = .strong });

    checkSignature("register_checkbox");
    @export(register_checkbox, .{ .name = "bob_register_checkbox", .linkage = .strong });

    checkSignature("register_colorpicker");
    @export(register_colorpicker, .{ .name = "bob_register_colorpicker", .linkage = .strong });

    checkSignature("ui_element_is_updated");
    @export(ui_element_is_updated, .{ .name = "bob_ui_element_is_updated", .linkage = .strong });

    checkSignature("get_ui_float_value");
    @export(get_ui_float_value, .{ .name = "bob_get_ui_float_value", .linkage = .strong });

    checkSignature("get_ui_int_value");
    @export(get_ui_int_value, .{ .name = "bob_get_ui_int_value", .linkage = .strong });

    checkSignature("get_ui_bool_value");
    @export(get_ui_bool_value, .{ .name = "bob_get_ui_bool_value", .linkage = .strong });

    checkSignature("get_ui_colorpicker_value");
    @export(get_ui_colorpicker_value, .{ .name = "bob_get_ui_colorpicker_value", .linkage = .strong });

    checkSignature("set_chromagram_c3");
    @export(set_chromagram_c3, .{ .name = "bob_set_chromagram_c3", .linkage = .strong });

    checkSignature("set_chromagram_num_octaves");
    @export(set_chromagram_num_octaves, .{ .name = "bob_set_chromagram_num_octaves", .linkage = .strong });

    checkSignature("set_chromagram_num_partials");
    @export(set_chromagram_num_partials, .{ .name = "bob_set_chromagram_num_partials", .linkage = .strong });
}

pub fn get_window_size(x: [*c]c_int, y: [*c]c_int) callconv(.C) c_int {
    x.?.* = context.window_width;
    y.?.* = context.window_height;

    if (!context.window_did_resize) {
        return 0;
    }

    context.window_did_resize = false;
    return 1;
}

pub fn get_time_data(channel: c_int) callconv(.C) bob.bob_float_buffer {
    const data = switch (channel) {
        bob.BOB_MONO_CHANNEL => context.analyzer.splixer.getCenter(),
        bob.BOB_LEFT_CHANNEL => context.analyzer.splixer.getLeft(),
        bob.BOB_RIGHT_CHANNEL => context.analyzer.splixer.getRight(),
        else => @panic("API function called with invalid BOB_*_CHANNEL"),
    };

    const buffer: bob.bob_float_buffer = .{
        .ptr = @ptrCast(data.ptr),
        .size = data.len,
    };

    return buffer;
}

pub fn get_frequency_data(channel: c_int) callconv(.C) bob.bob_float_buffer {
    // _ = .{ context, channel };
    // const buffer: bob.bob_float_buffer = std.mem.zeroes(bob.bob_float_buffer);

    const data = switch (channel) {
        bob.BOB_MONO_CHANNEL => context.analyzer.spectral_analyzer_center.read(),
        bob.BOB_LEFT_CHANNEL => context.analyzer.spectral_analyzer_left.read(),
        bob.BOB_RIGHT_CHANNEL => context.analyzer.spectral_analyzer_right.read(),
        else => @panic("Bad API call"),
    };

    const buffer: bob.bob_float_buffer = .{
        .ptr = @ptrCast(data.ptr),
        .size = data.len,
    };
    return buffer;
}

pub fn get_chromagram(buf: [*c]f32, channel: c_int) callconv(.C) void {
    const data = switch (channel) {
        bob.BOB_MONO_CHANNEL => &context.analyzer.chroma_center.chroma,
        bob.BOB_LEFT_CHANNEL => &context.analyzer.chroma_left.chroma,
        bob.BOB_RIGHT_CHANNEL => &context.analyzer.chroma_right.chroma,
        else => @panic("Bad API call"),
    };

    var buf_slice: []f32 = undefined;
    buf_slice.ptr = @ptrCast(buf);
    buf_slice.len = 12;

    @memcpy(buf_slice, data);
}

pub fn get_pulse_data(channel: c_int) callconv(.C) bob.bob_float_buffer {
    _ = .{ context, channel };
    const buffer: bob.bob_float_buffer = std.mem.zeroes(bob.bob_float_buffer);
    return buffer;
}

pub fn get_tempo(channel: c_int) callconv(.C) f32 {
    _ = .{ context, channel };
    return 0.0;
}

pub fn register_float_slider(name: [*c]const u8, min: f32, max: f32, default_value: f32) callconv(.C) c_int {
    const element: GuiState.GuiElement = .{
        .name = name,
        .data = .{ .float_slider = .{
            .value = default_value,
            .min = min,
            .max = max,
            .default = default_value,
        } },
    };

    const result = context.gui_state.registerElement(element);
    return result catch -1;
}

pub fn register_int_slider(name: [*c]const u8, min: c_int, max: c_int, default_value: c_int) callconv(.C) c_int {
    const element: GuiState.GuiElement = .{
        .name = name,
        .data = .{ .int_slider = .{
            .value = default_value,
            .min = min,
            .max = max,
            .default = default_value,
        } },
    };

    const result = context.gui_state.registerElement(element);
    return result catch -1;
}

pub fn register_checkbox(name: [*c]const u8, default_value: c_int) callconv(.C) c_int {
    const element: GuiState.GuiElement = .{
        .name = name,
        .data = .{ .checkbox = .{
            .value = default_value != 0,
            .default = default_value != 0,
        } },
    };

    const result = context.gui_state.registerElement(element);
    return result catch -1;
}

pub fn register_colorpicker(name: [*c]const u8, default_color: [*c]f32) callconv(.C) c_int {
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

    const result = context.gui_state.registerElement(element);
    return result catch -1;
}

pub fn ui_element_is_updated(handle: c_int) callconv(.C) c_int {
    const id: GuiState.InternalIndexType = @intCast(handle);
    const elems = context.gui_state.getElements();
    return @intFromBool(elems[id].update);
}

pub fn get_ui_float_value(handle: c_int) callconv(.C) f32 {
    const id: GuiState.InternalIndexType = @intCast(handle);
    const elems = context.gui_state.getElements();
    const elem = &elems[id];

    const value: f32 = switch (elem.data) {
        .float_slider => |s| s.value,
        else => return 0.0, // TODO: some error code?
    };

    elem.update = false;
    return value;
}

pub fn get_ui_int_value(handle: c_int) callconv(.C) c_int {
    const id: GuiState.InternalIndexType = @intCast(handle);
    const elems = context.gui_state.getElements();
    const elem = &elems[id];

    const value: c_int = switch (elem.data) {
        .int_slider => |s| s.value,
        else => return 0.0, // TODO: some error code?
    };

    elem.update = false;
    return value;
}

pub fn get_ui_bool_value(handle: c_int) callconv(.C) c_int {
    const id: GuiState.InternalIndexType = @intCast(handle);
    const elems = context.gui_state.getElements();
    const elem = &elems[id];

    const value = switch (elem.data) {
        .checkbox => |b| b.value,
        else => return 0, // TODO: some error code?
    };

    elem.update = false;
    return @intFromBool(value);
}

pub fn get_ui_colorpicker_value(handle: c_int, color: [*c]f32) callconv(.C) void {
    const id: GuiState.InternalIndexType = @intCast(handle);
    const elems = context.gui_state.getElements();
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
pub fn set_chromagram_c3(pitch: f32) callconv(.C) void {
    context.analyzer.chroma_left.c3 = pitch;
    context.analyzer.chroma_right.c3 = pitch;
    context.analyzer.chroma_center.c3 = pitch;
}

pub fn set_chromagram_num_octaves(num: usize) callconv(.C) void {
    context.analyzer.chroma_left.num_octaves = num;
    context.analyzer.chroma_right.num_octaves = num;
    context.analyzer.chroma_center.num_octaves = num;
}

pub fn set_chromagram_num_partials(num: usize) callconv(.C) void {
    context.analyzer.chroma_left.num_partials = num;
    context.analyzer.chroma_right.num_partials = num;
    context.analyzer.chroma_center.num_partials = num;
}
