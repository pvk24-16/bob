const std = @import("std");
const builtin = @import("builtin");

fn linkToGLFW(b: *std.Build, add_to: *std.Build.Step.Compile, os_tag: std.Target.Os.Tag) void {
    add_to.addIncludePath(b.path("deps/include/"));
    add_to.addCSourceFiles(.{ .files = &.{"deps/src/glad.c"} });
    add_to.addCSourceFiles(.{ .files = &.{"deps/src/stb_image_fix.c"} });
    switch (os_tag) {
        .windows => {
            add_to.addLibraryPath(b.path("deps/lib/windows"));
            add_to.linkSystemLibrary("opengl32");
            add_to.linkSystemLibrary("glfw3");
            add_to.linkSystemLibrary("gdi32");
            add_to.linkSystemLibrary("user32");
        },
        .linux => {
            add_to.linkSystemLibrary("GL");
            add_to.linkSystemLibrary("glfw");
        },
        .macos => {
            add_to.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
            add_to.linkFramework("OpenGL");
            add_to.linkSystemLibrary("glfw");
        },
        else => @panic("Unsupported platform"),
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const os_tag = target.result.os.tag;

    const exe = b.addExecutable(.{
        .name = "bob",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    switch (os_tag) {
        .windows => {
            exe.addLibraryPath(b.path("deps/lib/windows"));
            exe.linkSystemLibrary("mmdevapi");
            exe.linkSystemLibrary("ole32");
            exe.linkSystemLibrary("dwmapi");
            exe.linkSystemLibrary("opengl32");
            exe.linkSystemLibrary("glfw3");
            exe.linkSystemLibrary("gdi32");
            exe.linkSystemLibrary("user32");
        },
        .linux => {
            exe.linkSystemLibrary("glfw");
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("pulse");
        },
        .macos => {
            exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
            exe.linkFramework("OpenGL");
            exe.linkSystemLibrary("glfw");
            exe.linkFramework("CoreAudio");
            exe.linkFramework("AudioUnit");
            exe.linkFramework("CoreFoundation");
        },
        else => @panic("Unsupported platform"),
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    linkToGLFW(b, exe, target.result.os.tag);
    exe.addIncludePath(b.path("api"));
    exe.linkLibC();

    const zig_imgui_dep = b.dependency("Zig-ImGui", .{
        .target = target,
        .optimize = optimize,
        // Include support for using freetype font rendering in addition to
        // ImGui's default truetype, necessary for emoji support
        //
        // Note: ImGui will prefer using freetype by default when this option
        // is enabled, but the option to use typetype manually at runtime is
        // still available
        .enable_freetype = true, // if unspecified, the default is false
        // Enable ImGui's extension to freetype which uses lunasvg:
        // https://github.com/sammycage/lunasvg
        // to support SVGinOT (SVG in Open Type) color emojis
        //
        // Notes from ImGui's documentation:
        // * Not all types of color fonts are supported by FreeType at the
        //   moment.
        // * Stateful Unicode features such as skin tone modifiers are not
        //   supported by the text renderer.
        .enable_lunasvg = false, // if unspecified, the default is false
    });

    const imgui_dep = zig_imgui_dep.builder.dependency("imgui", .{
        .target = target,
        .optimize = optimize,
    });

    const imgui_opengl = createImguiOpenGLStaticLib(b, target, optimize, imgui_dep, zig_imgui_dep);

    const imgui_glfw = createImguiGLFWStaticLib(
        b,
        target,
        optimize,
        imgui_dep,
        zig_imgui_dep,
    );

    exe.root_module.addImport("imgui", zig_imgui_dep.module("Zig-ImGui"));
    exe.linkLibrary(imgui_opengl);
    exe.linkLibrary(imgui_glfw);

    b.installArtifact(exe);

    // Examples
    try @import("examples/build_c_examples.zig").build_c_examples(b, target, optimize);
    try @import("examples/sphere/build.zig").buildLib(b, "sphere", "examples/sphere/", target, optimize);
    try @import("examples/fish_swarm/build.zig").buildLib(b, "fish_swarm", "examples/fish_swarm/", target, optimize);
    try @import("examples/logvol/build.zig").buildLib(b, "logvol", "examples/logvol/", target, optimize);
    try @import("examples/logvol/build.zig").buildLib(b, "debug", "examples/debug/", target, optimize);
    try @import("examples/logvol/build.zig").buildLib(b, "mood", "examples/mood/", target, optimize);
}

const zig_imgui_build_script = @import("Zig-ImGui");

// Taken from https://gitlab.com/joshua.software.dev/Zig-ImGui
fn createImguiOpenGLStaticLib(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imgui_dep: *std.Build.Dependency,
    ZigImGui_dep: *std.Build.Dependency,
) *std.Build.Step.Compile {
    // compile the desired backend into a separate static library
    const imgui_opengl = b.addStaticLibrary(.{
        .name = "imgui_opengl",
        .target = target,
        .optimize = optimize,
    });
    imgui_opengl.root_module.link_libcpp = true;
    // link in the necessary symbols from ImGui base
    imgui_opengl.linkLibrary(ZigImGui_dep.artifact("cimgui"));

    // use the same override DEFINES that the ImGui base does
    for (zig_imgui_build_script.IMGUI_C_DEFINES) |c_define| {
        imgui_opengl.root_module.addCMacro(c_define[0], c_define[1]);
    }

    // ensure the backend has access to the ImGui headers it expects
    imgui_opengl.addIncludePath(imgui_dep.path("."));
    imgui_opengl.addIncludePath(imgui_dep.path("backends/"));

    imgui_opengl.addCSourceFile(.{
        .file = imgui_dep.path("backends/imgui_impl_opengl3.cpp"),
        // use the same compile flags that the ImGui base does
        .flags = zig_imgui_build_script.IMGUI_C_FLAGS,
    });

    return imgui_opengl;
}

fn createImguiGLFWStaticLib(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imgui_dep: *std.Build.Dependency,
    ZigImGui_dep: *std.Build.Dependency,
) *std.Build.Step.Compile {
    // compile the desired backend into a separate static library
    const imgui_glfw = b.addStaticLibrary(.{
        .name = "imgui_glfw",
        .target = target,
        .optimize = optimize,
    });
    imgui_glfw.linkLibCpp();
    // link in the necessary symbols from ImGui base
    imgui_glfw.linkLibrary(ZigImGui_dep.artifact("cimgui"));

    // use the same override DEFINES that the ImGui base does
    for (zig_imgui_build_script.IMGUI_C_DEFINES) |c_define| {
        imgui_glfw.root_module.addCMacro(c_define[0], c_define[1]);
    }

    // ensure only a basic version of glfw is given to `imgui_impl_glfw.cpp` to
    // ensure it can be loaded with no extra headers.
    imgui_glfw.root_module.addCMacro("GLFW_INCLUDE_NONE", "1");

    // ensure the backend has access to the ImGui headers it expects
    imgui_glfw.addIncludePath(imgui_dep.path("."));
    imgui_glfw.addIncludePath(imgui_dep.path("backends/"));
    imgui_glfw.addIncludePath(b.path("deps/include/"));

    linkToGLFW(b, imgui_glfw, target.result.os.tag);

    imgui_glfw.addCSourceFile(.{
        .file = imgui_dep.path("backends/imgui_impl_glfw.cpp"),
        // use the same compile flags that the ImGui base does
        .flags = zig_imgui_build_script.IMGUI_C_FLAGS,
    });

    return imgui_glfw;
}

// Build a standalone Zig dll
pub fn buildLib(b: *std.Build, comptime path: []const u8) !void {
    if (true) @compileError("Unimplemented");

    const folder = path ++ "/";
    const file = switch (builtin.os.tag) {
        .windows => path ++ ".os",
        .linux => path ++ ".os",
        .macos => path ++ ".os",
    };

    const lib = b.addSystemCommand(&.{ "zig", "build" });

    // Set directory to that of lib
    lib.setCwd(b.path(folder));

    // Fail if lib cannot compile
    lib.addCheck(.{ .expect_term = .{ .Exited = 0 } });

    // Ensure lib is rebuilt every compilation
    lib.has_side_effects = true;

    // Install library in a separate folder
    b.installLibFile(folder ++ "zig-out/lib/" ++ file, file);
}
