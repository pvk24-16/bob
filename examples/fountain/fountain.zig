const std = @import("std");
const builtin = @import("builtin");
const bob = @cImport({
    @cInclude("bob.h");
});

const net = std.net;
const print = std.debug.print;

const VisualizationInfo = bob.bob_visualization_info;
const BobAPI = bob.bob_api;

var s_target_chroma: [12]f32 = undefined;
var s_chroma: [12]f32 = undefined;

/// Struct for storing user data.
/// Define "global" values needed by the visualizer.
/// Create an instance of `UserData` in `create()`, and use it in `update()` and `destroy()`.
/// If you do not need any user data you can remove this struct.
const UserData = extern struct {
    my_rgb: [3]u8, // Example: storing an rgb value
};

/// Export api variable, it will be populated with information by the API
export var api: BobAPI = undefined;

/// Include information about your visualization here
export fn get_info() *VisualizationInfo {
    const info = std.heap.page_allocator.create(VisualizationInfo) catch unreachable;
    info.* = VisualizationInfo{
        .name = "Fountain",
        .description =
        \\Using socket to visualise music in a 3d music fountain created using godot and blender.
        \\Does not work on macOS due to signing issues.
        \\Please use the unload button to close the window.
        ,
        .enabled = bob.BOB_AUDIO_CHROMAGRAM_MONO,
    };
    return info;
}

/// Initialize visualization.
/// Audio analysis should be enabled here.
/// UI parameters should be registered here.
/// Return a pointer to user data, or NULL.
export fn create() ?*anyopaque {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("leak");
    const allocator = gpa.allocator();

    var argv = [_][]const u8{ "", "" };

    switch (builtin.target.os.tag) {
        .windows => argv = [_][]const u8{ "python", "..\\..\\..\\examples\\fountain\\startFountain.py" },
        .linux => argv = [_][]const u8{ "python3", "../../../examples/fountain/startFountain.py" },
        .macos => argv = [_][]const u8{ "python", "../../../examples/fountain/startFountain.py" },
        else => @compileError("Unsupported platform"),
    }

    var child = std.process.Child.init(&argv, allocator);

    child.spawn() catch |err| {
        print("error lauching visualization:{}", .{err});
        return null;
    };

    // Initialize user data
    // If you do not need user data remove this and return null
    return null;
}

/// Update called each frame.
/// Audio analysis data is passed in `data`.
export fn update(user_data: *anyopaque) void {
    const snap = 0.001;
    const threshold = 0.8;
    api.get_chromagram.?(api.context, &s_target_chroma[0], bob.BOB_MONO_CHANNEL);

    for (0..12) |i| {
        const v: f32 = s_target_chroma[i];
        var target: f32 = 0;
        if (v > threshold) {
            target = std.math.pow(f32, v, 6.0);
        } else {
            target = 0.02;
        }
        const diff: f32 = target - s_chroma[i];
        const speed: f32 = 0.05;
        if (-snap < diff and diff < snap) {
            s_chroma[i] = target;
        } else {
            s_chroma[i] = s_chroma[i] + speed * diff;
        }
    }

    const peer = net.Address.parseIp4("127.0.0.1", 8764) catch |err| {
        print("error creating socket:{}", .{err});
        return;
    };
    // Connect to peer
    const stream = net.tcpConnectToAddress(peer) catch |err| {
        print("error connecting to socket:{}\n", .{err});
        return;
    };

    defer stream.close();
    //print("Connecting to {}\n", .{peer});

    // Sending data to peer
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();
    const string = std.fmt.allocPrint(
        alloc,
        "{d:.3}, {d:.3}, {d:.3}, {d:.3}, {d:.3}, {d:.3}, {d:.3}, {d:.3}, {d:.3}, {d:.3}, {d:.3}, {d:.3}",
        .{ s_chroma[0], s_chroma[1], s_chroma[2], s_chroma[3], s_chroma[4], s_chroma[5], s_chroma[6], s_chroma[7], s_chroma[8], s_chroma[9], s_chroma[10], s_chroma[11] },
    ) catch |err| {
        print("error creating string{}", .{err});
        return;
    };
    defer alloc.free(string);
    var writer = stream.writer();
    _ = writer.write(string) catch |err| {
        print("error{} writing to socket", .{err});
        return;
    };

    //print("Sending '{s}' to peer, total written: {d} bytes\n", .{ string, size });
    _ = user_data;
}

/// Perform potential visualization cleanup.
export fn destroy(user_data: *anyopaque) void {
    const peer = net.Address.parseIp4("127.0.0.1", 8764) catch |err| {
        print("error creating socket:{}", .{err});
        return;
    };
    // Connect to peer
    const stream = net.tcpConnectToAddress(peer) catch |err| {
        print("error connecting to socket:{}", .{err});
        return;
    };

    defer stream.close();

    const string = "close";

    var writer = stream.writer();
    _ = writer.write(string) catch |err| {
        print("error{} writing to socket", .{err});
        return;
    };

    _ = user_data; // Avoid unused variable error
}
