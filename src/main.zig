const std = @import("std");
const builtin = @import("builtin");
const Visualizer = @import("Visualizer.zig");
const bob_impl = @import("bob_impl.zig");
const imgui = @import("imgui");
const glfw = @import("graphics/glfw.zig");
const gl = @import("graphics/glad.zig");
const Context = @import("Context.zig");
const Flags = @import("flags.zig").Flags;

const audio_producer_enumerator = @import("producers/enumerator.zig");
const Window = @import("graphics/window.zig").Window(8);

const os_tag = @import("builtin").os.tag;

fn resizeCallback(x: i32, y: i32, userdata: ?*anyopaque) void {
    const context: *Context = @ptrCast(@alignCast(userdata.?)); // This is ok
    context.window_width = @intCast(x);
    context.window_height = @intCast(y);
    context.window_did_resize = true;
}

/// Userdata is window
fn keyboardCallback(key: i32, _: i32, action: i32, _: i32, userdata: ?*anyopaque) void {
    var window: *Window = @ptrCast(@alignCast(userdata.?)); // This is ok

    switch (key) {
        glfw.GLFW_KEY_F => {
            if (action == glfw.GLFW_PRESS) {
                // For now we reserve key F for toggling borderless fullscreen
                // TODO: list monitors in GUI somehow, we use the primary monitor for now
                window.toggleBorderless();
            }
        },
        else => {},
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // the path to visualizers is currently overridden with the path where buildExample puts them
    var visualizer_list = try @import("VisualizerList.zig").init(allocator, "zig-out/bob");
    defer visualizer_list.deinit();
    try visualizer_list.readVisualizerDir();

    var context = try Context.init(allocator);
    defer context.deinit(allocator);

    var window = try Window.init(800, 600, "BoB");
    window.setUserPointer();
    try window.pushCallback(&resizeCallback, @ptrCast(@alignCast(&context)), .resize);
    try window.pushCallback(&keyboardCallback, @ptrCast(@alignCast(&window)), .keyboard);
    defer window.deinit();

    context.window_width = window.width;
    context.window_height = window.height;
    context.window_did_resize = true;

    var ui = try @import("UI.zig").init(window.handle);
    defer ui.deinit();

    var current_name: ?[*:0]const u8 = null;
    var current_index: ?usize = null;
    var pid_str = [_]u8{0} ** 32;

    var possible_audio_producers = audio_producer_enumerator.AudioProducerEntry.List.init(gpa.allocator());
    defer possible_audio_producers.deinit();

    audio_producer_enumerator.enumerate(&possible_audio_producers) catch |e| {
        try context.err.setMessage("Unable to list audio sources: {s}", .{@errorName(e)}, allocator);
    };

    var running = true;

    var audio_source_list_is_open = false;

    var bob_dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const bob_dir = try std.process.getCwd(&bob_dir_buf);

    while (running) {
        window.update();
        defer window.swap();
        defer running = window.running();
        defer {
            if (context.window_did_resize) {
                context.window_did_resize = false;
            }
        }

        // === Input ===
        if (glfw.glfwGetKey(window.handle, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            break;
        }

        // === Update sate ===
        context.processAudio();

        // === Draw begins here ===
        if (context.visualizer != null and context.capturer != null) {
            context.visualizer.?.update();
        } else {
            // Much clearer
            gl.glClearColor(0.2, 0.2, 0.2, 1.0);
            gl.glClear(gl.GL_COLOR_BUFFER_BIT);
        }

        ui.beginFrame();

        // Make the default window a bit bigger. As it is too small with
        // the new font otherwise.
        imgui.SetWindowSize_Vec2Ext(imgui.Vec2{ .x = 600, .y = 300 }, imgui.CondFlags{ .Once = true });

        if (context.capturer) |_| {
            if (imgui.Button("Disconnect")) {
                context.disconnect(allocator) catch |e| {
                    std.log.err("unable to disconnect: {s}", .{@errorName(e)});
                };
            }
        } else {
            _ = imgui.InputText("Application PID", &pid_str, @sizeOf(@TypeOf(pid_str)));
            imgui.SameLine();
            if (imgui.Button("Connect")) {
                const pid_str_c: [*c]const u8 = &pid_str;
                context.connect(std.mem.span(pid_str_c), allocator) catch |e| {
                    std.log.err("Failed to connect to application with PID {s}: {s}", .{ pid_str_c, @errorName(e) });
                    try context.err.setMessage("Unable to connect: {s}", .{@errorName(e)}, allocator);
                };
            }

            if (imgui.BeginCombo("Window Select", "Click for list")) {
                if (!audio_source_list_is_open) {
                    possible_audio_producers.clearRetainingCapacity();
                    audio_producer_enumerator.enumerate(&possible_audio_producers) catch |e| {
                        try context.err.setMessage("Unable to list audio sources: {s}", .{@errorName(e)}, allocator);
                    };
                }
                audio_source_list_is_open = true;
                for (possible_audio_producers.items) |producer| {
                    if (imgui.Selectable_Bool(&producer.name)) {
                        const pid_len = std.mem.indexOfScalar(u8, &producer.process_id, 0) orelse producer.process_id.len;
                        std.log.info("PID: {s}\n", .{producer.process_id[0..pid_len]});
                        context.connect(producer.process_id[0..pid_len], gpa.allocator()) catch |e| {
                            std.log.err("Failed to connect to application with PID {s}: {s}", .{ producer.process_id[0..pid_len], @errorName(e) });
                            try context.err.setMessage("Unable to connect: {s}", .{@errorName(e)}, allocator);
                        };
                    }
                }
                imgui.EndCombo();
            } else audio_source_list_is_open = false;
        }

        if (ui.selectVisualizer(&visualizer_list, current_name)) |index| {
            if (context.visualizer) |*visualizer| {
                std.log.info("unloading visualizer", .{});
                visualizer.destroy();
                visualizer.unload();
                context.visualizer = null;
                context.gui_state.clear();
                current_name = null;
                std.process.changeCurDir(bob_dir) catch {};
            }

            current_name = visualizer_list.list.items[index];
            const path = try visualizer_list.getVisualizerPath(index);
            defer visualizer_list.freePath(path);

            std.log.info("loading visualizer {s}", .{current_name.?});

            context.visualizer = Visualizer.load(path) catch |e| blk: {
                std.log.err("failed to load {s}: {s}", .{ path, @errorName(e) });
                try context.err.setMessage("Failed to load visualizer: {s}", .{@errorName(e)}, allocator);
                break :blk null;
            };

            if (context.visualizer) |*visualizer| {
                const visualizer_dir = std.fs.path.dirname(path) orelse unreachable;
                std.process.changeCurDir(visualizer_dir) catch {};

                bob_impl.fill(@ptrCast(&context), visualizer.api.api);
                if (visualizer.create()) |err| {
                    try context.err.setMessage("Failed to initialize visualizer: {s}", .{err}, allocator);
                    std.log.info("unloading visualizer", .{});
                    visualizer.destroy();
                    visualizer.unload();
                    context.visualizer = null;
                    context.gui_state.clear();
                    current_name = null;
                    context.flags = Flags{};
                    std.process.changeCurDir(bob_dir) catch {};
                } else {
                    context.flags = Flags.init(visualizer.info.enabled);
                    context.flags.log();
                    current_index = index;
                }
            }
        }

        if (context.visualizer) |*visualizer| {
            imgui.SeparatorText(visualizer.info.name);
            if (imgui.Button("Unload")) {
                std.log.info("unloading visualizer", .{});
                visualizer.destroy();
                visualizer.unload();
                context.visualizer = null;
                context.gui_state.clear();
                current_name = null;
                context.flags = Flags{};
                std.process.changeCurDir(bob_dir) catch {};
            } else {
                const path = visualizer_list.getVisualizerParentPath(current_index.?) catch |e| blk: {
                    std.log.err("failed to create parent path for visualizer: {s}", .{@errorName(e)});
                    break :blk null;
                };
                defer if (path) |path_| visualizer_list.freePath(path_);

                var load_preset = false;
                var save_preset = false;
                if (path) |_| {
                    imgui.SameLine();
                    load_preset = imgui.Button("Load preset");
                    imgui.SameLine();
                    save_preset = imgui.Button("Save preset");
                }

                context.gui_state.update();
                imgui.SeparatorText("Description");
                imgui.Text(visualizer.info.description);

                if (path) |_| {
                    if (load_preset) {
                        context.gui_state.loadPreset() catch |e| {
                            try context.err.setMessage("Failed to load preset: {s}", .{@errorName(e)}, allocator);
                        };
                    }
                    if (save_preset) {
                        context.gui_state.savePreset() catch |e| {
                            try context.err.setMessage("Failed to save preset: {s}", .{@errorName(e)}, allocator);
                        };
                    }
                }
            }
        }

        context.err.show(allocator);

        ui.endFrame();
    }
}
