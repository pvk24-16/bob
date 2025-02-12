const std = @import("std");
const Mood = @This();

const PitchClass = enum(usize) {
    C,
    @"C#/Db",
    D,
    @"D#/Eb",
    E,
    F,
    @"F#/Gb",
    G,
    @"G#/Ab",
    A,
    @"A#/Bb",
    B,
};

const Type = enum {
    major,
    minor,
    augmented,
    diminished,
    @"major 7",
    @"minor 7",
    @"dominant 7",
    @"sus 2",
    @"sus 4",
};

const Chord = struct {
    root: PitchClass,
    type_: Type,
    mask: [12]f32,
    confidence: f32 = undefined,

    pub fn print(self: *const Chord, writer: anytype) !void {
        try writer.print("{s} {s}", .{ @tagName(self.root), @tagName(self.type_) });
    }
};

chords: []Chord,
allocator: std.mem.Allocator,

fn getProfile(t: Type) []const usize {
    return switch (t) {
        .major => &.{ 0, 4, 7 },
        .minor => &.{ 0, 3, 7 },
        .augmented => &.{ 0, 4, 8 },
        .diminished => &.{ 0, 3, 6 },
        .@"major 7" => &.{ 0, 4, 7, 11 },
        .@"minor 7" => &.{ 0, 3, 5, 10 },
        .@"dominant 7" => &.{ 0, 4, 7, 10 },
        .@"sus 2" => &.{ 0, 2, 7 },
        .@"sus 4" => &.{ 0, 5, 7 },
    };
}

pub fn init(allocator: std.mem.Allocator) !Mood {
    var chords = std.ArrayList(Chord).init(allocator);

    for (std.enums.values(Type)) |type_| {
        const profile = getProfile(type_);
        for (std.enums.values(PitchClass)) |root| {
            const offset: usize = @intFromEnum(root);

            var chord: Chord = .{
                .root = root,
                .type_ = type_,
                .mask = undefined,
            };

            @memset(&chord.mask, 1.0);
            for (profile) |i| {
                chord.mask[(i + offset) % 12] = 0.0;
            }

            try chords.append(chord);
        }
    }

    return .{
        .chords = try chords.toOwnedSlice(),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Mood) void {
    self.allocator.free(self.chords);
}

pub fn classify(self: *Mood, chromagram: []const f32) ?*const Chord {
    // const threshold: f32 = 0.2;

    var min_idx: usize = 0;
    var min_ratio: f32 = std.math.floatMax(f32);

    for (self.chords, 0..) |chord, idx| {
        var dot: f32 = 0.0;
        var inv_dot: f32 = 0.0;
        var mask_sum: f32 = 0.0;

        for (chord.mask, chromagram) |m, c| {
            mask_sum += m;
            inv_dot += m * c;
            dot += (1.0 - m) * c;
        }

        dot /= (12.0 - mask_sum);
        inv_dot /= mask_sum;

        const ratio = inv_dot - dot;

        if (ratio < min_ratio) {
            min_idx = idx;
            min_ratio = ratio;
        }
    }

    // if (min_ratio > threshold)
    //     return null;

    self.chords[min_idx].confidence = min_ratio;
    return &self.chords[min_idx];
}
