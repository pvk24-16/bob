const std = @import("std");
const GuiState = @This();
const imgui = @import("imgui");

pub const InternalIndexType = u31;
const max_elements = std.math.maxInt(InternalIndexType);

pub fn Slider(comptime T: type) type {
    return struct {
        value: T,
        min: T,
        max: T,
        default: T,
    };
}

pub const Checkbox = struct {
    value: bool,
    default: bool,
};

pub const ColorPicker = struct {
    rgb: [3]f32,
};

pub const GuiElement = struct {
    name: [*c]const u8,
    update: bool = false,
    data: union(enum) {
        float_slider: Slider(f32),
        int_slider: Slider(c_int),
        checkbox: Checkbox,
        colorpicker: ColorPicker,
    },
};

elements: std.ArrayList(GuiElement),

pub fn init(allocator: std.mem.Allocator) GuiState {
    return .{
        .elements = std.ArrayList(GuiElement).init(allocator),
    };
}

pub fn deinit(self: *GuiState) void {
    self.elements.deinit();
}

pub fn registerElement(self: *GuiState, element: GuiElement) !InternalIndexType {
    if (self.elements.items.len == max_elements) {
        return error.MaxElementsRegistered;
    }

    const id: InternalIndexType = @intCast(self.elements.items.len);

    try self.elements.append(element);

    return id;
}

pub fn getElements(self: *GuiState) []GuiElement {
    return self.elements.items;
}

pub fn update(self: *GuiState) void {

    // Make the color picker less meaty
    const color_edit_flags: imgui.ColorEditFlags = .{
        .NoSidePreview = true,
        .NoAlpha = true,
        .NoPicker = true,
        .NoOptions = true,
        .NoSmallPreview = true,
    };

    for (self.getElements()) |*elem| {
        elem.update = switch (elem.data) {
            .float_slider => |*e| imgui.SliderFloat(elem.name, &e.value, e.min, e.max),
            .int_slider => |*e| imgui.SliderInt(elem.name, &e.value, e.min, e.max),
            .checkbox => |*e| imgui.Checkbox(elem.name, &e.value),
            .colorpicker => |*e| blk: {
                imgui.PushItemWidth(200);
                const update_ = imgui.ColorPicker3Ext(elem.name, &e.rgb, color_edit_flags);
                imgui.PopItemWidth();
                break :blk update_;
            },
        };
    }
}

pub fn clear(self: *GuiState) void {
    self.elements.clearRetainingCapacity();
}
