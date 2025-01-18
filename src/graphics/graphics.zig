const std = @import("std");
const gl = @import("c.zig").gl;
const glfw = @import("c.zig").glfw;

pub const Renderer = struct {
    pub const Error = error{
        failed_to_init_glfw,
        failed_to_init_gl,
        failed_to_create_window,
    };

    pub const CallbackKind = enum {
        resize,
        keyboard,
        mouse,
    };

    const max_callbacks: usize = 8;
    const window_width: u32 = 800;
    const window_height: u32 = 600;
    const window_title = "project_name";

    window_handle: *glfw.GLFWwindow = undefined,

    /// Create renderer.
    pub fn init() !Renderer {
        if (glfw.glfwInit() == glfw.GLFW_FALSE) return Error.failed_to_init_glfw;
        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 4);
        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 6);
        glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_COMPAT_PROFILE);

        const window = glfw.glfwCreateWindow(
            window_width,
            window_height,
            window_title[0..],
            null,
            null,
        ) orelse return Error.failed_to_create_window;
        glfw.glfwMakeContextCurrent(window);

        if (gl.gladLoadGLLoader(@ptrCast(&glfw.glfwGetProcAddress)) == 0) return Error.failed_to_init_gl;
        gl.glViewport(0, 0, window_width, window_height);

        glfw.glfwSwapInterval(1);

        return Renderer{
            .window_handle = window,
        };
    }

    /// Destroy renderer.
    pub fn deinit(self: *Renderer) void {
        glfw.glfwDestroyWindow(self.window_handle);
        glfw.glfwTerminate();
    }

    /// Swap buffers and poll events. Returns false if window should close.
    pub fn update(self: *Renderer) bool {
        glfw.glfwSwapBuffers(self.window_handle);
        glfw.glfwPollEvents();
        return glfw.glfwWindowShouldClose(self.window_handle) == glfw.GLFW_FALSE;
    }
};
