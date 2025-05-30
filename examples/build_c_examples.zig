const std = @import("std");
const builtin = @import("builtin");

const Example = struct {
    name: []const u8,
    sources: []const []const u8,
    extra_files: []const []const u8 = &.{},
    uses_opengl: bool = true,
    debug: bool = false,
};

const examples: []const Example = &.{
    .{
        .name = "simple",
        .sources = &.{"simple.c"},
        .debug = true,
    },
    .{
        .name = "perf",
        .sources = &.{"perf.c"},
        .debug = true,
    },
    .{
        .name = "key_test",
        .sources = &.{"key_test.c"},
        .debug = true,
    },
    .{
        .name = "debugvisual",
        .sources = &.{"debugvisual.c"},
        .debug = true,
    },
    .{
        .name = "debugprint",
        .sources = &.{"debugprint.c"},
        .debug = true,
    },
    .{
        .name = "beat",
        .sources = &.{"beat.c"},
        .debug = true,
    },
    .{
        .name = "breaks",
        .sources = &.{"breaks.c"},
        .debug = true,
    },
    .{
        .name = "error",
        .sources = &.{"error.c"},
        .uses_opengl = false,
        .debug = true,
    },
    .{
        .name = "cwd",
        .sources = &.{"cwd.c"},
        .extra_files = &.{"banana.txt"},
        .uses_opengl = false,
        .debug = true,
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
    build_debug_visualizers: bool,
) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    for (examples) |example| {
        if (example.debug and !build_debug_visualizers)
            continue;

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
