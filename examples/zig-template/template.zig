const std = @import("std");
const bob = @cImport({
    @cInclude("bob.h");
});

const VisualizationInfo = bob.bob_visualization_info;
const BobAPI = bob.bob_api;

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
        .name = "Instert name here",
        .description = "Insert description here",
        .enabled = bob.BOB_AUDIO_TIME_DOMAIN_MONO | bob.BOB_AUDIO_FREQUENCY_DOMAIN_MONO,
    };
    return info;
}

/// Initialize visualization.
/// Audio analysis should be enabled here.
/// UI parameters should be registered here.
/// Return a pointer to user data, or NULL.
export fn create() ?*anyopaque {
    // Initialize user data
    // If you do not need user data remove this and return null
    var data = UserData{
        .my_rgb = .{ 255, 255, 255 },
    };
    return @ptrCast(&data);
}

/// Update called each frame.
/// Audio analysis data is passed in `data`.
export fn update(user_data: *anyopaque) void {
    // Access user data
    const data: *UserData = @ptrCast(user_data);
    const my_rgb = data.my_rgb;

    _ = my_rgb; // Avoid unused variable error
}

/// Perform potential visualization cleanup.
export fn destroy(user_data: *anyopaque) void {
    _ = user_data; // Avoid unused variable error
}
