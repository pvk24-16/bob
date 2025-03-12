const std = @import("std");

pub fn buildExample(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    root_source_file: []const u8,
) !void {
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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();

    const path = try std.fs.path.join(gpa.allocator(), &.{ "bob", name });
    // defer gpa.allocator().free(path);

    const install = b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = path } } });
    b.default_step.dependOn(&install.step);
}
