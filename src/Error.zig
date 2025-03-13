const std = @import("std");
const imgui = @import("imgui");

const Error = @This();

message: ?[*:0]const u8 = null,

pub fn setMessage(
    self: *Error,
    comptime format: []const u8,
    args: anytype,
    allocator: std.mem.Allocator,
) !void {
    self.clear(allocator);

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    try buffer.writer().print(format, args);

    self.message = try allocator.dupeZ(u8, buffer.items);
}

pub fn show(self: *Error, allocator: std.mem.Allocator) void {
    const title = "Error";

    if (self.message) |m| {
        imgui.OpenPopup_Str(title);

        if (imgui.BeginPopup(title)) {
            imgui.SeparatorText(title);
            imgui.Text(m);

            if (imgui.Button("Ok")) {
                self.clear(allocator);
            }

            imgui.EndPopup();
        }
    }
}

pub fn clear(self: *Error, allocator: std.mem.Allocator) void {
    if (self.message) |m| {
        allocator.free(std.mem.span(m));
    }

    self.message = null;
}
