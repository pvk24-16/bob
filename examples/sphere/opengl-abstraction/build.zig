const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const os_tag = target.result.os.tag;

    _ = b.addModule(
        "opengl-abstraction",
        .{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        },
    );

    const lib = b.addExecutable(.{
        .name = "opengl-abstraction",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();
    switch (os_tag) {
        .windows => {
            lib.addLibraryPath(.{ .cwd_relative = "deps/lib/windows" });
            lib.linkSystemLibrary("opengl32");
            lib.linkSystemLibrary("glfw3");
            lib.linkSystemLibrary("gdi32");
            lib.linkSystemLibrary("user32");
        },
        .linux => {
            lib.linkSystemLibrary("GL");
            lib.linkSystemLibrary("glfw");
        },
        .macos => {
            lib.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
            lib.linkFramework("OpenGL");
            lib.linkSystemLibrary("glfw");
        },
        else => @panic("Unsupported platform"),
    }

    lib.addIncludePath(.{ .cwd_relative = "deps/include/" });
    lib.addCSourceFiles(.{ .files = &.{"deps/src/glad.c"} });
    lib.addCSourceFiles(.{ .files = &.{"deps/src/stb_image_fix.c"} });

    const run_exe = b.addRunArtifact(lib);
    const run_step = b.step("run", "Run the application");
    switch (os_tag) {
        .windows => b.installFile("deps/lib/windows/glfw3.dll", "bin/glfw3.dll"),
        else => {},
    }

    run_step.dependOn(&run_exe.step);

    b.installArtifact(lib);
}
