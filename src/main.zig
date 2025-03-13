const std = @import("std");
const builtin = @import("builtin");
const Client = @import("Client.zig");
const bob_impl = @import("bob_impl.zig");
const imgui = @import("imgui");
const glfw = @import("graphics/glfw.zig");
const gl = @import("graphics/glad.zig");
const Context = @import("Context.zig");

const os_tag = @import("builtin").os.tag;

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

    var context = Context.init(allocator);
    defer context.deinit(allocator);

    var current_name: ?[*:0]const u8 = null;
    var pid_str = [_]u8{0} ** 32;

    var running = true;

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
                break :blk null;
            };
            if (context.client) |*client| {
                bob_impl.fill(@ptrCast(&context), client.api.api);
                client.create();
                context.flags.set(client.info.enabled);
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
