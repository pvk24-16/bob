const std = @import("std");
const Client = @import("Client.zig");
const rt_api = @import("rt_api.zig");
const imgui = @import("imgui");
const gui = @import("graphics/gui.zig");
const glfw = gui.glfw;
const gl = gui.gl;
const Context = @import("Context.zig");

const os_tag = @import("builtin").os.tag;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(gpa.allocator());
    defer args.deinit();

    const name = args.next() orelse unreachable;

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const path = args.next() orelse {
        try stderr.print("usage: {s} <path>\n", .{name});
        std.process.exit(1);
    };

    var context = Context.init(gpa.allocator());
    defer context.deinit();

    var client = Client.load(path) catch |e| {
        try stderr.print("error: failed to load '{s}': {s}\n", .{ path, @errorName(e) });
        std.process.exit(1);
    };
    defer client.unload();

    rt_api.fill(@ptrCast(&context), client.api.api);
    const info = &client.api.get_info()[0];
    try stdout.print("Name: {s}\n", .{info.name});
    try stdout.print("Description: {s}\n", .{info.description});

    client.create();

    mainGui(&context, &client);
}

/// Print error and code on GLFW errors.
fn errorCallback(err: c_int, msg: [*c]const u8) callconv(.C) void {
    std.log.err("Error code: {} message: {s}", .{ err, msg });
}

fn mainGui(context: *Context, client: *Client) void {
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
        "project_name",
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

    const gui_context = imgui.CreateContext();
    imgui.SetCurrentContext(gui_context);
    {
        const im_io = imgui.GetIO();
        im_io.IniFilename = null;
        im_io.ConfigFlags = imgui.ConfigFlags.with(
            im_io.ConfigFlags,
            .{
                .NavEnableKeyboard = true,
                .NavEnableGamepad = true,
                .DockingEnable = true,
                .ViewportsEnable = true,
            },
        );
    }

    imgui.StyleColorsDark();

    _ = gui.ImGui_ImplGlfw_InitForOpenGL(window, true);
    switch (gui.populate_dear_imgui_opengl_symbol_table(@ptrCast(&gui.get_proc_address))) {
        .ok => {},
        .init_error, .open_library => {
            std.log.err("Load OpenGL failed", .{});
            return;
        },
        .opengl_version_unsupported => {
            std.log.warn("Tried to run on unsupported OpenGL version", .{});
            return;
        },
    }
    _ = gui.ImGui_ImplOpenGL3_Init("#version 330 core");

    var running = true;

    while (running) {
        glfw.glfwPollEvents();

        gui.ImGui_ImplOpenGL3_NewFrame();
        gui.ImGui_ImplGlfw_NewFrame();
        imgui.NewFrame();

        const info = client.api.get_info()[0];
        _ = imgui.Begin(info.name);
        context.gui_state.update();
        client.api.update(client.ctx);
        imgui.End();

        imgui.EndFrame();

        imgui.Render();
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
        gui.ImGui_ImplOpenGL3_RenderDrawData(imgui.GetDrawData());

        const saved_context = glfw.glfwGetCurrentContext();
        imgui.UpdatePlatformWindows();
        imgui.RenderPlatformWindowsDefault();
        glfw.glfwMakeContextCurrent(saved_context);

        running = glfw.glfwWindowShouldClose(window) == glfw.GLFW_FALSE;
        glfw.glfwSwapBuffers(window);
    }
}
