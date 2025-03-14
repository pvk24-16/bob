const os_tag = @import("builtin").os.tag;
pub const AudioProducerEntry = @import("./AudioProducerEntry.zig");

fn scannerNotImplementedForPlatform(_: *AudioProducerEntry.List) void {
    // TODO: Maybe we should log this somehow?
}

pub const scan = switch(os_tag) {
    .windows => @import("./windows.zig").scanForAudioProducers,
    else => scannerNotImplementedForPlatform,
};
