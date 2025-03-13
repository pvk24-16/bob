const std = @import("std");
const c = @cImport({
    @cInclude("bob.h");
});

pub const Spec = enum { mono, stereo };

pub const Flag = std.EnumArray(Spec, bool);

time: Flag,
frequency: Flag,
chromagram: Flag,
pulse: Flag,
tempo: Flag,

pub fn empty() @This() {
    return .{
        .time = Flag.initFill(false),
        .frequency = Flag.initFill(false),
        .chromagram = Flag.initFill(false),
        .pulse = Flag.initFill(false),
        .tempo = Flag.initFill(false),
    };
}

pub fn set(self: *@This(), client_flags: c_int) void {
    self.time.set(.mono, client_flags & c.BOB_AUDIO_TIME_DOMAIN_MONO != 0);
    self.time.set(.stereo, client_flags & c.BOB_AUDIO_TIME_DOMAIN_STEREO != 0);
    self.frequency.set(.mono, client_flags & c.BOB_AUDIO_FREQUENCY_DOMAIN_MONO != 0);
    self.frequency.set(.stereo, client_flags & c.BOB_AUDIO_FREQUENCY_DOMAIN_STEREO != 0);
    self.chromagram.set(.mono, client_flags & c.BOB_AUDIO_CHROMAGRAM_MONO != 0);
    self.chromagram.set(.stereo, client_flags & c.BOB_AUDIO_CHROMAGRAM_STEREO != 0);
    self.pulse.set(.mono, client_flags & c.BOB_AUDIO_PULSE_MONO != 0);
    self.pulse.set(.stereo, client_flags & c.BOB_AUDIO_PULSE_STEREO != 0);
    self.tempo.set(.mono, client_flags & c.BOB_AUDIO_TEMPO_MONO != 0);
    self.tempo.set(.stereo, client_flags & c.BOB_AUDIO_TEMPO_STEREO != 0);
}

pub fn log(self: *const @This()) void {
    std.log.info("client audio flags:", .{});
    inline for (std.meta.fields(@This())) |field| {
        const flags = &@field(self, field.name);
        for (std.enums.values(Spec)) |spec| {
            if (flags.get(spec)) {
                std.log.info("  {s} ({s})", .{ field.name, @tagName(spec) });
            }
        }
    }
}
