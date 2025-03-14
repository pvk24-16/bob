const std = @import("std");

const RingBuffer = @import("../buffer.zig").RingBuffer;
const Config = @import("../Config.zig");

pub const LinuxImpl = struct {
    const pulse = @cImport({
        @cInclude("pulse/pulseaudio.h");
    });

    const log = std.log.scoped(.pulseaudio);

    const Error = error{
        capture_start,
        capture_stop,
        mainloop_init,
        mainloop_start,
        context_init,
        context_connect,
        stream_init,
    };

    running: bool = false,

    mutex: std.Thread.Mutex,
    ring_buffer: RingBuffer,
    mainloop: *pulse.pa_threaded_mainloop,
    context: *pulse.pa_context,
    stream: *pulse.pa_stream,

    pub fn init(config: Config, allocator: std.mem.Allocator) !LinuxImpl {
        const mainloop = pulse.pa_threaded_mainloop_new() orelse {
            return error.mainloop_init;
        };
        errdefer pulse.pa_threaded_mainloop_free(mainloop);
        log.info("mainloop initialized...", .{});

        if (pulse.pa_threaded_mainloop_start(mainloop) < 0) {
            return error.mainloop_start;
        }

        const context = try Context.init(mainloop);
        errdefer {
            pulse.pa_threaded_mainloop_lock(mainloop);
            pulse.pa_context_disconnect(context);
            pulse.pa_threaded_mainloop_unlock(mainloop);
        }
        log.info("context connected...", .{});

        const sink_input_info = try SinkInputInfo.init(config, mainloop, context);
        log.info("sink input info initialized...", .{});

        const stream = try Stream.init(&sink_input_info, mainloop, context);
        errdefer {
            pulse.pa_threaded_mainloop_lock(mainloop);
            _ = pulse.pa_stream_disconnect(stream);
            pulse.pa_threaded_mainloop_unlock(mainloop);
        }
        log.info("stream connected...", .{});

        var ring_buffer = try RingBuffer.init(Config.windowSize() / @sizeOf(f32), allocator);
        errdefer ring_buffer.deinit(allocator);

        return LinuxImpl{
            .mutex = .{},
            .ring_buffer = ring_buffer,
            .mainloop = mainloop,
            .context = context,
            .stream = stream,
        };
    }

    pub fn deinit(self: *LinuxImpl, allocator: std.mem.Allocator) void {
        pulse.pa_threaded_mainloop_lock(self.mainloop);
        _ = pulse.pa_stream_disconnect(self.stream);
        pulse.pa_threaded_mainloop_unlock(self.mainloop);
        log.info("stream disconnected...", .{});

        pulse.pa_threaded_mainloop_lock(self.mainloop);
        pulse.pa_context_disconnect(self.context);
        pulse.pa_threaded_mainloop_unlock(self.mainloop);
        log.info("context disconnected...", .{});

        pulse.pa_threaded_mainloop_free(self.mainloop);
        log.info("mainloop deinitialized...", .{});

        self.ring_buffer.deinit(allocator);
        self.* = undefined;
    }

    pub fn start(self: *LinuxImpl) !void {
        if (!self.running) {
            pulse.pa_threaded_mainloop_lock(self.mainloop);
            pulse.pa_stream_set_read_callback(self.stream, captureLoop, self);
            pulse.pa_threaded_mainloop_unlock(self.mainloop);

            self.running = true;
        }

        return Cork.call(self.stream, self.mainloop, false);
    }

    pub fn stop(self: *LinuxImpl) !void {
        return Cork.call(self.stream, self.mainloop, true);
    }

    pub fn sample(self: *LinuxImpl) []const f32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.ring_buffer.receive();
    }

    fn captureLoop(stream: ?*pulse.pa_stream, nbytes: usize, userdata: ?*anyopaque) callconv(.C) void {
        var self: *LinuxImpl = @ptrCast(@alignCast(userdata.?));
        var buf: ?[*]f32 = undefined;
        var bytes: usize = nbytes;

        if (pulse.pa_stream_peek(stream, @ptrCast(@alignCast(&buf)), @ptrCast(@alignCast(&bytes))) < 0) {
            return;
        }

        if (buf) |okbuf| {
            const len = bytes / @sizeOf(f32);
            self.mutex.lock();
            self.ring_buffer.send(okbuf[0..len]);
            self.mutex.unlock();
            _ = pulse.pa_stream_drop(stream);
        } else if (bytes != 0) {
            _ = pulse.pa_stream_drop(stream);
        }
    }

    const Context = struct {
        ok: bool,
        mainloop: *pulse.pa_threaded_mainloop,

        pub fn init(mainloop: *pulse.pa_threaded_mainloop) !*pulse.pa_context {
            const proplist = pulse.pa_proplist_new() orelse {
                return error.fail;
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

    const SinkInputInfo = struct {
        ok: bool,
        sink_input_info: pulse.pa_sink_input_info,
        mainloop: *pulse.pa_threaded_mainloop,
        process_id: []const u8,

        pub fn init(config: Config, mainloop: *pulse.pa_threaded_mainloop, context: *pulse.pa_context) !pulse.pa_sink_input_info {
            var userdata = SinkInputInfo{
                .ok = false,
                .sink_input_info = undefined,
                .mainloop = mainloop,
                .process_id = config.process_id,
            };

            pulse.pa_threaded_mainloop_lock(mainloop);
            _ = pulse.pa_context_get_sink_input_info_list(context, callback, &userdata);
            pulse.pa_threaded_mainloop_wait(mainloop);
            pulse.pa_threaded_mainloop_unlock(mainloop);

            if (!userdata.ok) {
                return error.sink_info_init;
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
            const ptr = pulse.pa_proplist_gets(info.proplist, pulse.PA_PROP_APPLICATION_PROCESS_ID) orelse return;
            const len = std.mem.indexOfSentinel(u8, 0, ptr);

            if (std.mem.eql(u8, data.process_id, ptr[0..len])) {
                data.ok = true;
                data.sink_input_info = info.*;
                if (info.sample_spec.rate != Config.sample_rate)
                    std.log.warn("sink input samplerate {d} does not match hardcoded value {d}", .{ info.sample_spec.rate, Config.sample_rate });
            }
        }
    };

    const Stream = struct {
        ok: bool,
        mainloop: *pulse.pa_threaded_mainloop,

        pub fn init(sink_input_info: *const pulse.pa_sink_input_info, mainloop: *pulse.pa_threaded_mainloop, context: *pulse.pa_context) !*pulse.pa_stream {
            const proplist = pulse.pa_proplist_new() orelse {
                return error.fail;
            };

            defer pulse.pa_proplist_free(proplist);

            const sample_spec = pulse.pa_sample_spec{
                .channels = Config.channel_count,
                .rate = Config.sample_rate,
                .format = pulse.PA_SAMPLE_FLOAT32NE,
            };

            const stream = pulse.pa_stream_new_with_proplist(context, @ptrCast(@alignCast("pvk")), &sample_spec, null, proplist) orelse {
                return Error.stream_init;
            };

            var userdata = Stream{
                .ok = false,
                .mainloop = mainloop,
            };

            const dev: [*c]u8 = null;
            const flags = pulse.PA_STREAM_START_CORKED | pulse.PA_STREAM_ADJUST_LATENCY;
            const attr = pulse.pa_buffer_attr{
                .maxlength = ~@as(u32, 0),
                .tlength = ~@as(u32, 0),
                .prebuf = ~@as(u32, 0),
                .minreq = ~@as(u32, 0),
                .fragsize = Config.windowSize(),
            };

            pulse.pa_threaded_mainloop_lock(mainloop);
            pulse.pa_stream_set_state_callback(stream, callback, &userdata);
            _ = pulse.pa_stream_set_monitor_stream(stream, sink_input_info.index);
            _ = pulse.pa_stream_connect_record(stream, dev, &attr, flags);
            pulse.pa_threaded_mainloop_wait(mainloop);
            pulse.pa_threaded_mainloop_unlock(mainloop);

            if (!userdata.ok or pulse.pa_stream_get_state(stream) != pulse.PA_STREAM_READY) {
                return error.fail;
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
                return error.cork;
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
