const std = @import("std");

pub fn buildLib(
    b: *std.Build,
    comptime name: []const u8,
    comptime path: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {
    const lib = b.addSharedLibrary(.{
        .name = name,
        .target = target,
        .root_source_file = b.path(path ++ "sphere.zig"),
        .optimize = optimize,
    });

    // OpenGL dependency
    const render = b.dependency(
        "render",
        .{ .target = target, .optimize = optimize },
    ).module("render");
    lib.root_module.addImport("render", render);

    lib.addIncludePath(b.path("api"));

    const install = b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = "bob/" ++ name } } });
    b.default_step.dependOn(&install.step);
}
