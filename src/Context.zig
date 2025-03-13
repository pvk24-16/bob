//! Holds all data used in API calls
//! TODO: add all the stuff
const std = @import("std");
const Context = @This();

const GuiState = @import("GuiState.zig");
const Client = @import("Client.zig");
const AudioCapturer = @import("audio/AudioCapturer.zig");
const FFT = @import("audio/fft.zig").FastFourierTransform;
const Error = @import("Error.zig");
const AudioSplixer = @import("audio/AudioSplixer.zig");
const AudioConfig = @import("audio/Config.zig");
const Flags = @import("Flags.zig");

err: Error,
gui_state: GuiState,
client: ?Client,
capturer: ?AudioCapturer,
splixer: ?AudioSplixer,
fft: ?FFT,
flags: Flags,

pub fn init(allocator: std.mem.Allocator) Context {
    return .{
        .err = Error{},
        .gui_state = GuiState.init(allocator),
        .client = null,
        .capturer = null,
        .splixer = null,
        .fft = null,
        .flags = Flags.empty(),
    };
}

pub fn connect(self: *Context, process_id: []const u8, allocator: std.mem.Allocator) !void {
    const config: AudioConfig = .{ .process_id = process_id };
    self.capturer = try AudioCapturer.init(config, allocator);
    self.splixer = try AudioSplixer.init(config.windowSize(), allocator);
    self.fft = try FFT.init(std.math.log2_int(usize, 4096), 2, .blackman_nuttall, 0.5, allocator);
    try self.capturer.?.start();
}

pub fn disconnect(self: *Context, allocator: std.mem.Allocator) !void {
    try self.capturer.?.stop();
    self.capturer.?.deinit(allocator);
    self.capturer = null;
    self.splixer.?.deinit(allocator);
    self.splixer = null;
    self.fft.?.deinit(allocator);
    self.fft = null;
}

pub fn processAudio(self: *Context) void {
    if (self.capturer) |*capturer| {
        self.splixer.?.mix(capturer.sample());
        self.fft.?.write(self.splixer.?.getCenter());
    }
    // TODO: chroma etc...
}

pub fn deinit(self: *Context, allocator: std.mem.Allocator) void {
    self.gui_state.deinit();
    if (self.client) |*client|
        client.unload();
    if (self.capturer) |*capturer|
        capturer.deinit(allocator);
    if (self.splixer) |*splixer|
        splixer.deinit(allocator);
    self.err.clear(allocator);
}
