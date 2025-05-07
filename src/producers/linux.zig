const std = @import("std");
const pulse = @import("../audio/linux/pulse.zig");

const AudioProducerEntry = @import("./AudioProducerEntry.zig");

pub fn enumerateAudioProducers(list: *AudioProducerEntry.List) !void {
    errdefer list.clearRetainingCapacity();

    const mainloop = pulse.pa_threaded_mainloop_new() orelse {
        return error.@"Failed to create mainloop";
    };
    defer pulse.pa_threaded_mainloop_free(mainloop);

    if (pulse.pa_threaded_mainloop_start(mainloop) < 0) {
        return error.@"Failed to start mainloop";
    }
    defer pulse.pa_threaded_mainloop_stop(mainloop);

    const api = pulse.pa_threaded_mainloop_get_api(mainloop);
    const context = pulse.pa_context_new(api, "bob-list-clients-context") orelse {
        return error.@"Failed to create context";
    };

    const ConnectData = struct {
        mainloop: @TypeOf(mainloop),
        ok: bool = false,

        fn callback(
            ctx: ?*pulse.pa_context,
            userdata: ?*anyopaque,
        ) callconv(.C) void {
            const data_ptr: *@This() = @ptrCast(@alignCast(userdata.?));
            const state = pulse.pa_context_get_state(ctx);

            switch (state) {
                pulse.PA_CONTEXT_READY => data_ptr.ok = true,
                pulse.PA_CONTEXT_FAILED => {},
                else => return,
            }

            pulse.pa_threaded_mainloop_signal(data_ptr.mainloop, 0);
        }
    };

    var connect_data: ConnectData = .{ .mainloop = mainloop };

    pulse.pa_threaded_mainloop_lock(mainloop);
    pulse.pa_context_set_state_callback(context, ConnectData.callback, @ptrCast(&connect_data));
    _ = pulse.pa_context_connect(context, null, pulse.PA_CONTEXT_NOAUTOSPAWN, null);
    pulse.pa_threaded_mainloop_wait(mainloop);
    pulse.pa_threaded_mainloop_unlock(mainloop);

    if (!connect_data.ok)
        return error.@"Failed to connect to PulseAudio server";

    defer pulse.pa_context_disconnect(context);

    const ListData = struct {
        list: @TypeOf(list),
        mainloop: @TypeOf(mainloop),
        ok: bool = true,

        pub fn callback(
            ctx: ?*pulse.pa_context,
            info: ?*const pulse.pa_sink_input_info,
            eol: c_int,
            userdata: ?*anyopaque,
        ) callconv(.C) void {
            _ = ctx;
            const data_ptr: *@This() = @ptrCast(@alignCast(userdata));

            if (!data_ptr.ok or eol != 0) {
                pulse.pa_threaded_mainloop_signal(data_ptr.mainloop, 0);
                return;
            }

            var key: [*c]const u8 = pulse.PA_PROP_APPLICATION_PROCESS_ID;
            var value = pulse.pa_proplist_gets(info.?.proplist, key);
            const process_id = std.mem.span(value orelse return);

            key = pulse.PA_PROP_APPLICATION_NAME;
            value = pulse.pa_proplist_gets(info.?.proplist, key);
            var name = std.mem.span(value orelse return);

            key = pulse.PA_PROP_MEDIA_NAME;
            value = pulse.pa_proplist_gets(info.?.proplist, key);
            if (value) |media_name| {
                name = std.mem.span(media_name);
            }

            var entry: AudioProducerEntry = undefined;

            const name_len = @min(name.len, entry.name.len - 1);
            const process_id_len = @min(process_id.len, entry.process_id.len - 1);
            @memcpy(entry.name[0..name_len], name);
            @memcpy(entry.process_id[0..process_id_len], process_id);

            entry.name[name_len] = 0;
            entry.process_id[process_id_len] = 0;

            data_ptr.list.append(entry) catch {
                data_ptr.ok = false;
            };
        }
    };

    var list_data: ListData = .{ .list = list, .mainloop = mainloop };

    pulse.pa_threaded_mainloop_lock(mainloop);
    _ = pulse.pa_context_get_sink_input_info_list(context, ListData.callback, @ptrCast(&list_data));
    pulse.pa_threaded_mainloop_wait(mainloop);
    pulse.pa_threaded_mainloop_unlock(mainloop);

    if (!list_data.ok)
        return error.@"Failed to list PulseAudio sink inputs";
}
