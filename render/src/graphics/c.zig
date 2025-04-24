pub const gl = @cImport({
    @cInclude("glad/glad.h");
});

pub const stb_image = @cImport({
    @cInclude("stb_image/stb_image.h");
});
