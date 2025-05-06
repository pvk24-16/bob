const std = @import("std");
const builtin = @import("builtin");

const Example = struct {
    name: []const u8,
    sources: []const []const u8,
    extra_files: []const []const u8 = &.{},
    uses_opengl: bool = true,
};

const examples: []const Example = &.{
    .{
        .name = "simple",
        .sources = &.{"simple.c"},
    },
    .{
        .name = "perf",
        .sources = &.{"perf.c"},
    },
    .{
        .name = "debugprint",
        .sources = &.{"debugprint.c"},
    },
    .{
        .name = "beat",
        .sources = &.{"beat.c"},
    },
    .{
        .name = "breaks",
        .sources = &.{"breaks.c"},
    },
    .{
        .name = "error",
        .sources = &.{"error.c"},
        .uses_opengl = false,
    },
    .{
        .name = "cwd",
        .sources = &.{"cwd.c"},
        .extra_files = &.{"banana.txt"},
        .uses_opengl = false,
    },
    .{
        .name = "meta_fifths",
        .sources = &.{
            "buffer.c",
            "graphics.c",
            "lattice.c",
            "marching.c",
            "meta_fifths.c",
            "params.c",
            "chroma.c",
        },
    },
};

pub fn build_c_examples(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    for (examples) |example| {
        const source_dir = try std.fs.path.join(gpa.allocator(), &.{ "examples", example.name });
        const dest_dir = try std.fs.path.join(gpa.allocator(), &.{ "bob", example.name });

        const lib = b.addSharedLibrary(.{
            .name = example.name,
            .target = target,
            .optimize = optimize,
            .pic = true,
        });

        lib.linkLibC();
        lib.linkSystemLibrary("m");
        lib.addIncludePath(b.path("api"));

        for (example.sources) |file| {
            const path = try std.fs.path.join(gpa.allocator(), &.{ source_dir, file });
            lib.addCSourceFile(.{ .file = b.path(path) });
        }

        for (example.extra_files) |file| {
            const source_path = try std.fs.path.join(gpa.allocator(), &.{ source_dir, file });
            const dest_path = try std.fs.path.join(gpa.allocator(), &.{ dest_dir, file });
            const install = b.addInstallFile(b.path(source_path), dest_path);
            b.default_step.dependOn(&install.step);
        }

        if (example.uses_opengl) {
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

            lib.addCSourceFile(.{ .file = b.path("deps/src/glad.c") });
            lib.addIncludePath(b.path("deps/include"));
        }

        const install = b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = dest_dir } } });
        b.default_step.dependOn(&install.step);
    }
}
