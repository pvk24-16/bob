const std = @import("std");
const pulse = @cImport({
    @cInclude("pulse/pulseaudio.h");
});

const Allocator = std.mem.Allocator;

// Requires Tiger-style initialization.
const CaptureBase = @import("../base.zig");

const LinuxCaptureImpl = @This();
const cname = "capture";
const sname = "capture_stream_0";
pub const Error = error{
    allocate_mainloop_failure,
    start_mainloop_failure,
    create_context_failure,
    create_stream_failure,
    connect_to_server_failure,
    connect_to_client_failure,
    invalid_connect_params,
    no_client_found,
    no_sink_found,
    failed_to_cork,
};

pid_str: []const u8 = undefined,
mainloop: *pulse.pa_threaded_mainloop = undefined,
context: *pulse.pa_context = undefined,
stream: *pulse.pa_stream = undefined,
stream_name: []u8 = undefined,
sample_spec: pulse.pa_sample_spec = undefined,
client_id: u32 = pulse.PA_INVALID_INDEX,
sink_id: u32 = undefined,
base: CaptureBase = undefined,

/// Create linux capture.
pub fn init(
    self: *LinuxCaptureImpl,
    process_str: []const u8,
    capacity: usize,
    allocator: Allocator,
) !void {
    self.pid_str = process_str;
    self.mainloop = pulse.pa_threaded_mainloop_new() orelse {
        return Error.allocate_mainloop_failure;
    };

    if (pulse.pa_threaded_mainloop_start(self.mainloop) < 0) {
        return Error.start_mainloop_failure;
    }

    try self.createContext();
    var client = try self.getClient();
    try self.selectClient(&client);
    try self.connect(capacity);

    pulse.pa_threaded_mainloop_lock(self.mainloop);
    pulse.pa_stream_set_read_callback(self.stream, sampleCallback, self);
    pulse.pa_threaded_mainloop_unlock(self.mainloop);

    self.base = try CaptureBase.init(capacity, allocator);
}

/// Destory linux capture.
pub fn deinit(self: *LinuxCaptureImpl) void {
    self.base.deinit();
    pulse.pa_threaded_mainloop_lock(self.mainloop);
    _ = pulse.pa_stream_disconnect(self.stream);
    pulse.pa_context_disconnect(self.context);
    pulse.pa_threaded_mainloop_unlock(self.mainloop);
    pulse.pa_threaded_mainloop_free(self.mainloop);
}

/// Start audio capture.
pub fn startCapture(self: *LinuxCaptureImpl) !void {
    try self.cork(false);
}

/// Stop audio capture.
pub fn stopCapture(self: *LinuxCaptureImpl) !void {
    try self.cork(true);
}

/// Retrieve sample rate.
pub fn sampleRate(self: *LinuxCaptureImpl) u32 {
    return self.sample_spec.rate;
}

fn sampleCallback(_: ?*pulse.pa_stream, _: usize, userdata: ?*anyopaque) callconv(.C) void {
    const self: *LinuxCaptureImpl = @ptrCast(@alignCast(userdata.?));

    var data: ?[*]f32 = undefined;
    var size: usize = ~@as(u32, 0);

    while (size > 0) {
        _ = pulse.pa_stream_peek(
            self.stream,
            @ptrCast(@alignCast(&data)),
            &size,
        );

        if (data) |d| {
            const data_size = size / (@sizeOf(f32) * self.sample_spec.channels);
            self.base.ring.write(d[0..data_size]);
            _ = pulse.pa_stream_drop(self.stream);
        } else break;
    }
}

/// Create pulseaudio context.
inline fn createContext(self: *LinuxCaptureImpl) !void {
    const api = pulse.pa_threaded_mainloop_get_api(self.mainloop);
    self.context = pulse.pa_context_new(api, @ptrCast(cname)) orelse {
        return Error.create_context_failure;
    };

    var userdata = CreateContextCallback{ .ctx = self };

    pulse.pa_threaded_mainloop_lock(self.mainloop);
    pulse.pa_context_set_state_callback(self.context, CreateContextCallback.createContext, &userdata);
    if (pulse.pa_context_connect(
        self.context,
        null,
        pulse.PA_CONTEXT_NOAUTOSPAWN,
        null,
    ) < 0) return Error.invalid_connect_params;

    pulse.pa_threaded_mainloop_wait(self.mainloop);
    pulse.pa_threaded_mainloop_unlock(self.mainloop);
    if (!userdata.ok) return Error.connect_to_server_failure;
}

