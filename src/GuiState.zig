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
    name: [:0]const u8,
    update: bool = false,
    data: union(enum) {
        float_slider: Slider(f32),
        int_slider: Slider(c_int),
        checkbox: Checkbox,
        colorpicker: ColorPicker,
    },

    pub fn eql(self: *const GuiElement, other: *const GuiElement) bool {
        const activeTag = std.meta.activeTag;
        return activeTag(self.data) == activeTag(other.data) and std.mem.eql(u8, self.name, other.name);
    }
};

elements: std.ArrayList(GuiElement),

pub fn init(allocator: std.mem.Allocator) GuiState {
    return .{
        .elements = std.ArrayList(GuiElement).init(allocator),
    };
}

pub fn deinit(self: *GuiState) void {
    self.clear();
    self.elements.deinit();
}

pub fn registerElement(self: *GuiState, element: GuiElement) !InternalIndexType {
    if (self.elements.items.len == max_elements) {
        return error.MaxElementsRegistered;
    }

    const id: InternalIndexType = @intCast(self.elements.items.len);

    var copy = element;
    copy.name = try self.elements.allocator.dupeZ(u8, copy.name);
    try self.elements.append(copy);

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
    for (self.elements.items) |element| {
        self.elements.allocator.free(element.name);
    }
    self.elements.clearRetainingCapacity();
}

pub fn loadPreset(self: *GuiState, parent_dir: []const u8) !void {
    const allocator = self.elements.allocator;

    const path = try std.fs.path.join(allocator, &.{ parent_dir, "preset.json" });
    defer allocator.free(path);

    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    const data = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data);

    const parsed = try std.json.parseFromSlice([]GuiElement, allocator, data, .{});
    defer parsed.deinit();

    const default_elements = parsed.value;

    for (self.elements.items, default_elements) |element, default_element| {
        if (!element.eql(&default_element))
            return error.@"Incompatible GUI configuration";
    }

    for (self.elements.items, default_elements) |*element, default_element| {
        element.data = default_element.data;
        element.update = true;
    }
}

pub fn savePreset(self: *GuiState, parent_dir: []const u8) !void {
    const allocator = self.elements.allocator;

    const path = try std.fs.path.join(allocator, &.{ parent_dir, "preset.json" });
    defer allocator.free(path);

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    const options: std.json.StringifyOptions = .{ .whitespace = .indent_2 };
    try std.json.stringify(self.elements.items, options, file.writer());
}
