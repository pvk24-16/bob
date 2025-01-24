const std = @import("std");
const g = @import("graphics/graphics.zig");
const v = @import("visualizers/bar_visualizer.zig");
const vutils = @import("visualizers/utils.zig");
const Window = g.window.Window;
const BarVisualizer = v.BarVisualizer;

pub fn main() !void {
    var running = true;
    var window = try Window(8).init();
    defer window.deinit();
    window.setUserPointer();

    var visualizer = try BarVisualizer().init();
    defer visualizer.deinit();

    const fft_path = "test_data/fft_1mil_normalized.csv";

    const allocator = std.heap.page_allocator;
    var offset: usize = 0;
    var fft_data = try vutils.read_file(allocator, fft_path, &offset);
    defer allocator.free(fft_data);

    std.debug.print("{}\n", .{fft_data.len});

    var audio_data = vutils.AudioAnalysisData{
        .fft_data = fft_data,
    };

    while (running) {
        window.update();

        try visualizer.draw(&audio_data);

        fft_data = try vutils.read_file(allocator, fft_path, &offset);
        audio_data.fft_data = fft_data;

        running = window.running();
    }
}
