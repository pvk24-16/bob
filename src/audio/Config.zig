const Config = @This();

const Channels = enum { mono, stereo };
const SampleRate = enum {};

process_id: []const u8 = undefined,
sample_rate: u32 = 44100, // kHz
channel_count: u32 = 2,
window_time: u32 = 10, // ms

pub fn bitDepth(_: Config) u32 {
    return @bitSizeOf(f32);
}

pub fn bitRate(self: Config) u32 {
    return self.sample_rate * self.channel_count * @bitSizeOf(f32);
}

pub fn windowSize(self: Config) u32 {
    var window_size: u32 = self.sample_rate * self.window_time * self.channel_count * @sizeOf(f32) / 1000;

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
