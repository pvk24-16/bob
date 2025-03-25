const std = @import("std");

fn linkToGLFW(add_to: *std.Build.Step.Compile, os_tag: std.Target.Os.Tag) void {
    add_to.addIncludePath(.{ .cwd_relative = "deps/include/" });
    add_to.addCSourceFiles(.{ .files = &.{"deps/src/glad.c"} });
    add_to.addCSourceFiles(.{ .files = &.{"deps/src/stb_image_fix.c"} });
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

pub fn buildExample(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    root_source_file: []const u8,
) !void {
    const os_tag = target.result.os.tag;

    const lib = b.addSharedLibrary(.{
        .name = name,
        .target = target,
        .root_source_file = b.path(root_source_file),
        .optimize = optimize,
    });

    lib.linkLibC();

    switch (target.result.os.tag) {
        .linux => {
            lib.linkSystemLibrary("GL");
        },
        .windows => {
            lib.linkSystemLibrary("opengl32");
        },
        .macos => {
            lib.linkFramework("OpenGL");
        },
        else => std.debug.panic("unsupported platform", .{}),
    }

    lib.addIncludePath(b.path("api"));
    lib.addIncludePath(b.path("deps/include"));
    linkToGLFW(lib, os_tag);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();

    const path = try std.fs.path.join(gpa.allocator(), &.{ "bob", name });
    // defer gpa.allocator().free(path);

    const install = b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = path } } });
    b.default_step.dependOn(&install.step);
}
