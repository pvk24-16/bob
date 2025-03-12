const Config = @This();

pub const channel_count = 2;
pub const sample_rate = 44100; // Hz

process_id: []const u8 = undefined,
window_time: u32 = 20, // ms

pub fn bitDepth() comptime_int {
    return @bitSizeOf(f32);
}

pub fn bitRate() comptime_int {
    return sample_rate * channel_count * @bitSizeOf(f32);
}

pub fn byteDepth() comptime_int {
    return @sizeOf(f32);
}

pub fn byteRate() comptime_int {
    return sample_rate * channel_count * @sizeOf(f32);
}

pub fn windowSize(self: Config) u32 {
    var window_size: u32 = self.window_time * byteRate() / 1000;

    // Round up to the nearest power of two.
    window_size -= 1;
    window_size |= window_size >> 1;
    window_size |= window_size >> 2;
    window_size |= window_size >> 4;
    window_size |= window_size >> 8;
    window_size |= window_size >> 16;
    window_size += 1;

    return window_size;
}
