const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const os_tag = target.result.os.tag;

    const mod = b.addModule("render", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    switch (os_tag) {
        .windows => mod.linkSystemLibrary("opengl32", .{}),
        .linux => mod.linkSystemLibrary("GL", .{}),
        .macos => mod.linkFramework("OpenGL", .{}),
        else => @panic("Unsupported platform"),
    }

    mod.addIncludePath(b.path("deps/include/"));
    mod.addCSourceFiles(.{ .files = &.{"deps/src/glad.c"} });
    mod.addCSourceFiles(.{ .files = &.{"deps/src/stb_image_fix.c"} });
}
