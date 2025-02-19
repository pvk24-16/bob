const std = @import("std");
const rt_api = @import("rt_api.zig");

const c = @cImport({
    @cInclude("bob.h");
});

const Client = @This();

const ClientApi = struct {
    api: *@TypeOf(c.api),
    get_info: *const @TypeOf(c.get_info),
    create: *const @TypeOf(c.create),
    update: *const @TypeOf(c.update),
    destroy: *const @TypeOf(c.destroy),

    pub fn load(lib: *std.DynLib) !ClientApi {
        var self: ClientApi = undefined;
        inline for (std.meta.fields(ClientApi)) |field| {
            const ptr = lib.lookup(field.type, field.name) orelse {
                // TODO: logging
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

pub fn load(path: []const u8) !Client {
    var lib = try std.DynLib.open(path);
    const api = try ClientApi.load(&lib);
    return .{
        .lib = lib,
        .api = api,
        .ctx = null,
    };
}

pub fn create(self: *Client) void {
    self.ctx = self.api.create();
}

pub fn unload(client: *Client) void {
    client.api.destroy(client.ctx);
    client.lib.close();
}
