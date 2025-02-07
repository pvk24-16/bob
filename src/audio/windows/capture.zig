const std = @import("std");
const win = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", {});
    @cInclude("mmdeviceapi.h");
    @cInclude("Audioclient.h");
});

const Allocator = std.mem.Allocator;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

// Requires Tiger-style initialization.
const CaptureBase = @import("../base.zig");

const WindowsCaptureImpl = @This();
const process_loopback_path = L("VAD\\Process_Loopback");

pub const Error = error{
    co_initialize_failed,
    out_of_date_windows,
    operation_was_null,
    get_audio_client,
    init_capture_client,
    get_capture_client,
    create_event,
    event_register,
};

audio_client: *win.IAudioClient = undefined,
capture_client: *win.IAudioCaptureClient = undefined,
wave_format: win.WAVEFORMATEX = undefined,
sample_ready_event: *anyopaque = undefined,
base: CaptureBase = undefined,

/// Create windows capture.
pub fn init(
    self: *WindowsCaptureImpl,
    process_str: []const u8,
    capacity: usize,
    allocator: Allocator,
) !void {
    const process_id = try std.fmt.parseInt(u32, process_str, 10);
    var result = win.CoInitializeEx(null, win.COINITBASE_MULTITHREADED);

    if (result != win.S_OK) return Error.co_initialize_failed;

    var blob: ActivationParams = undefined;
    blob.activation_type = .process_loopback;
    blob.u.loopback_params.process_id = process_id;
    blob.u.loopback_params.mode = .include_target;

    var params: win.PROPVARIANT = .{};
    params.unnamed_0.unnamed_0.vt = win.VT_BLOB;
    params.unnamed_0.unnamed_0.unnamed_0.blob.cbSize = @sizeOf(ActivationParams);
    params.unnamed_0.unnamed_0.unnamed_0.blob.pBlobData = @ptrCast(&blob);

    var interface_table: win.IActivateAudioInterfaceCompletionHandlerVtbl = .{};
    interface_table.ActivateCompleted = ActivationHandler.activateCompleted;
    interface_table.QueryInterface = ActivationHandler.queryInterface;
    interface_table.AddRef = ActivationHandler.addRef;
    interface_table.Release = ActivationHandler.release;

    var handler: ActivationHandler = undefined;
    handler.interface = .{ .lpVtbl = &interface_table };
    handler.mutex = .{};
    handler.condition = .{};
    handler.done = false;

    var operation: ?*win.IActivateAudioInterfaceAsyncOperation = null;

    result = win.ActivateAudioInterfaceAsync(
        process_loopback_path[0..],
        &IID_IAudioClient,
        @ptrCast(&params),
        @ptrCast(&handler.interface),
        @ptrCast(&operation),
    );

    {
        handler.mutex.lock();
        defer handler.mutex.unlock();
        while (!handler.done) {
            handler.condition.wait(&handler.mutex);
        }
    }

    if (result != win.S_OK) return Error.out_of_date_windows;
    const op = operation orelse return Error.operation_was_null;

    std.log.debug("[Windows Capture] Audio interface activation complete", .{});

    const get_fn = op.lpVtbl.*.GetActivateResult orelse unreachable;
    const release_fn = op.lpVtbl.*.Release orelse unreachable;
    var get_result: win.HRESULT = undefined;
    var audio_client: ?*win.IAudioClient = null;
    result = get_fn(op, &get_result, @ptrCast(&audio_client));
    _ = release_fn(op);
    if (get_result != win.S_OK or result != win.S_OK) return Error.get_audio_client;
    self.audio_client = audio_client orelse unreachable;

    std.log.debug("[Windows Capture] Retrieved audio client", .{});

    self.wave_format = .{};
    // TODO: Make this configurable.
    self.wave_format.wFormatTag = win.WAVE_FORMAT_IEEE_FLOAT;
    self.wave_format.nChannels = 2;
    self.wave_format.nSamplesPerSec = 44100;
    self.wave_format.wBitsPerSample = @bitSizeOf(f32);
    self.wave_format.nBlockAlign = @divFloor(self.wave_format.wBitsPerSample, 8) * self.wave_format.nChannels;
    self.wave_format.nAvgBytesPerSec = self.wave_format.nSamplesPerSec * self.wave_format.nBlockAlign;

    const init_fn = self.audio_client.lpVtbl.*.Initialize orelse unreachable;
    result = init_fn(
        self.audio_client,
        win.AUDCLNT_SHAREMODE_SHARED,
        win.AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
            win.AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
            win.AUDCLNT_STREAMFLAGS_LOOPBACK |
            win.AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY,
        0,
        0,
        &self.wave_format,
        null,
    );

    if (result != win.S_OK) return Error.init_capture_client;
    std.log.debug("[Windows Capture] Initialized capture client", .{});

    const get_service_fn = self.audio_client.lpVtbl.*.GetService orelse unreachable;
    var capture_client: ?*win.IAudioCaptureClient = null;
    result = get_service_fn(self.audio_client, &IID_IAudioCaptureClient, @ptrCast(&capture_client));
    if (result != win.S_OK) return Error.get_capture_client;
    self.capture_client = capture_client orelse unreachable;

    std.log.debug("[Windows Capture] Retrieved audio capture client", .{});

    self.sample_ready_event = win.CreateEventW(
        null,
        win.FALSE,
        win.FALSE,
        null,
    ) orelse return Error.create_event;

    const set_event_fn = self.audio_client.lpVtbl.*.SetEventHandle orelse unreachable;
    result = set_event_fn(self.audio_client, self.sample_ready_event);
    if (result != win.S_OK) return Error.event_register;

    std.log.debug("[Windows Capture] Created and set sample ready event", .{});

    self.base = try CaptureBase.init(capacity, allocator);

    std.log.debug("[Windows Capture] Created capture base", .{});
}

