//!
//! Utilities for dealing with ImGui
//!

const std = @import("std");
const imgui = @import("imgui");
const glfw = @import("graphics/glfw.zig");
const VisualizerList = @import("VisualizerList.zig");

const comicJensFreeProRegular = @embedFile("assets/ComicJensFreePro-Regular.ttf");

const ui_window_title = "bob";

pub fn init(window: *glfw.GLFWwindow) !@This() {
    const context = imgui.CreateContext();
    imgui.SetCurrentContext(context);

    const io = imgui.GetIO();
    io.IniFilename = null;
    io.ConfigFlags = imgui.ConfigFlags.with(io.ConfigFlags, .{
        .NavEnableKeyboard = true,
        .NavEnableGamepad = true,
        .DockingEnable = true,
        // For bringing GUI outside of main window
        .ViewportsEnable = true,
    });

    // Set font
    if (io.Fonts) |fonts| {
        const glyph_range = imgui.FontGlyphRangesBuilder.init_ImFontGlyphRangesBuilder();
        imgui.FontGlyphRangesBuilder.AddRanges(glyph_range, imgui.FontAtlas.GetGlyphRangesDefault(fonts));

        var built_range = std.mem.zeroes(imgui.Vector(imgui.Wchar));
        imgui.FontGlyphRangesBuilder.BuildRanges(glyph_range, &built_range);

        _ = imgui.FontAtlas.AddFontFromMemoryTTFExt(fonts, @constCast(@ptrCast(comicJensFreeProRegular.ptr)), comicJensFreeProRegular.len, 20.0, null, built_range.items()[0 .. built_range.Size - 1 :0]);
        _ = imgui.raw.ImFontAtlas_Build(fonts); // TODO: assert?
    }

    // Light theme
    imgui.StyleColorsLight();

    _ = ImGui_ImplGlfw_InitForOpenGL(window, true);
    switch (populate_dear_imgui_opengl_symbol_table(@ptrCast(&get_proc_address))) {
        .ok => {},
        .init_error, .open_library => {
            std.log.err("Load OpenGL failed", .{});
            return error.FailedToLoadOpenGL;
        },
        .opengl_version_unsupported => {
            std.log.warn("Tried to run on unsupported OpenGL version", .{});
            return error.UnsupportedOpenGLVersion;
        },
    }
    _ = ImGui_ImplOpenGL3_Init("#version 330 core");

    return .{};
}

pub fn deinit(self: *@This()) void {
    _ = self;
}

pub fn beginFrame(self: *const @This()) void {
    _ = self;

    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplGlfw_NewFrame();
    imgui.NewFrame();
    _ = imgui.Begin(ui_window_title);
}

/// Returns an index in to the list if the user selected a visualizer, and null otherwise
pub fn selectVisualizer(self: *const @This(), visualizers: *const VisualizerList, current: ?[*:0]const u8) ?usize {
    _ = self;

    if (imgui.BeginCombo("Select visualizer", current)) {
        defer imgui.EndCombo();
        for (visualizers.list.items, 0..) |name, i| {
            const selected = if (current) |c| std.mem.orderZ(u8, name, c) == .eq else false;
            _ = selected;
            if (imgui.Selectable_Bool(name))
                return i;
        }
    }
    return null;
}

pub fn endFrame(self: *const @This()) void {
    _ = self;

    imgui.End();
    imgui.EndFrame();
    imgui.Render();
    ImGui_ImplOpenGL3_RenderDrawData(imgui.GetDrawData());

    const saved_context = glfw.glfwGetCurrentContext();
    imgui.UpdatePlatformWindows();
    imgui.RenderPlatformWindowsDefault();
    glfw.glfwMakeContextCurrent(saved_context);
}

pub extern fn ImGui_ImplGlfw_InitForOpenGL(window: *glfw.GLFWwindow, install_callbacks: bool) bool;
pub extern fn ImGui_ImplGlfw_Shutdown() void;
pub extern fn ImGui_ImplGlfw_NewFrame() void;

const LoaderInitErrors = enum(i32) {
    ok = 0,
    init_error = -1,
    open_library = -2,
    opengl_version_unsupported = -3,
};

pub const get_proc_address = glfw.glfwGetProcAddress;

extern fn imgl3wInit2(get_proc_address_pfn: *const fn ([*:0]const u8) callconv(.C) ?*anyopaque) LoaderInitErrors;
pub const populate_dear_imgui_opengl_symbol_table = imgl3wInit2;

pub extern fn ImGui_ImplOpenGL3_Init(glsl_version: ?[*:0]const u8) bool;
pub extern fn ImGui_ImplOpenGL3_Shutdown() void;
pub extern fn ImGui_ImplOpenGL3_NewFrame() void;
pub extern fn ImGui_ImplOpenGL3_RenderDrawData(draw_data: *const imgui.DrawData) void;
