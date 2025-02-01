const std = @import("std");
const g = @import("graphics.zig");

pub fn createTexture(path: [:0]const u8) !u32 {
    var width: c_int = 0;
    var height: c_int = 0;
    var channels: c_int = 0;
    const pixel_data = g.stb_image.stbi_load(
        @ptrCast(@alignCast(path)),
        &width,
        &height,
        &channels,
        0,
    );
    var texture: u32 = 0;

    g.gl.glGenTextures(1, &texture);
    g.gl.glBindTexture(g.gl.GL_TEXTURE_2D, texture);
    g.gl.glTexParameteri(g.gl.GL_TEXTURE_2D, g.gl.GL_TEXTURE_MIN_FILTER, g.gl.GL_LINEAR);
    g.gl.glTexParameteri(g.gl.GL_TEXTURE_2D, g.gl.GL_TEXTURE_MAG_FILTER, g.gl.GL_LINEAR);
    g.gl.glTexParameteri(g.gl.GL_TEXTURE_2D, g.gl.GL_TEXTURE_WRAP_S, g.gl.GL_CLAMP_TO_EDGE);
    g.gl.glTexParameteri(g.gl.GL_TEXTURE_2D, g.gl.GL_TEXTURE_WRAP_T, g.gl.GL_CLAMP_TO_EDGE);
    g.gl.glTexImage2D(g.gl.GL_TEXTURE_2D, 0, g.gl.GL_RGBA, width, height, 0, g.gl.GL_RGBA, g.gl.GL_UNSIGNED_BYTE, @ptrCast(pixel_data));

    return texture;
}
