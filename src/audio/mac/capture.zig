const std = @import("std");
const Config = @import("../Config.zig");
const RingBuffer = @import("../buffer.zig").RingBuffer;
const coreaudio = @import("coreaudio.zig");

pub const MacOSImpl = struct {
    const c = coreaudio.c;
    const cf_string_to_charptr = coreaudio.cf_string_to_charptr;
    const log = coreaudio.log;

    const Error = error{
        out_of_memory,
        get_devices,
        start_audio_unit,
        stream_configuration,
        audio_component,
        new_instance,
        initialize,
        enable_io,
        assign_current_device,
        /// The format for audio capture (sample rate, data type,
        /// bit size, etc.) was not accepted.
        format,
        set_callback,
        convert_string,
        stop_audio_unit,
    };

    const OUTPUT_ELEMENT: c.AudioUnitElement = 0;
    const INPUT_ELEMENT: c.AudioUnitElement = 1;

    const SAMPLE_RATE = 44100;

    const UserData = struct {
        instance: *c.AudioComponentInstance,
        buffer_list: *c.AudioBufferList,
        ring_buffer: RingBuffer,
        mutex: std.Thread.Mutex,
        device_id: c.UInt32,
    };
    data: *UserData,

    pub fn init(config: Config, allocator: std.mem.Allocator) !MacOSImpl {
        var err: c.OSStatus = undefined;
        var prop_address: c.AudioObjectPropertyAddress = undefined;
        var io_size: c.UInt32 = undefined;

        const config_device_id: ?c.AudioDeviceID = std.fmt.parseInt(c.AudioDeviceID, config.process_id, 10) catch null;
        var device_id: c.AudioDeviceID = undefined;
        if (config_device_id) |id| {
            device_id = id;
        } else {
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
            device_id = default_input_id;
        }

        prop_address = c.AudioObjectPropertyAddress{
            .mSelector = c.kAudioDevicePropertyStreamConfiguration,
            .mScope = c.kAudioObjectPropertyScopeInput,
            .mElement = c.kAudioObjectPropertyElementMain,
        };
        err = c.AudioObjectGetPropertyDataSize(device_id, &prop_address, 0, null, &io_size);
        if (err != 0) {
            log.err("Failed to get size of stream configuration.", .{});
            return Error.stream_configuration;
        }
        const buffer_list: *c.AudioBufferList = @ptrCast(allocator.allocWithOptions(u8, io_size, 8, null) catch {
            log.err("Failed to allocate buffer list.", .{});
            return Error.out_of_memory;
        });

        err = c.AudioObjectGetPropertyData(device_id, &prop_address, 0, null, &io_size, @ptrCast(buffer_list));
        if (err != 0) {
            log.err("Failed to... honestly I don't know. Something failed.", .{});
            return Error.stream_configuration;
        }

        const desc = c.AudioComponentDescription{
            .componentType = c.kAudioUnitType_Output,
            .componentSubType = c.kAudioUnitSubType_HALOutput,
            .componentManufacturer = c.kAudioUnitManufacturer_Apple,
            .componentFlags = 0,
            .componentFlagsMask = 0,
        };

        const comp = c.AudioComponentFindNext(null, &desc) orelse {
            log.err("Failed to get audio component.", .{});
            return Error.audio_component;
        };

        const instance_ptr: *c.AudioComponentInstance = allocator.create(c.AudioComponentInstance) catch {
            log.err("Failed to allocate AudioUnit.", .{});
            return Error.out_of_memory;
        };

        err = c.AudioComponentInstanceNew(comp, @ptrCast(instance_ptr));
        if (err != 0) {
            log.err("Failed to create new instance.", .{});
            return Error.new_instance;
        }
        const instance = instance_ptr.*;

        err = c.AudioUnitInitialize(instance);
        if (err != 0) {
            log.err("Failed to initialize. OSStatus = {}", .{err});
            return Error.initialize;
        }

        var enable_io: c.UInt32 = 1;
        err = c.AudioUnitSetProperty(instance, c.kAudioOutputUnitProperty_EnableIO, c.kAudioUnitScope_Input, INPUT_ELEMENT, &enable_io, @sizeOf(c.UInt32));
        if (err != 0) {
            log.err("Failed to enable input IO", .{});
            return Error.enable_io;
        }

        enable_io = 0;
        err = c.AudioUnitSetProperty(instance, c.kAudioOutputUnitProperty_EnableIO, c.kAudioUnitScope_Output, OUTPUT_ELEMENT, &enable_io, @sizeOf(c.UInt32));
        if (err != 0) {
            log.err("Failed to disable output IO", .{});
            return Error.enable_io;
        }

        err = c.AudioUnitSetProperty(instance, c.kAudioOutputUnitProperty_CurrentDevice, c.kAudioUnitScope_Output, INPUT_ELEMENT, &device_id, @sizeOf(c.AudioDeviceID));
        if (err != 0) {
            log.err("Failed to assign current device.", .{});
            return Error.assign_current_device;
        }

        var default_format: c.AudioStreamBasicDescription = undefined;
        io_size = @sizeOf(c.AudioStreamBasicDescription);
        err = c.AudioUnitGetProperty(instance, c.kAudioUnitProperty_StreamFormat, c.kAudioUnitScope_Output, INPUT_ELEMENT, @ptrCast(&default_format), &io_size);
        if (err != 0) {
            log.err("Failed to get default format. OSStatus: {}\n", .{err});
            return Error.format;
        }

        log.info("Default format:", .{});
        log.info("Sample rate: {}", .{default_format.mSampleRate});
        log.info("Format ID: {}", .{default_format.mFormatID});
        log.info("Format Flags: {}", .{default_format.mFormatFlags});
        log.info("Bytes per packet: {}", .{default_format.mBytesPerPacket});
        log.info("Bytes per frame: {}", .{default_format.mBytesPerFrame});
        log.info("Channels per frame: {}", .{default_format.mChannelsPerFrame});
        log.info("Bits per channel: {}", .{default_format.mBitsPerChannel});
        log.info("", .{});

        const format = c.AudioStreamBasicDescription{
            .mSampleRate = SAMPLE_RATE,
            .mFormatID = c.kAudioFormatLinearPCM,
            .mFormatFlags = c.kAudioFormatFlagIsFloat,
            .mBytesPerPacket = @sizeOf(f32) * 2,
            .mFramesPerPacket = 1,
            .mBytesPerFrame = @sizeOf(f32) * 2,
            .mChannelsPerFrame = 2,
            .mBitsPerChannel = 32,
            .mReserved = 0,
        };

        err = c.AudioUnitSetProperty(instance, c.kAudioUnitProperty_StreamFormat, c.kAudioUnitScope_Output, INPUT_ELEMENT, &format, @sizeOf(c.AudioStreamBasicDescription));
        if (err != 0) {
            log.err("Failed to set format. OSStatus: {}\n", .{err});
            return Error.format;
        }

        const ring_buffer = try RingBuffer.init(Config.windowSize() / @sizeOf(f32), allocator);

        const userdata_ptr: *UserData = allocator.create(UserData) catch {
            log.err("Unable to allocate MacOSImpl", .{});
            return Error.out_of_memory;
        };
        userdata_ptr.* = UserData{
            .instance = instance_ptr,
            .buffer_list = buffer_list,
            .ring_buffer = ring_buffer,
            .mutex = .{},
            .device_id = device_id,
        };
        const input_callback = c.AURenderCallbackStruct{
            .inputProc = read_callback_ca,
            .inputProcRefCon = @ptrCast(userdata_ptr),
        };

        err = c.AudioUnitSetProperty(instance, c.kAudioOutputUnitProperty_SetInputCallback, c.kAudioUnitScope_Output, INPUT_ELEMENT, &input_callback, @sizeOf(c.AURenderCallbackStruct));
        if (err != 0) {
            log.err("Failed to set input callback.", .{});
            return Error.set_callback;
        }

        prop_address = c.AudioObjectPropertyAddress{
            .mSelector = c.kAudioDeviceProcessorOverload,
            .mScope = c.kAudioObjectPropertyScopeGlobal,
            .mElement = INPUT_ELEMENT,
        };

        err = c.AudioObjectAddPropertyListener(device_id, &prop_address, on_instream_device_overload, null);
        if (err != 0) {
            log.err("Failed to assign overload listener.", .{});
            return Error.set_callback;
        }

        return MacOSImpl{ .data = userdata_ptr };
    }

    pub fn deinit(self: *MacOSImpl, allocator: std.mem.Allocator) void {
        var err: c.OSStatus = undefined;
        var prop_address: c.AudioObjectPropertyAddress = undefined;
        prop_address = c.AudioObjectPropertyAddress{
            .mSelector = c.kAudioDeviceProcessorOverload,
            .mScope = c.kAudioObjectPropertyScopeGlobal,
            .mElement = INPUT_ELEMENT,
        };
        err = c.AudioObjectRemovePropertyListener(self.data.device_id, &prop_address, on_instream_device_overload, null);
        if (err != 0) {
            log.debug("Failed to remove property listener when deinit-ing audio capture. OSStatus = {}", .{err});
        }
        self.data.ring_buffer.deinit(allocator);
        allocator.free(self.data.buffer_list[0..1]);
        allocator.free(self.data.instance[0..1]);
        allocator.free(self.data[0..1]);
    }

    pub fn start(self: *MacOSImpl) !void {
        const err = c.AudioOutputUnitStart(self.data.instance.*);
        if (err != 0) {
            log.err("Failed to start audio unit. OSStatus = {}", .{err});
            return Error.start_audio_unit;
        }
    }

    pub fn stop(self: *MacOSImpl) !void {
        const err = c.AudioOutputUnitStop(self.data.instance.*);
        if (err != 0) {
            log.err("Failed to stop audio unit. OSStatus = {}", .{err});
            return Error.stop_audio_unit;
        }
        log.info("Stopping...", .{});
    }

    pub fn sample(self: *MacOSImpl) []const f32 {
        self.data.mutex.lock();
        defer self.data.mutex.unlock();
        return self.data.ring_buffer.receive();
    }

    fn read_callback_ca(userdata0: ?*anyopaque, io_action_flags: [*c]c.AudioUnitRenderActionFlags, in_time_stamp: [*c]const c.AudioTimeStamp, in_bus_number: c.UInt32, in_number_frames: c.UInt32, io_data: [*c]c.AudioBufferList) callconv(.C) c.OSStatus {
        _ = io_data;
        const userdata: *UserData = @ptrCast(@alignCast(userdata0));

        const err = c.AudioUnitRender(userdata.instance.*, io_action_flags, in_time_stamp, in_bus_number, in_number_frames, @ptrCast(userdata.buffer_list));
        if (err != 0) {
            log.err("Failed to render, OSStatus = {}", .{err});
            return c.noErr;
        }

        for (0..userdata.buffer_list.mNumberBuffers) |i| {
            const buf = userdata.buffer_list.mBuffers[i];
            const data: [*]f32 = @ptrCast(@alignCast(buf.mData));
            const length = buf.mDataByteSize / @sizeOf(f32);
            userdata.mutex.lock();
            userdata.ring_buffer.send(data[0..length]);
            userdata.mutex.unlock();
            // log.info("Got data with length = {}", .{length});
            // std.debug.print("Buffer %d has %zu floats with %d channels.\n", i, length, buf.mNumberChannels);
            // for (0..length) |j| {
            //     std.debug.print("%.2f ", data[j]);
            // }
            // std.debug.print("\n\n");
        }

        return c.noErr;
    }

    fn on_instream_device_overload(in_object_id: c.AudioObjectID, in_number_addresses: c.UInt32, in_addresses: [*c]const c.AudioObjectPropertyAddress, in_client_data: ?*anyopaque) callconv(.C) c.OSStatus {
        _ = .{ in_object_id, in_number_addresses, in_addresses, in_client_data };
        log.warn("Overload.", .{});
        return c.noErr;
    }
};
