const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const os_tag = target.result.os.tag;

    const exe = b.addExecutable(.{
        .name = "project",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    switch (os_tag) {
        .windows => {
            exe.addLibraryPath(.{ .cwd_relative = "deps/lib/windows" });
            exe.addObjectFile(.{ .cwd_relative = "deps/lib/windows/glfw3.dll" });
            exe.linkSystemLibrary("opengl32");
            exe.linkSystemLibrary("glfw3");
        },
        .linux => {
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("glfw");
        },
        .macos => {
            exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
            exe.linkFramework("OpenGL");
            exe.linkSystemLibrary("glfw");
        },
        else => @panic("Unsupported platform"),
    }

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
