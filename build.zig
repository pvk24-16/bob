const std = @import("std");
const os = @import("builtin").os;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "project",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    switch (os.tag) {
        .windows => {
            exe.addLibraryPath(.{ .cwd_relative = "deps/lib/windows" });
            exe.addObjectFile(.{ .cwd_relative = "deps/lib/windows/glfw3.dll" });
            exe.linkSystemLibrary("opengl32");
            exe.linkSystemLibrary("glfw3");
        },
        else => @compileError("Unsupported platform " ++ @tagName(os.tag)),
    }

    exe.addIncludePath(.{ .cwd_relative = "deps/include/" });
    exe.addCSourceFiles(.{ .files = &.{"deps/src/glad.c"} });

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    switch (os.tag) {
        .windows => run_exe.addPathDir("deps/lib/windows"),
        else => {},
    }

    run_step.dependOn(&run_exe.step);

    b.installArtifact(exe);
}
