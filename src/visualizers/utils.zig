const std = @import("std");

pub const AudioAnalysisData = struct {
    fft_data : []const f32,
};

pub const vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
};

pub const Vertex = struct { pos: vec3, col: vec3 };

pub fn full_quad() []Vertex {
    var arr : [6]Vertex = .{
        Vertex{
            .pos = .{ .x = -1.0, .y = -1.0, .z = 0.0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        },
        Vertex{
            .pos = .{ .x = -1.0, .y = 1.0, .z = 0.0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        },
        Vertex{
            .pos = .{ .x = 1.0, .y = -1.0, .z = 0.0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        },
        Vertex{
            .pos = .{ .x = -1.0, .y = 1.0, .z = 0.0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        },
        Vertex{
            .pos = .{ .x = 1.0, .y = 1.0, .z = 0.0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        },
        Vertex{
            .pos = .{ .x = 1.0, .y = -1.0, .z = 0.0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        },
    };
    return &arr;
} 

pub fn read_file(allocator: std.mem.Allocator, filePath: []const u8, offset: *u64) ![]const f32 {
    var file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();

    try file.seekTo(offset.*);

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var line_buf: [128]u8 = undefined;
    var amp_data = std.ArrayList(f32).init(allocator);
    defer amp_data.deinit();

    var prev_win_start: f32 = -1;

    // _ = try in_stream.readUntilDelimiterOrEof(&line_buf, '\n');
    while (try in_stream.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        var iter = std.mem.tokenizeAny(u8, line, ",\n\r");

        const win_start = try std.fmt.parseFloat(f32, iter.next().?);
        _ = try std.fmt.parseFloat(f32, iter.next().?);
        const amp = try std.fmt.parseFloat(f32, iter.next().?);

        offset.* += line.len + 1;
        if (prev_win_start == -1 or prev_win_start == win_start) {
            try amp_data.append(amp);
        } else {
            return amp_data.toOwnedSlice();
        }

        prev_win_start = win_start;
    }

    offset.* = 0;
    return amp_data.toOwnedSlice();
}
