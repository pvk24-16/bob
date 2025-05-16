//!
//! Holds data associated with a loaded visualizer
//!

const std = @import("std");
const bob = @import("bob_api.zig");

const Visualizer = @This();

/// Holds function pointers for the dynamic library side API
const VisualizerApi = struct {
    api: *@TypeOf(bob.api),
    get_info: *const @TypeOf(bob.get_info),
    create: *const @TypeOf(bob.create),
    update: *const @TypeOf(bob.update),
    destroy: *const @TypeOf(bob.destroy),

    pub fn load(lib: *std.DynLib) !VisualizerApi {
        var self: VisualizerApi = undefined;

        inline for (std.meta.fields(VisualizerApi)) |field| {
            const ptr = lib.lookup(field.type, field.name) orelse {
                std.log.err("Missing symbol '" ++ field.name ++ "'\n", .{});

                return error.MissingSymbol;
            };

            @field(self, field.name) = @ptrCast(ptr);
        }

        return self;
    }
};

lib: std.DynLib,
api: VisualizerApi,
info: bob.bob_visualizer_info,

/// Load the client and get some info
pub fn load(path: []const u8) !Visualizer {
    var lib = try std.DynLib.open(path);
    const api = try VisualizerApi.load(&lib);
    const info = api.get_info().*;
    return .{
        .lib = lib,
        .api = api,
        .info = info,
    };
}

// Visualizer API wrappers
pub fn create(self: *Visualizer) ?[]const u8 {
    if (self.api.create()) |err| {
        return std.mem.span(err);
    }
    return null;
}

pub fn update(self: *const Visualizer) void {
    self.api.update();
}

pub fn destroy(self: *const Visualizer) void {
    self.api.destroy();
}

pub fn unload(visualizer: *Visualizer) void {
    visualizer.lib.close();
}