/// Destroy windows capture.
pub fn deinit(self: *WindowsCaptureImpl) void {
    self.base.mutex.lock();
    self.base.capture_running = false;
    self.base.mutex.unlock();
    if (self.base.thread) |*t| {
        t.join();
    }

    self.base.ring.deinit();
    const release_fn = self.audio_client.lpVtbl.*.Release orelse unreachable;
    _ = release_fn(self.audio_client);
    win.CoUninitialize();

    std.log.debug("[Windows Capture] Deinitialized", .{});
}

/// Audio capture loop.
fn captureLoop(self: *WindowsCaptureImpl) void {
    const get_buffer_fn = self.capture_client.lpVtbl.*.GetBuffer orelse unreachable;
    const release_fn = self.capture_client.lpVtbl.*.ReleaseBuffer orelse unreachable;

    var p_data: [*]f32 = undefined;
    var frames: u32 = 0;
    var flags: u64 = 0;

    while (self.base.capture_running) {
        if (win.WaitForSingleObject(self.sample_ready_event, 100) != win.WAIT_OBJECT_0) {
            continue;
        }

        while (get_buffer_fn(
            self.capture_client,
            @ptrCast(&p_data),
            @ptrCast(&frames),
            @ptrCast(&flags),
            null,
            null,
        ) == win.S_OK) {
            defer _ = release_fn(self.capture_client, frames);

            const data_size = frames * self.wave_format.nChannels;

            self.base.mutex.lock();
            self.base.ring.write(p_data[0..data_size]);
            self.base.mutex.unlock();
        }
    }
}

/// Start audio capture.
pub fn startCapture(self: *WindowsCaptureImpl) !void {
    if (self.base.thread) |_| {
        std.log.warn("[Windows Capture] Attemped to start while running", .{});
        return;
    }

    const start_fn = self.audio_client.lpVtbl.*.Start orelse unreachable;
    if (start_fn(self.audio_client) != win.S_OK) return CaptureBase.Error.start_capture;

    self.base.capture_running = true;
    self.base.thread = try std.Thread.spawn(.{}, captureLoop, .{self});
    std.log.debug("[Windows Capture] Started capture loop", .{});
}

