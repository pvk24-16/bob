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

    const api = pulse.pa_threaded_mainloop_get_api(mainloop);
    const context = pulse.pa_context_new(api, "bob-list-clients-context") orelse {
        return error.@"Failed to create context";
    };

    if (pulse.pa_context_connect(context, null, pulse.PA_CONTEXT_NOAUTOSPAWN, null) < 0) {
        return error.@"Failed to connect to PulseAudio server";
    }
    defer {
        pulse.pa_threaded_mainloop_lock(mainloop);
        pulse.pa_context_disconnect(context);
        pulse.pa_threaded_mainloop_unlock(mainloop);
        pulse.pa_threaded_mainloop_wait(mainloop);
    }

    const Data = struct {
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
            const process_id = std.mem.span(value);

            key = pulse.PA_PROP_APPLICATION_NAME;
            value = pulse.pa_proplist_gets(info.?.proplist, key);
            const name = std.mem.span(value);

            var entry: AudioProducerEntry = undefined;

            @memcpy(entry.name[0..name.len], name);
            @memcpy(entry.process_id[0..process_id.len], process_id);

            entry.name[name.len] = 0;
            entry.process_id[process_id.len] = 0;

            data_ptr.list.append(entry) catch {
                data_ptr.ok = false;
            };
        }
    };

    var data: Data = .{ .list = list, .mainloop = mainloop };

    pulse.pa_threaded_mainloop_lock(mainloop);
    _ = pulse.pa_context_get_sink_input_info_list(context, Data.callback, @ptrCast(&data));
    pulse.pa_threaded_mainloop_unlock(mainloop);
    pulse.pa_threaded_mainloop_wait(mainloop);

    if (!data.ok)
        return error.@"Failed to list PulseAudio sink inputs";
}
