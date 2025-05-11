const std = @import("std");
const Key = @This();
const bob = @import("../bob_api.zig");

const KeyType = enum(c_int) {
    major = bob.BOB_KEY_MAJOR,
    minor = bob.BOB_KEY_MINOR,
};

const profiles = std.enums.EnumArray(KeyType, []const usize).init(.{
    .major = &.{ 0, 4, 7 },
    .minor = &.{ 0, 3, 7 },
});

const Result = struct {
    pitch_class: usize,
    key_type: usize,
    confidence: f32,
};

result: Result = undefined,

pub fn classify(self: *Key, chromagram: []const f32) void {
    self.result = Result{
        .pitch_class = 0,
        .key_type = 0,
        .confidence = 0.0,
    };

    var chroma_sum: f32 = 0.0;
    for (chromagram) |chroma| {
        chroma_sum += chroma;
    }

    for (0..12) |pitch_class| {
        for (profiles.values, 0..) |profile, key_type| {
            var dot = chroma_sum;
            for (profile) |offset| {
                const index = (offset + pitch_class) % 12;
                dot -= chromagram[index];
            }

            const confidence = 12.0 - dot;
            if (confidence > self.result.confidence) {
                self.result.confidence = confidence;
                self.result.pitch_class = pitch_class;
                self.result.key_type = key_type;
            }
        }
    }
}
