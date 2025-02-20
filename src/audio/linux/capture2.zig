const std = @import("std");

const LinuxImpl = struct {
    const pulse = @cImport({
        @cInclude("pulse/pulseaudio.h");
    });

    const log = std.log.scoped(.pulseaudio);

    const Error = error{
        capture_start,
        capture_stop,
        mainloop_init,
        mainloop_start,
        proplist_init,
        context_init,
        context_connect,
        client_info_init,
        sink_info_init,
        stream_init,
        stream_connect,
    };

    running: bool = false,

    channel: spsc.SwapBuffer(f32),
    mainloop: *pulse.pa_threaded_mainloop,
    context: *pulse.pa_context,
    stream: *pulse.pa_stream,

    pub fn init(config: Config, allocator: std.mem.Allocator) !LinuxImpl {
        var channel = try spsc.SwapBuffer(f32).init(
            config.bufferSize() * 4,
            allocator,
        );
        errdefer channel.deinit(allocator);
        log.info("channel initialized...", .{});

        const mainloop = pulse.pa_threaded_mainloop_new() orelse {
            return Error.mainloop_init;
        };
        errdefer pulse.pa_threaded_mainloop_free(mainloop);

        if (pulse.pa_threaded_mainloop_start(mainloop) < 0) {
            return Error.mainloop_start;
        }

        const context = try Context.init(mainloop);
        errdefer {
            pulse.pa_threaded_mainloop_lock(mainloop);
            pulse.pa_context_disconnect(context);
            pulse.pa_threaded_mainloop_unlock(mainloop);
        }
        log.info("context initialized...", .{});

        const client_info = try ClientInfo.init(config, mainloop, context);
        log.info("client info initialized...", .{});

        const sink_input_info = try SinkInputInfo.init(&client_info, mainloop, context);
        log.info("sink input info initialized...", .{});

        const stream = try Stream.init(config, &sink_input_info, mainloop, context);
        errdefer {
            pulse.pa_threaded_mainloop_lock(mainloop);
            _ = pulse.pa_stream_disconnect(stream);
            pulse.pa_threaded_mainloop_unlock(mainloop);
        }
        log.info("stream initialized...", .{});

        return LinuxImpl{
            .channel = channel,
            .mainloop = mainloop,
            .context = context,
            .stream = stream,
        };
    }

    pub fn deinit(self: *LinuxImpl, allocator: std.mem.Allocator) void {
        pulse.pa_threaded_mainloop_lock(self.mainloop);
        _ = pulse.pa_stream_disconnect(self.stream);
        pulse.pa_threaded_mainloop_unlock(self.mainloop);
        log.info("stream deinitialized...", .{});

        pulse.pa_threaded_mainloop_lock(self.mainloop);
        pulse.pa_context_disconnect(self.context);
        pulse.pa_threaded_mainloop_unlock(self.mainloop);
        log.info("context deinitialized...", .{});

        pulse.pa_threaded_mainloop_free(self.mainloop);
        log.info("mainloop deinitialized...", .{});

        self.channel.deinit(allocator);
        log.info("channel deinitialized...", .{});

        self.* = undefined;
    }

    pub fn start(self: *LinuxImpl) !void {
        if (!self.running) {
            pulse.pa_threaded_mainloop_lock(self.mainloop);
            pulse.pa_stream_set_read_callback(self.stream, captureLoop, &self.channel);
            pulse.pa_threaded_mainloop_unlock(self.mainloop);

            self.running = true;
        }

        return Cork.call(self.stream, self.mainloop, false);
    }

    pub fn stop(self: *LinuxImpl) !void {
        return Cork.call(self.stream, self.mainloop, true);
    }

    pub fn sample(self: *LinuxImpl) []const f32 {
        return self.channel.receive();
    }

    fn captureLoop(stream: ?*pulse.pa_stream, nbytes: usize, userdata: ?*anyopaque) callconv(.C) void {
        var channel: *spsc.SwapBuffer(f32) = @ptrCast(@alignCast(userdata.?));
        var buf: ?[*]f32 = undefined;
        var len: usize = nbytes;

        if (pulse.pa_stream_peek(stream, @ptrCast(@alignCast(&buf)), @ptrCast(@alignCast(&len))) < 0) {
            return;
        }

        if (buf) |okbuf| {
            channel.send(okbuf[0..len]);
        }

        _ = pulse.pa_stream_drop(stream);
    }

    const Context = struct {
        ok: bool,
        mainloop: *pulse.pa_threaded_mainloop,

        pub fn init(mainloop: *pulse.pa_threaded_mainloop) !*pulse.pa_context {
            const proplist = pulse.pa_proplist_new() orelse {
                return Error.proplist_init;
            };

            defer pulse.pa_proplist_free(proplist);

            const api = pulse.pa_threaded_mainloop_get_api(mainloop);

            const context = pulse.pa_context_new_with_proplist(api, @ptrCast(@alignCast("pvk")), proplist) orelse {
                return Error.context_init;
            };

            var userdata = Context{
                .ok = false,
                .mainloop = mainloop,
            };

            pulse.pa_threaded_mainloop_lock(mainloop);
            pulse.pa_context_set_state_callback(context, callback, &userdata);
            _ = pulse.pa_context_connect(context, null, pulse.PA_CONTEXT_NOAUTOSPAWN, null);
            pulse.pa_threaded_mainloop_wait(mainloop);
            pulse.pa_threaded_mainloop_unlock(mainloop);

            if (!userdata.ok) {
                return Error.context_connect;
            }

            return context;
        }

        fn callback(context: ?*pulse.pa_context, userdata: ?*anyopaque) callconv(.C) void {
            var data: *Context = @ptrCast(@alignCast(userdata.?));
            const state = pulse.pa_context_get_state(context);

            if (state == pulse.PA_CONTEXT_READY) {
                data.ok = true;
                pulse.pa_threaded_mainloop_signal(data.mainloop, 0);
            } else if (state == pulse.PA_CONTEXT_FAILED) {
                data.ok = false;
                pulse.pa_threaded_mainloop_signal(data.mainloop, 0);
            }
        }
    };

    const ClientInfo = struct {
        ok: bool,
        client_info: pulse.pa_client_info,
        process_id: []const u8,
        mainloop: *pulse.pa_threaded_mainloop,

        pub fn init(config: Config, mainloop: *pulse.pa_threaded_mainloop, context: *pulse.pa_context) !pulse.pa_client_info {
            var userdata = ClientInfo{
                .ok = false,
                .client_info = undefined,
                .process_id = config.process_id,
                .mainloop = mainloop,
            };

            pulse.pa_threaded_mainloop_lock(mainloop);
            _ = pulse.pa_context_get_client_info_list(context, callback, &userdata);
            pulse.pa_threaded_mainloop_wait(mainloop);
            pulse.pa_threaded_mainloop_unlock(mainloop);

            if (!userdata.ok) {
                return Error.client_info_init;
            }

            return userdata.client_info;
        }

        fn callback(_: ?*pulse.pa_context, cinfo: ?*const pulse.pa_client_info, eol: c_int, userdata: ?*anyopaque) callconv(.C) void {
            var data: *ClientInfo = @ptrCast(@alignCast(userdata.?));

            if (eol > 0) {
                pulse.pa_threaded_mainloop_signal(data.mainloop, 0);
                return;
            }

            const info = cinfo orelse return;
            const ptr = pulse.pa_proplist_gets(info.proplist, pulse.PA_PROP_APPLICATION_PROCESS_ID) orelse return;
            const len = std.mem.indexOfSentinel(u8, 0, ptr);

            if (std.mem.eql(u8, data.process_id, ptr[0..len])) {
                data.ok = true;
                data.client_info = info.*;
            }
        }
    };

    const SinkInputInfo = struct {
        ok: bool,
        sink_input_info: pulse.pa_sink_input_info,
        client_id: u32,
        mainloop: *pulse.pa_threaded_mainloop,

        pub fn init(client_info: *const pulse.pa_client_info, mainloop: *pulse.pa_threaded_mainloop, context: *pulse.pa_context) !pulse.pa_sink_input_info {
            var userdata = SinkInputInfo{
                .ok = false,
                .sink_input_info = undefined,
                .client_id = client_info.index,
                .mainloop = mainloop,
            };

            pulse.pa_threaded_mainloop_lock(mainloop);
            _ = pulse.pa_context_get_sink_input_info_list(context, callback, &userdata);
            pulse.pa_threaded_mainloop_wait(mainloop);
            pulse.pa_threaded_mainloop_unlock(mainloop);

            if (!userdata.ok) {
                return Error.sink_info_init;
            }

            return userdata.sink_input_info;
        }

        fn callback(_: ?*pulse.pa_context, cinfo: ?*const pulse.pa_sink_input_info, eol: c_int, userdata: ?*anyopaque) callconv(.C) void {
            const data: *SinkInputInfo = @ptrCast(@alignCast(userdata.?));

            if (eol > 0) {
                pulse.pa_threaded_mainloop_signal(data.mainloop, 0);
                return;
            }

            const info = cinfo orelse return;

            if (data.client_id == info.client) {
                data.ok = true;
                data.sink_input_info = info.*;
            }
        }
    };

    const Stream = struct {
        ok: bool,
        mainloop: *pulse.pa_threaded_mainloop,

        pub fn init(config: Config, sink_input_info: *const pulse.pa_sink_input_info, mainloop: *pulse.pa_threaded_mainloop, context: *pulse.pa_context) !*pulse.pa_stream {
            const proplist = pulse.pa_proplist_new() orelse {
                return Error.proplist_init;
            };

            defer pulse.pa_proplist_free(proplist);

            const sample_spec = pulse.pa_sample_spec{
                .channels = @intCast(config.channels),
                .rate = config.sample_rate,
                .format = pulse.PA_SAMPLE_FLOAT32,
            };

            const stream = pulse.pa_stream_new_with_proplist(context, @ptrCast(@alignCast("pvk")), &sample_spec, &sink_input_info.channel_map, proplist) orelse {
                return Error.stream_init;
            };

            var userdata = Stream{ .ok = false, .mainloop = mainloop };

            const dev: [*c]u8 = null;
            const flags = pulse.PA_STREAM_START_CORKED | pulse.PA_STREAM_ADJUST_LATENCY;
            const attr = pulse.pa_buffer_attr{
                .maxlength = ~@as(u32, 0),
                .tlength = ~@as(u32, 0),
                .prebuf = ~@as(u32, 0),
                .minreq = ~@as(u32, 0),
                .fragsize = config.windowSize(),
            };

            pulse.pa_threaded_mainloop_lock(mainloop);
            pulse.pa_stream_set_state_callback(stream, callback, &userdata);
            _ = pulse.pa_stream_set_monitor_stream(stream, sink_input_info.index);
            _ = pulse.pa_stream_connect_record(stream, dev, &attr, flags);
            pulse.pa_threaded_mainloop_wait(mainloop);
            pulse.pa_threaded_mainloop_unlock(mainloop);

            if (!userdata.ok or pulse.pa_stream_get_state(stream) != pulse.PA_STREAM_READY) {
                return Error.stream_connect;
            }

            return stream;
        }

        fn callback(stream: ?*pulse.pa_stream, userdata: ?*anyopaque) callconv(.C) void {
            var data: *Stream = @ptrCast(@alignCast(userdata.?));
            const state = pulse.pa_stream_get_state(stream);

            if (state == pulse.PA_STREAM_READY) {
                data.ok = true;
                pulse.pa_threaded_mainloop_signal(data.mainloop, 0);
            } else if (state == pulse.PA_STREAM_FAILED) {
                data.ok = false;
                pulse.pa_threaded_mainloop_signal(data.mainloop, 0);
            }
        }
    };

    const Cork = struct {
        ok: bool,
        mainloop: *pulse.pa_threaded_mainloop,

        fn call(stream: *pulse.pa_stream, mainloop: *pulse.pa_threaded_mainloop, cork: bool) !void {
            var userdata = Cork{
                .ok = false,
                .mainloop = mainloop,
            };

            pulse.pa_threaded_mainloop_lock(mainloop);

            const op = pulse.pa_stream_cork(
                stream,
                @intFromBool(cork),
                callback,
                &userdata,
            );

            while (pulse.pa_operation_get_state(op) == pulse.PA_OPERATION_RUNNING) {
                pulse.pa_threaded_mainloop_wait(mainloop);
            }

            pulse.pa_operation_unref(op);
            pulse.pa_threaded_mainloop_unlock(mainloop);

            if (!userdata.ok) {
                return if (cork) Error.capture_stop else Error.capture_start;
            }
        }

        fn callback(_: ?*pulse.pa_stream, success: c_int, userdata: ?*anyopaque) callconv(.C) void {
            var data: *Cork = @ptrCast(@alignCast(userdata.?));

            if (success != 0) {
                data.ok = true;
            }

            pulse.pa_threaded_mainloop_signal(data.mainloop, 0);
        }
    };
};
