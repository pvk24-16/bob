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
        .pic = true,
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

    for (source) |file| {
        lib.addCSourceFile(.{ .file = b.path(file) });
    }
    lib.addCSourceFile(.{ .file = b.path("deps/src/glad.c") });

    lib.addIncludePath(b.path("deps/include"));
    lib.addIncludePath(b.path("api"));

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();

    const path = try std.fs.path.join(gpa.allocator(), &.{ "bob", name });
    // defer gpa.allocator().free(path);

    const install = b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = path } } });
    b.default_step.dependOn(&install.step);
}
