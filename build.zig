const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const os_tag = target.result.os.tag;

    const exe = b.addExecutable(.{
        .name = "project-name",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    switch (os_tag) {
        .windows => {
            exe.addLibraryPath(.{ .cwd_relative = "deps/lib/windows" });
            exe.addObjectFile(.{ .cwd_relative = "deps/lib/windows/glfw3.dll" });
            exe.linkSystemLibrary("mmdevapi");
            exe.linkSystemLibrary("ole32");
            exe.linkSystemLibrary("opengl32");
            exe.linkSystemLibrary("glfw3");
        },
        .linux => {
            exe.linkSystemLibrary("glfw");
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("pulse");
        },
        else => @panic("Unsupported platform"),
    }

    exe.addIncludePath(.{ .cwd_relative = "deps/include/" });
    exe.addCSourceFiles(.{ .files = &.{"deps/src/glad.c"} });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    switch (os_tag) {
        .windows => {
            b.installFile("deps/lib/windows/glfw3.dll", "bin/glfw3.dll");
        },
        else => {},
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
}
