const std = @import("std");

pub fn buildExample(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    source: []const []const u8,
) !void {
    const lib = b.addSharedLibrary(.{
        .name = name,
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();

    const opengl = switch (target.result.os.tag) {
        .linux => "GL",
        .windows => "opengl32",
        .macos => "OpenGL",
        else => std.debug.panic("unsupported platform", .{}),
    };
    lib.linkSystemLibrary(opengl);

    for (source) |file| {
        lib.addCSourceFile(.{ .file = b.path(file) });
    }
    lib.addIncludePath(b.path("api"));

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();

    const path = try std.fs.path.join(gpa.allocator(), &.{ "bob", name });
    // defer gpa.allocator().free(path);

    const install = b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = path } } });
    b.default_step.dependOn(&install.step);
}
