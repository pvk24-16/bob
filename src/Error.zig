const std = @import("std");
const imgui = @import("imgui");

message: ?[*:0]const u8,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) @This() {
    return .{
        .message = null,
        .allocator = allocator,
    };
}

pub fn deinit(self: *@This()) void {
    self.clear();
}

fn clear(self: *@This()) void {
    if (self.message) |m| {
        self.allocator.free(std.mem.span(m));
    }
    self.message = null;
}

pub fn setMessage(
    self: *@This(),
    comptime format: []const u8,
    args: anytype,
) !void {
    self.clear();
    var buffer = std.ArrayList(u8).init(self.allocator);
    defer buffer.deinit();
    try buffer.writer().print(format, args);
    self.message = try self.allocator.dupeZ(u8, buffer.items);
}

pub fn show(self: *@This()) void {
    const title = "Error";
    if (self.message) |m| {
        imgui.OpenPopup_Str(title);
        if (imgui.BeginPopup(title)) {
            imgui.SeparatorText(title);
            imgui.Text(m);
            if (imgui.Button("Ok"))
                self.clear();
            imgui.EndPopup();
        }
    }
}