inline fn getClient(self: *LinuxCaptureImpl) !u32 {
    var userdata = GetClientCallback{ .ctx = self };

    pulse.pa_threaded_mainloop_lock(self.mainloop);
    _ = pulse.pa_context_get_client_info_list(self.context, GetClientCallback.getClient, &userdata);
    pulse.pa_threaded_mainloop_wait(self.mainloop);
    pulse.pa_threaded_mainloop_unlock(self.mainloop);

    if (userdata.client) |client| return client;
    return Error.no_client_found;
}

/// Select a sink.
inline fn selectClient(self: *LinuxCaptureImpl, client: *u32) !void {
    var userdata = SelectClientCallback{
        .index = client,
        .ctx = self,
    };

    pulse.pa_threaded_mainloop_lock(self.mainloop);
    _ = pulse.pa_context_get_sink_input_info_list(
        self.context,
        SelectClientCallback.selectClient,
        &userdata,
    );
    pulse.pa_threaded_mainloop_wait(self.mainloop);
    pulse.pa_threaded_mainloop_unlock(self.mainloop);

    if (self.client_id == pulse.PA_INVALID_INDEX) {
        return Error.no_sink_found;
    }
}

/// Connect to a sink.
inline fn connect(self: *LinuxCaptureImpl, capacity: usize) !void {
    const proplist = pulse.pa_proplist_new().?;
    pulse.pa_threaded_mainloop_lock(self.mainloop);
    const stream: ?*pulse.pa_stream = pulse.pa_stream_new_with_proplist(
        self.context,
        sname[0..].ptr,
        &self.sample_spec,
        null,
        proplist,
    );
    pulse.pa_threaded_mainloop_unlock(self.mainloop);
    pulse.pa_proplist_free(proplist);

    if (stream) |s| {
        self.stream = s;
    } else return Error.create_stream_failure;

    var userdata = ConnectCallback{ .ctx = self };
    const dev: [*c]u8 = null;
    const flags: pulse.pa_stream_flags = pulse.PA_STREAM_ADJUST_LATENCY | pulse.PA_STREAM_START_CORKED;
    const attributes = pulse.pa_buffer_attr{
        .maxlength = ~@as(u32, 0),
        .tlength = ~@as(u32, 0),
        .prebuf = ~@as(u32, 0),
        .minreq = ~@as(u32, 0),
        .fragsize = @truncate(capacity * @sizeOf(f32)),
    };

    pulse.pa_threaded_mainloop_lock(self.mainloop);
    pulse.pa_stream_set_state_callback(self.stream, ConnectCallback.connect, &userdata);
    _ = pulse.pa_stream_set_monitor_stream(self.stream, self.sink_id);
    _ = pulse.pa_stream_connect_record(
        self.stream,
        dev,
        &attributes,
        flags,
    );
    pulse.pa_threaded_mainloop_wait(self.mainloop);
    pulse.pa_threaded_mainloop_unlock(self.mainloop);

    if (!userdata.ok) return Error.connect_to_client_failure;
}

/// Cork or uncork a sink.
inline fn cork(self: *LinuxCaptureImpl, c: bool) !void {
    var userdata = CorkCallback{ .ctx = self };

    pulse.pa_threaded_mainloop_lock(self.mainloop);
    const op = pulse.pa_stream_cork(
        self.stream,
        @intFromBool(c),
        CorkCallback.cork,
        &userdata,
    );

    while (pulse.pa_operation_get_state(op) == pulse.PA_OPERATION_RUNNING) {
        pulse.pa_threaded_mainloop_wait(self.mainloop);
    }
    pulse.pa_operation_unref(op);
    pulse.pa_threaded_mainloop_unlock(self.mainloop);

    if (!userdata.ok) return Error.failed_to_cork;
}

