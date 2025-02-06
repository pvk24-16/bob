const std = @import("std");

fn linkToGLFW(add_to: *std.Build.Step.Compile, os_tag: std.Target.Os.Tag) void {
    switch (os_tag) {
        .windows => {
            add_to.addLibraryPath(.{ .cwd_relative = "deps/lib/windows" });
            add_to.addObjectFile(.{ .cwd_relative = "deps/lib/windows/glfw3.dll" });
            add_to.linkSystemLibrary("opengl32");
            add_to.linkSystemLibrary("glfw3");
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

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const os_tag = target.result.os.tag;


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
        .enable_lunasvg = false // if unspecified, the default is false
    });

    const imgui_dep = zig_imgui_dep.builder.dependency("imgui", .{
        .target = target,
        .optimize = optimize,
    });

    const lazy_xcode_dep = switch (target.result.os.tag.isDarwin()) {
        true => b.lazyDependency("xcode_frameworks", .{ .target = target, .optimize = optimize }),
        else => null,
    };

    const imgui_opengl = createImguiOpenGLStaticLib(b, target, optimize, imgui_dep, zig_imgui_dep);

    const imgui_glfw = createImguiGLFWStaticLib(
        b,
        target,
        optimize,
        imgui_dep,
        zig_imgui_dep,
        lazy_xcode_dep,
    );

    var exe = b.addExecutable(.{
        .name = "project",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("imgui", zig_imgui_dep.module("Zig-ImGui"));
    exe.linkLibrary(imgui_opengl);
    exe.linkLibrary(imgui_glfw);

    linkToGLFW(exe, os_tag);

    exe.linkLibC();

    exe.addIncludePath(.{ .cwd_relative = "deps/include/" });
    exe.addCSourceFiles(.{ .files = &.{"deps/src/glad.c"} });
    exe.addCSourceFiles(.{ .files = &.{"deps/src/stb_image_fix.c"} });

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    switch (os_tag) {
        .windows => b.installFile("deps/lib/windows/glfw3.dll", "bin/glfw3.dll"),
        else => {},
    }

    run_step.dependOn(&run_exe.step);

    b.installArtifact(exe);
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
    lazy_xcode_dep: ?*std.Build.Dependency,
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

    // For MacOS specifically, ensure we include system headers that zig
    // doesn't by default, which the xcode_frameworks project helpfully
    // provides.
    if (lazy_xcode_dep) |xcode_dep| {
        imgui_glfw.addSystemFrameworkPath(xcode_dep.path("Frameworks/"));
        imgui_glfw.addSystemIncludePath(xcode_dep.path("include/"));
        imgui_glfw.addLibraryPath(xcode_dep.path("lib/"));
    }

    linkToGLFW(imgui_glfw, target.result.os.tag);

    imgui_glfw.addCSourceFile(.{
        .file = imgui_dep.path("backends/imgui_impl_glfw.cpp"),
        // use the same compile flags that the ImGui base does
        .flags = zig_imgui_build_script.IMGUI_C_FLAGS,
    });

    return imgui_glfw;
}
