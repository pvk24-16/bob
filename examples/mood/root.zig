const std = @import("std");
const c = @import("c.zig");

const Info = c.bob.bob_visualization_info;
const Bob = c.bob.bob_api;

export var api: Bob = undefined;

var info = Info{
    .name = "mood",
    .description = "Mood color mapping.",
    .enabled = c.bob.BOB_AUDIO_MOOD_MONO,
};

export fn get_info() [*c]const Info {
    return &info;
}

export fn create() [*c]const u8 {
    if (c.glad.gladLoadGLLoader(api.get_proc_address) == 0) {
        @panic("could not load gl loader");
    }

    return null;
}

const scale = 0.9;
var r: f32 = 0.0;
var g: f32 = 0.0;
var b: f32 = 0.0;

export fn update() void {
    const mood: c_int = api.get_mood.?(api.context, c.bob.BOB_MONO_CHANNEL);

    switch (mood) {
        c.bob.BOB_HAPPY => {
            r = scale * r + (1.0 - scale) * 0.71;
            g = scale * g + (1.0 - scale) * 0.62;
            b = scale * b + (1.0 - scale) * 0.00;
        },
        c.bob.BOB_EXUBERANT => {
            r = scale * r + (1.0 - scale) * 0.80;
            g = scale * g + (1.0 - scale) * 0.40;
            b = scale * b + (1.0 - scale) * 0.10;
        },
        c.bob.BOB_ENERGETIC => {
            r = scale * r + (1.0 - scale) * 0.70;
            g = scale * g + (1.0 - scale) * 0.10;
            b = scale * b + (1.0 - scale) * 0.10;
        },
        c.bob.BOB_FRANTIC => {
            r = scale * r + (1.0 - scale) * 0.60;
            g = scale * g + (1.0 - scale) * 0.10;
            b = scale * b + (1.0 - scale) * 0.40;
        },
        c.bob.BOB_ANXIOUS => {
            r = scale * r + (1.0 - scale) * 0.10;
            g = scale * g + (1.0 - scale) * 0.10;
            b = scale * b + (1.0 - scale) * 0.50;
        },
        c.bob.BOB_DEPRESSION => {
            r = scale * r + (1.0 - scale) * 0.10;
            g = scale * g + (1.0 - scale) * 0.10;
            b = scale * b + (1.0 - scale) * 0.30;
        },
        c.bob.BOB_CALM => {
            r = scale * r + (1.0 - scale) * 0.10;
            g = scale * g + (1.0 - scale) * 0.50;
            b = scale * b + (1.0 - scale) * 0.20;
        },
        c.bob.BOB_CONTENTMENT => {
            r = scale * r + (1.0 - scale) * 0.30;
            g = scale * g + (1.0 - scale) * 0.30;
            b = scale * b + (1.0 - scale) * 0.30;
        },
        else => unreachable,
    }

    c.glad.glClearColor(r, g, b, 1);
    c.glad.glClear(c.glad.GL_COLOR_BUFFER_BIT);
}

export fn destroy() void {}

// Verify that type signatures are correct
comptime {
    for (&.{ "api", "get_info", "create", "update", "destroy" }) |name| {
        const A = @TypeOf(@field(c.bob, name));
        const B = @TypeOf(@field(@This(), name));
        if (A != B) {
            @compileError("Type mismatch for '" ++ name ++ "': "
            //
            ++ @typeName(A) ++ " and " ++ @typeName(B));
        }
    }
}
