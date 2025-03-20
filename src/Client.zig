const std = @import("std");
const bob = @import("bob.zig");

const Client = @This();

const ClientApi = struct {
    get_info: *const @TypeOf(bob.get_info),
    create: *const @TypeOf(bob.create),
    update: *const @TypeOf(bob.update),
    destroy: *const @TypeOf(bob.destroy),

    pub fn load(lib: *std.DynLib) !ClientApi {
        var self: ClientApi = undefined;

        inline for (std.meta.fields(ClientApi)) |field| {
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
api: ClientApi,
ctx: ?*anyopaque,
info: bob.bob_visualization_info,

pub fn load(path: []const u8) !Client {
    var lib = try std.DynLib.open(path);
    const api = try ClientApi.load(&lib);
    const info = api.get_info().*;
    return .{
        .lib = lib,
        .api = api,
        .ctx = null,
        .info = info,
    };
}

pub fn create(self: *Client) void {
    self.ctx = self.api.create();
}

pub fn update(self: *const Client) void {
    self.api.update(self.ctx);
}

pub fn destroy(self: *const Client) void {
    self.api.destroy(self.ctx);
}

pub fn unload(client: *Client) void {
    client.lib.close();
}