const CreateContextCallback = struct {
    ok: bool = true,
    ctx: *LinuxCaptureImpl = undefined,

    pub fn createContext(
        context: ?*pulse.pa_context,
        userdata: ?*anyopaque,
    ) callconv(.C) void {
        var data: *CreateContextCallback = @ptrCast(@alignCast(userdata.?));
        const state = pulse.pa_context_get_state(context);

        if (state == pulse.PA_CONTEXT_FAILED) data.ok = false;

        switch (state) {
            pulse.PA_CONTEXT_READY, pulse.PA_CONTEXT_FAILED => {
                pulse.pa_threaded_mainloop_signal(data.ctx.mainloop, 0);
            },
            else => {},
        }
    }
};

const GetClientCallback = struct {
    client: ?u32 = null,
    ctx: *LinuxCaptureImpl = undefined,

    pub fn getClient(
        _: ?*pulse.pa_context,
        cinfo: ?*const pulse.pa_client_info,
        eol: c_int,
        userdata: ?*anyopaque,
    ) callconv(.C) void {
        var data: *GetClientCallback = @ptrCast(@alignCast(userdata.?));
        if (eol > 0) {
            pulse.pa_threaded_mainloop_signal(data.ctx.mainloop, 0);
            return;
        }

        const info = cinfo orelse return;
        const value: []const u8 = v: {
            if (pulse.pa_proplist_gets(info.proplist, pulse.PA_PROP_APPLICATION_PROCESS_ID)) |val| {
                const len = std.mem.indexOfSentinel(u8, 0, val);
                break :v val[0..len];
            } else {
                return;
            }
        };

        if (std.mem.eql(u8, data.ctx.pid_str, value)) {
            data.client = info.index;
        }
    }
};

const SelectClientCallback = struct {
    index: *u32 = undefined,
    ctx: *LinuxCaptureImpl = undefined,

    pub fn selectClient(
        _: ?*pulse.pa_context,
        cinfo: ?*const pulse.pa_sink_input_info,
        eol: c_int,
        userdata: ?*anyopaque,
    ) callconv(.C) void {
        const data: *SelectClientCallback = @ptrCast(@alignCast(userdata.?));

        if (eol > 0) {
            pulse.pa_threaded_mainloop_signal(data.ctx.mainloop, 0);
            return;
        }

        const info = cinfo orelse return;
        if (data.ctx.client_id != pulse.PA_INVALID_INDEX) return;

        if (data.index.* == info.client) {
            data.ctx.client_id = data.index.*;
            data.ctx.sink_id = info.index;
            data.ctx.sample_spec = info.sample_spec;
            data.ctx.sample_spec.channels = 5;
        }
    }
};

const ConnectCallback = struct {
    ok: bool = true,
    ctx: *LinuxCaptureImpl = undefined,

    pub fn connect(
        s: ?*pulse.pa_stream,
        userdata: ?*anyopaque,
    ) callconv(.C) void {
        var data: *ConnectCallback = @ptrCast(@alignCast(userdata.?));
        const state = pulse.pa_stream_get_state(s);

        if (state == pulse.PA_STREAM_FAILED) data.ok = false;
        switch (state) {
            pulse.PA_STREAM_FAILED, pulse.PA_STREAM_READY => {
                pulse.pa_threaded_mainloop_signal(data.ctx.mainloop, 0);
            },
            else => {},
        }
    }
};

const CorkCallback = struct {
    ok: bool = true,
    ctx: *LinuxCaptureImpl = undefined,

    pub fn cork(
        _: ?*pulse.pa_stream,
        success: c_int,
        userdata: ?*anyopaque,
    ) callconv(.C) void {
        var data: *CorkCallback = @ptrCast(@alignCast(userdata.?));
        if (success == 0) data.ok = false;
        pulse.pa_threaded_mainloop_signal(data.ctx.mainloop, 0);
    }
};
