const std = @import("std");
const builtin = @import("builtin");

pub fn buildLib(
    b: *std.Build,
    comptime name: []const u8,
    comptime path: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {
    const lib = b.addSharedLibrary(.{
        .name = name,
        .root_source_file = b.path(path ++ "spectrogram.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
        .link_libc = true,
    });

    // OpenGL dependency
    const render = b.dependency(
        "render",
        .{ .target = target, .optimize = optimize },
    ).module("render");
    lib.root_module.addImport("render", render);

    switch (builtin.target.os.tag) {
        .windows => lib.linkSystemLibrary("opengl32"),
        .linux => lib.linkSystemLibrary("GL"),
        .macos => lib.linkFramework("OpenGL"),
        else => @compileError("Unsupported platform"),
    }

    lib.addIncludePath(b.path("deps/include"));
    lib.addIncludePath(b.path("api"));
    //lib.addCSourceFile(.{ .file = b.path("deps/src/glad.c") });

    const install = b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = "bob/" ++ name } } });
    b.default_step.dependOn(&install.step);
}
