const std = @import("std");
const bob = @import("bob_api.zig");

pub const Flags = struct {
    time_mono: bool = false,
    time_stereo: bool = false,
    frequency_mono: bool = false,
    frequency_stereo: bool = false,
    chromagram_mono: bool = false,
    chromagram_stereo: bool = false,
    pulse_mono: bool = false,
    pulse_stereo: bool = false,
    tempo_mono: bool = false,
    tempo_stereo: bool = false,
    breaks_mono: bool = false,
    breaks_stereo: bool = false,
    key_mono: bool = false,
    key_stereo: bool = false,
    mood_mono: bool = false,
    mood_stereo: bool = false,

    pub fn init(flags: c_int) Flags {
        return Flags{
            .time_mono = flags & bob.BOB_AUDIO_TIME_DOMAIN_MONO != 0,
            .time_stereo = flags & bob.BOB_AUDIO_TIME_DOMAIN_STEREO != 0,
            .frequency_mono = flags & bob.BOB_AUDIO_FREQUENCY_DOMAIN_MONO != 0,
            .frequency_stereo = flags & bob.BOB_AUDIO_FREQUENCY_DOMAIN_STEREO != 0,
            .chromagram_mono = flags & bob.BOB_AUDIO_CHROMAGRAM_MONO != 0 or flags & bob.BOB_AUDIO_KEY_MONO != 0,
            .chromagram_stereo = flags & bob.BOB_AUDIO_CHROMAGRAM_STEREO != 0 or flags & bob.BOB_AUDIO_KEY_STEREO != 0,
            .pulse_mono = flags & bob.BOB_AUDIO_PULSE_MONO != 0,
            .pulse_stereo = flags & bob.BOB_AUDIO_PULSE_STEREO != 0,
            .tempo_mono = flags & bob.BOB_AUDIO_TEMPO_MONO != 0,
            .tempo_stereo = flags & bob.BOB_AUDIO_TEMPO_STEREO != 0,
            .breaks_mono = flags & bob.BOB_AUDIO_BREAKS_MONO != 0,
            .breaks_stereo = flags & bob.BOB_AUDIO_BREAKS_STEREO != 0,
            .key_mono = flags & bob.BOB_AUDIO_KEY_MONO != 0,
            .key_stereo = flags & bob.BOB_AUDIO_KEY_STEREO != 0,
            .mood_mono = flags & bob.BOB_AUDIO_MOOD_MONO != 0,
            .mood_stereo = flags & bob.BOB_AUDIO_MOOD_STEREO != 0,
        };
    }

    pub fn log(self: Flags) void {
        std.log.info("visualizer audio flags:", .{});
        inline for (std.meta.fields(Flags)) |field| {
            const flag: bool = @field(self, field.name);
            if (flag) {
                std.log.info(" * {s}", .{field.name});
            }
        }
    }
};
