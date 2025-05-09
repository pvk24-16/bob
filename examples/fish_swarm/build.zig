const std = @import("std");

pub fn buildLib(
    b: *std.Build,
    comptime name: []const u8,
    comptime path: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const source_dir = try std.fs.path.join(gpa.allocator(), &.{ "examples", name });
    const dest_dir = try std.fs.path.join(gpa.allocator(), &.{ "bob", name });

    const lib = b.addSharedLibrary(.{
        .name = name,
        .target = target,
        .root_source_file = b.path(path ++ "fish.zig"),
        .optimize = optimize,
    });

    // OpenGL dependency
    const render = b.dependency(
        "render",
        .{ .target = target, .optimize = optimize },
    ).module("render");
    lib.root_module.addImport("render", render);

    lib.addIncludePath(b.path("api"));

    const extra_files = [_][]const u8{ "objects/fish_low_poly.png", "objects/fish_low_poly.obj" };

    for (extra_files) |file| {
        const source_path = try std.fs.path.join(gpa.allocator(), &.{ source_dir, file });
        const dest_path = try std.fs.path.join(gpa.allocator(), &.{ dest_dir, file });
        const install = b.addInstallFile(b.path(source_path), dest_path);
        b.default_step.dependOn(&install.step);
    }

    const install = b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = "bob/" ++ name } } });
    b.default_step.dependOn(&install.step);
}
