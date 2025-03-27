const std = @import("std");
const builtin = @import("builtin");
const Client = @import("Client.zig");
const bob_impl = @import("bob_impl.zig");
const imgui = @import("imgui");
const glfw = @import("graphics/glfw.zig");
const gl = @import("graphics/glad.zig");
const Context = @import("Context.zig");
const Flags = @import("flags.zig").Flags;

const audio_producer_enumerator = @import("producers/enumerator.zig");

const os_tag = @import("builtin").os.tag;

fn resizeCallback(window: ?*glfw.GLFWwindow, x: c_int, y: c_int) callconv(.C) void {
    const userdata = glfw.glfwGetWindowUserPointer(window);
    const context: *Context = @ptrCast(@alignCast(userdata));
    context.window_width = x;
    context.window_height = y;
    context.window_did_resize = true;
    gl.glViewport(0, 0, 800, 600);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // the path to visualizers is currently overridden with the path where buildExample puts them
    var client_list = try @import("ClientList.zig").init(allocator, "zig-out/bob");
    defer client_list.deinit();
    try client_list.readClientDir();

    _ = glfw.glfwSetErrorCallback(errorCallback);
    if (glfw.glfwInit() == glfw.GLFW_FALSE) {
        std.log.err("Failed to init GLFW", .{});
        return;
    }
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);
    if (os_tag == .macos) {
        glfw.glfwWindowHint(glfw.GLFW_OPENGL_FORWARD_COMPAT, glfw.GLFW_TRUE);
    }

    const window = glfw.glfwCreateWindow(
        800,
        600,
        "bob",
        null,
        null,
    ) orelse {
        std.log.err("Failed to create window", .{});
        return;
    };
    defer glfw.glfwDestroyWindow(window);

    glfw.glfwMakeContextCurrent(window);
    if (gl.gladLoadGLLoader(@ptrCast(&glfw.glfwGetProcAddress)) == 0) {
        std.log.err("Failed to load gl", .{});
        return;
    }

    gl.glViewport(0, 0, 800, 600);
    glfw.glfwSwapInterval(1);

    var ui = try @import("UI.zig").init(window);
    defer ui.deinit();

    var context = try Context.init(allocator);
    defer context.deinit(allocator);

    glfw.glfwSetWindowUserPointer(window, @ptrCast(&context));
    _ = glfw.glfwSetWindowSizeCallback(window, resizeCallback);

    var x: c_int = undefined;
    var y: c_int = undefined;
    glfw.glfwGetWindowSize(window, &x, &y);
    context.window_width = x;
    context.window_height = y;
    context.window_did_resize = true;

    var current_name: ?[*:0]const u8 = null;
    var pid_str = [_]u8{0} ** 32;

    var possible_audio_producers = audio_producer_enumerator.AudioProducerEntry.List.init(gpa.allocator());
    defer possible_audio_producers.deinit();

    audio_producer_enumerator.enumerate(&possible_audio_producers) catch |e| {
        try context.err.setMessage("Unable to list audio sources: {s}", .{@errorName(e)}, allocator);
    };

    var running = true;

    var audio_source_list_is_open = false;

    while (running) {
        glfw.glfwPollEvents();

        gl.glClearColor(0.2, 0.2, 0.2, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        context.processAudio();

        if (context.client) |client| {
            if (context.capturer != null) {
                client.update();
            }
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
                    std.log.info("clicked!", .{});
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

        if (ui.selectClient(&client_list, current_name)) |index| {
            if (context.client) |*client| {
                std.log.info("unloading visualizer", .{});
                client.destroy();
                client.unload();
                context.client = null;
                context.gui_state.clear();
                current_name = null;
            }

            current_name = client_list.list.items[index];
            const path = try client_list.getClientPath(index);
            defer client_list.freeClientPath(path);

            std.log.info("loading visualizer {s}", .{current_name.?});

            context.client = Client.load(path) catch |e| blk: {
                std.log.err("failed to load {s}: {s}", .{ path, @errorName(e) });
                try context.err.setMessage("Failed to load visualizer: {s}", .{@errorName(e)}, allocator);
                break :blk null;
            };
            if (context.client) |*client| {
                bob_impl.fill(@ptrCast(&context), client.api.api);
                client.create();
                context.flags = Flags.init(client.info.enabled);
                context.flags.log();
            }
        }

        if (context.client) |*client| {
            imgui.SeparatorText(client.info.name);
            if (imgui.Button("Unload")) {
                std.log.info("unloading visualizer", .{});
                client.destroy();
                client.unload();
                context.client = null;
                context.gui_state.clear();
                current_name = null;
                context.flags = Flags{};
            } else {
                context.gui_state.update();
                imgui.SeparatorText("Description");
                imgui.Text(client.info.description);
            }
        }

        context.err.show(allocator);

        ui.endFrame();

        running = glfw.glfwWindowShouldClose(window) == glfw.GLFW_FALSE;
        glfw.glfwSwapBuffers(window);

        if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            break;
        }
    }
}

/// Print error and code on GLFW errors.
fn errorCallback(err: c_int, msg: [*c]const u8) callconv(.C) void {
    std.log.err("Error code: {d} message: {s}", .{ err, msg });
}
