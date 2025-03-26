const os_tag = @import("builtin").os.tag;
pub const AudioProducerEntry = @import("./AudioProducerEntry.zig");

// TODO: Chrome source refers to this type of code as "window enumerator". Maybe that is a better name?

fn enumeratorNotImplementedForPlatform(_: *AudioProducerEntry.List) !void {
    // TODO: Maybe we should log this somehow?
}

pub const enumerate = switch (os_tag) {
    .windows => @import("./windows.zig").enumerateAudioProducers,
    .macos => @import("./mac.zig").enumerateAudioProducers,
    .linux => @import("./linux.zig").enumerateAudioProducers,
    else => enumeratorNotImplementedForPlatform,
};
