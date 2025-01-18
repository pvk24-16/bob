const c = @import("c.zig");
pub const gl = c.gl;
pub const glfw = c.glfw;

const window = @import("window.zig");
pub const Window = window.Window;
pub const WindowError = window.Error;
pub const CallbackKind = window.CallbackKind;

const shader = @import("shader.zig");
pub const Shader = shader.Shader;