/// Stop audio capture.
pub fn stopCapture(self: *WindowsCaptureImpl) !void {
    const stop_fn = self.audio_client.lpVtbl.*.Stop orelse unreachable;
    if (stop_fn(self.audio_client) != win.S_OK) return CaptureBase.Error.stop_capture;
}

/// Resume audio capture.
pub fn resumeCapture(_: *WindowsCaptureImpl) !void {
    @compileError("Not implemented");
}

/// Stop audio capture.
pub fn pauseCapture(_: *WindowsCaptureImpl) !void {
    @compileError("Not implemented");
}

/// Retrieve sample rate.
pub inline fn sampleRate(self: *WindowsCaptureImpl) u32 {
    return @intCast(self.wave_format.nSamplesPerSec);
}

const ActivationHandler = struct {
    interface: win.IActivateAudioInterfaceCompletionHandler,
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    done: bool,

    pub fn activateCompleted(
        interface: [*c]win.IActivateAudioInterfaceCompletionHandler,
        _: [*c]win.IActivateAudioInterfaceAsyncOperation,
    ) callconv(.C) win.HRESULT {
        var handler: *ActivationHandler = @as(
            ?*ActivationHandler,
            @fieldParentPtr("interface", interface),
        ) orelse unreachable;

        {
            handler.mutex.lock();
            defer handler.mutex.unlock();
            handler.done = true;
        }

        handler.condition.signal();
        std.log.debug("[Windows Capture] Activate handler completed", .{});
        return win.S_OK;
    }

    pub fn queryInterface(
        interface: [*c]win.IActivateAudioInterfaceCompletionHandler,
        iid: [*c]const win.IID,
        ppv: [*c]?*anyopaque,
    ) callconv(.C) win.HRESULT {
        const guid: win.GUID = @bitCast(iid.*);

        if (std.meta.eql(IID_IAgileObejct, guid)) {
            ppv.* = @ptrCast(interface);
            std.log.debug("[Windows Capture] Queried interface", .{});
            return win.S_OK;
        }

        return win.E_NOINTERFACE;
    }

    // These are useless, return default.

    pub fn addRef(_: [*c]win.IActivateAudioInterfaceCompletionHandler) callconv(.C) win.ULONG {
        return 1;
    }

    pub fn release(_: [*c]win.IActivateAudioInterfaceCompletionHandler) callconv(.C) win.ULONG {
        return 0;
    }
};

const ActivationType = enum(u32) {
    default = 0,
    process_loopback = 1,
};

const LoopbackMode = enum(u32) {
    include_target = 0,
    exclude_target = 1,
};

const LoopbackParams = struct {
    process_id: win.DWORD,
    mode: LoopbackMode,
};

const ActivationParams = struct {
    activation_type: ActivationType,
    u: union {
        loopback_params: LoopbackParams,
    },
};

const IID_IAgileObejct = win.GUID{
    .Data1 = 0x94EA2B94,
    .Data2 = 0xE9CC,
    .Data3 = 0x49E0,
    .Data4 = .{ 0xC0, 0xFF, 0xEE, 0x64, 0xCA, 0x8F, 0x5B, 0x90 },
};

const IID_IAudioClient = win.GUID{
    .Data1 = 0x1CB9AD4C,
    .Data2 = 0xDBFA,
    .Data3 = 0x4C32,
    .Data4 = .{ 0xB1, 0x78, 0xC2, 0xF5, 0x68, 0xA7, 0x03, 0xB2 },
};

const IID_IAudioCaptureClient = win.GUID{
    .Data1 = 0xC8ADBD64,
    .Data2 = 0xE71E,
    .Data3 = 0x48A0,
    .Data4 = .{ 0xA4, 0xDE, 0x18, 0x5C, 0x39, 0x5C, 0xD3, 0x17 },
};
