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

pub const GuiElement = struct {
    name: [*c]const u8,
    update: bool = false,
    data: union(enum) {
        float_slider: Slider(f32),
        checkbox: Checkbox,
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
    if (self.elements.items.len == max_elements)
        return error.MaxElementsRegistered;
    const id: InternalIndexType = @intCast(self.elements.items.len);
    try self.elements.append(element);
    return id;
}

pub fn getElements(self: *GuiState) []GuiElement {
    return self.elements.items;
}

pub fn update(self: *GuiState) void {
    for (self.getElements()) |*elem| {
        elem.update = switch (elem.data) {
            .float_slider => |*e| imgui.SliderFloat(elem.name, &e.value, e.min, e.max),
            .checkbox => |*e| imgui.Checkbox(elem.name, &e.value),
        };
    }
}

pub fn clear(self: *GuiState) void {
    self.elements.clearRetainingCapacity();
}
