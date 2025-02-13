const std = @import("std");

const RingBuffer = @import("buffer.zig").RingBuffer;
const Config = @import("../Config.zig");

const Allocator = std.mem.Allocator;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub const WindowsImpl = struct {
    const win = @cImport({
        @cDefine("WIN32_LEAN_AND_MEAN", {});
        @cInclude("mmdeviceapi.h");
        @cInclude("Audioclient.h");
    });

    const log = std.log.scoped(.wasapi);

    const Error = error{
        com_init,
        audio_interface_activation,
        audio_client_retrieval,
        audio_client_init,
        capture_client_retrieval,
        sample_ready_event_creation,
        sample_ready_event_registration,
        start_capture,
        stop_capture,
    };

    const process_loopback_path = std.unicode.utf8ToUtf16LeStringLiteral("VAD\\Process_Loopback");

    running: bool,
    audio_client: *win.IAudioClient,
    capture_client: *win.IAudioCaptureClient,
    sample_ready_event: *anyopaque,

    thread: ?std.Thread,
    mutex: std.Thread.Mutex,
    channel_count: u32,
    ring_buffer: RingBuffer,

    pub fn init(config: Config, allocator: std.mem.Allocator) !WindowsImpl {
        var result = win.CoInitializeEx(null, win.COINITBASE_MULTITHREADED);

        if (result != win.S_OK) {
            return Error.com_init;
        }

        log.info("COM initialized...", .{});

        var blob: ActivationParams = undefined;
        blob.activation_type = .process_loopback;
        blob.u.loopback_params.process_id = try std.fmt.parseInt(win.DWORD, config.process_id, 10);
        blob.u.loopback_params.mode = .include_target;

        var params: win.PROPVARIANT = .{};
        params.unnamed_0.unnamed_0.vt = win.VT_BLOB;
        params.unnamed_0.unnamed_0.unnamed_0.blob.cbSize = @sizeOf(ActivationParams);
        params.unnamed_0.unnamed_0.unnamed_0.blob.pBlobData = @ptrCast(@alignCast(&blob));

        var interface_vtable = win.IActivateAudioInterfaceCompletionHandlerVtbl{
            .QueryInterface = CompletionHandler.queryInterface,
            .AddRef = CompletionHandler.addRef,
            .Release = CompletionHandler.release,
            .ActivateCompleted = CompletionHandler.activateCompleted,
        };

        var handler = CompletionHandler{
            .interface = .{ .lpVtbl = &interface_vtable },
            .mutex = .{},
            .condition = .{},
            .done = false,
        };

        var operation: ?*win.IActivateAudioInterfaceAsyncOperation = null;

        result = win.ActivateAudioInterfaceAsync(
            process_loopback_path[0..],
            &IID_IAudioClient,
            @ptrCast(@alignCast(&params)),
            @ptrCast(@alignCast(&handler.interface)),
            @ptrCast(@alignCast(&operation)),
        );

        handler.mutex.lock();

        while (!handler.done) {
            handler.condition.wait(&handler.mutex);
        }

        handler.mutex.unlock();

        if (result != win.S_OK) {
            return Error.audio_interface_activation;
        }

        log.info("audio interface activated...", .{});

        const get_fn = operation.?.lpVtbl.*.GetActivateResult.?;
        const release_fn = operation.?.lpVtbl.*.Release.?;
        var result_get: win.HRESULT = undefined;
        var audio_client_nullable: ?*win.IAudioClient = null;

        result = get_fn(operation, &result_get, @ptrCast(&audio_client_nullable));
        _ = release_fn(operation);

        if (result_get != win.S_OK or result != win.S_OK) {
            return Error.audio_client_retrieval;
        }

        const audio_client = audio_client_nullable orelse unreachable;

        std.log.debug("audio client retrieved...", .{});

        const wave_format = win.WAVEFORMATEX{
            .wFormatTag = win.WAVE_FORMAT_IEEE_FLOAT,
            .nChannels = @intCast(config.channel_count),
            .nSamplesPerSec = @intCast(config.sample_rate),
            .wBitsPerSample = @bitSizeOf(f32),
            .nBlockAlign = @intCast(@sizeOf(f32) * config.channel_count),
            .nAvgBytesPerSec = @intCast(@sizeOf(f32) * config.sample_rate * config.channel_count),
        };

        const init_fn = audio_client.lpVtbl.*.Initialize.?;

        result = init_fn(
            audio_client,
            win.AUDCLNT_SHAREMODE_SHARED,
            win.AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                win.AUDCLNT_STREAMFLAGS_LOOPBACK |
                win.AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
                win.AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY,
            0,
            0,
            &wave_format,
            null,
        );

        if (result != win.S_OK) {
            return Error.audio_client_init;
        }

        log.info("audio client initialized...", .{});

        const get_service_fn = audio_client.lpVtbl.*.GetService.?;
        var capture_client_nullable: ?*win.IAudioCaptureClient = null;

        result = get_service_fn(
            @ptrCast(@alignCast(audio_client)),
            &IID_IAudioCaptureClient,
            @ptrCast(@alignCast(&capture_client_nullable)),
        );

        if (result != win.S_OK) {
            return Error.capture_client_retrieval;
        }

        const capture_client = capture_client_nullable orelse unreachable;

        log.info("capture client retrieved...", .{});

        const sample_ready_event: *anyopaque = win.CreateEventW(
            null,
            @intFromBool(false),
            @intFromBool(false),
            null,
        ) orelse return Error.sample_ready_event_creation;

        log.info("sample ready event created...", .{});

        const set_handle_fn = audio_client.lpVtbl.*.SetEventHandle.?;

        result = set_handle_fn(audio_client, sample_ready_event);

        if (result != win.S_OK) {
            return Error.sample_ready_event_registration;
        }

        log.info("sample ready event registered...", .{});

        var ring_buffer = try RingBuffer.init(config.windowSize() / @sizeOf(f32), allocator);
        errdefer ring_buffer.deinit(allocator);

        return WindowsImpl{
            .running = false,
            .audio_client = audio_client,
            .capture_client = capture_client,
            .sample_ready_event = sample_ready_event,
            .mutex = .{},
            .thread = undefined,
            .channel_count = config.channel_count,
            .ring_buffer = ring_buffer,
        };
    }

    pub fn deinit(self: *WindowsImpl, allocator: std.mem.Allocator) void {
        if (self.thread) |thread| {
            self.mutex.lock();
            self.running = false;
            self.mutex.unlock();
            thread.join();
        }

        const release_fn = self.audio_client.lpVtbl.*.Release.?;

        _ = release_fn(self.audio_client);
        self.ring_buffer.deinit(allocator);
        win.CoUninitialize();
        self.* = undefined;
    }

    pub fn start(self: *WindowsImpl) !void {
        if (self.thread) |_| {
            self.mutex.lock();
            self.running = true;
            self.mutex.unlock();
        } else {
            self.running = true;
            self.thread = try std.Thread.spawn(.{}, captureLoop, .{self});
        }

        const start_fn = self.audio_client.lpVtbl.*.Start.?;

        if (start_fn(self.audio_client) != win.S_OK) {
            return Error.start_capture;
        }
    }

    pub fn stop(self: *WindowsImpl) !void {
        if (self.thread) |_| {
            self.mutex.lock();
            self.running = false;
            self.mutex.unlock();
        }

        const stop_fn = self.audio_client.lpVtbl.*.Stop.?;

        if (stop_fn(self.audio_client) != win.S_OK) {
            return Error.stop_capture;
        }
    }

    pub fn sample(self: *WindowsImpl) []const f32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.ring_buffer.receive();
    }

    fn captureLoop(self: *WindowsImpl) void {
        const get_buffer_fn = self.capture_client.lpVtbl.*.GetBuffer orelse unreachable;
        const release_fn = self.capture_client.lpVtbl.*.ReleaseBuffer orelse unreachable;

        var p_data: [*]f32 = undefined;
        var frames: u32 = 0;
        var flags: u64 = 0;

        while (self.running) {
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

                const data_size = frames * self.channel_count;

                self.mutex.lock();
                self.ring_buffer.send(p_data[0..data_size]);
                self.mutex.unlock();
            }
        }
    }

    const CompletionHandler = struct {
        interface: win.IActivateAudioInterfaceCompletionHandler,
        mutex: std.Thread.Mutex,
        condition: std.Thread.Condition,
        done: bool,

        fn activateCompleted(interface: [*c]win.IActivateAudioInterfaceCompletionHandler, _: [*c]win.IActivateAudioInterfaceAsyncOperation) callconv(.C) win.HRESULT {
            var handler: *CompletionHandler = @as(?*CompletionHandler, @fieldParentPtr("interface", interface)).?;

            handler.mutex.lock();
            handler.done = true;
            handler.mutex.unlock();
            handler.condition.signal();

            return win.S_OK;
        }

        fn queryInterface(h: [*c]win.IActivateAudioInterfaceCompletionHandler, iid: [*c]const win.IID, ppv: [*c]?*anyopaque) callconv(.C) win.HRESULT {
            const guid: win.GUID = @bitCast(iid.*);

            if (std.meta.eql(IID_IAgileObejct, guid)) {
                ppv.* = @ptrCast(h);
                return win.S_OK;
            }

            return win.E_NOINTERFACE;
        }

        fn addRef(_: [*c]win.IActivateAudioInterfaceCompletionHandler) callconv(.C) win.ULONG {
            return 1;
        }

        fn release(_: [*c]win.IActivateAudioInterfaceCompletionHandler) callconv(.C) win.ULONG {
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

    const LoopbackParams = extern struct {
        process_id: win.DWORD,
        mode: LoopbackMode,
    };

    const ActivationParams = extern struct {
        activation_type: ActivationType,
        u: extern union {
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
};
