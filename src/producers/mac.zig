const AudioProducerEntry = @import("./AudioProducerEntry.zig");
const std = @import("std");
const coreaudio = @import("../audio/mac/coreaudio.zig");
const c = coreaudio.c;
const cf_string_to_charptr = coreaudio.cf_string_to_charptr;
const log = coreaudio.log;

const Error = error{
    out_of_memory,
    get_devices,
    convert_string,
};

pub fn getAudioInputs(list: *AudioProducerEntry.List) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var err: c.OSStatus = undefined;
    var prop_address: c.AudioObjectPropertyAddress = undefined;
    var io_size: c.UInt32 = undefined;

    prop_address = c.AudioObjectPropertyAddress{
        .mSelector = c.kAudioHardwarePropertyDevices,
        .mScope = c.kAudioObjectPropertyScopeInput,
        .mElement = c.kAudioObjectPropertyElementMain,
    };
    err = c.AudioObjectGetPropertyDataSize(c.kAudioObjectSystemObject, &prop_address, 0, null, &io_size);
    if (err != 0) {
        log.err("Failed to get size of devices list.", .{});
        return Error.get_devices;
    }

    const device_count = io_size / @sizeOf(c.AudioObjectID);
    const devices = gpa.allocator().alloc(c.AudioObjectID, device_count) catch {
        log.err("Failed to allocate devices list.", .{});
        return Error.out_of_memory;
    };
    defer gpa.allocator().free(devices);

    err = c.AudioObjectGetPropertyData(c.kAudioObjectSystemObject, &prop_address, 0, null, &io_size, @ptrCast(devices));
    if (err != 0) {
        log.err("Failed to get devices list.", .{});
        return Error.get_devices;
    }

    prop_address = c.AudioObjectPropertyAddress{
        .mSelector = c.kAudioHardwarePropertyDefaultInputDevice,
        .mScope = c.kAudioObjectPropertyScopeInput,
        .mElement = c.kAudioObjectPropertyElementMain,
    };
    io_size = @sizeOf(c.AudioObjectID);
    var default_input_id: c.AudioObjectID = undefined;
    err = c.AudioObjectGetPropertyData(c.kAudioObjectSystemObject, &prop_address, 0, null, &io_size, @ptrCast(&default_input_id));
    if (err != 0) {
        log.err("Failed to get default input device.", .{});
        return Error.get_devices;
    }

    for (0..device_count) |i| {
        const device_id = devices[i];
        prop_address = c.AudioObjectPropertyAddress{
            .mSelector = c.kAudioObjectPropertyName,
            .mScope = c.kAudioObjectPropertyScopeGlobal,
            .mElement = c.kAudioObjectPropertyElementMain,
        };
        io_size = @sizeOf(c.CFStringRef);
        var string_ref: c.CFStringRef = undefined;
        err = c.AudioObjectGetPropertyData(device_id, &prop_address, 0, null, &io_size, @ptrCast(&string_ref));
        if (err != 0) {
            log.err("Failed to get name of device.", .{});
            return Error.get_devices;
        }
        const name = cf_string_to_charptr(string_ref, gpa.allocator(), Error) catch |e| {
            log.err("Failed to convert name", .{});
            return e;
        };
        defer gpa.allocator().free(name);

        prop_address = c.AudioObjectPropertyAddress{ .mSelector = c.kAudioDevicePropertyDeviceUID, .mScope = c.kAudioObjectPropertyScopeGlobal, .mElement = c.kAudioObjectPropertyElementMain };
        err = c.AudioObjectGetPropertyData(device_id, &prop_address, 0, null, &io_size, @ptrCast(&string_ref));
        if (err != 0) {
            log.err("Failed to get UID of device.", .{});
            return Error.get_devices;
        }
        const uid = cf_string_to_charptr(string_ref, gpa.allocator(), Error) catch |e| {
            log.err("Failed to convert name", .{});
            return e;
        };
        defer gpa.allocator().free(uid);

        const defstr = if (device_id == default_input_id) "(default) " else "";
        log.info("Device {}\t name: {s}\t uid: {s}{s}", .{ device_id, name, uid, defstr });

        var entry: AudioProducerEntry = undefined;
        _ = std.fmt.bufPrint(&entry.name, "{s}{s}\x00", .{ defstr, name }) catch {};
        _ = std.fmt.bufPrint(&entry.process_id, "{d}\x00", .{device_id}) catch {};
        list.append(entry) catch {
            return Error.out_of_memory;
        };
    }
    log.info("", .{});
}

pub fn enumerateAudioProducers(list: *AudioProducerEntry.List) !void {
    getAudioInputs(list) catch {};
}
