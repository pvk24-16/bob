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

    window_handle: *glfw.GLFWwindow = undefined,

    /// Create renderer.
    pub fn init() !Renderer {
        const window_width: u32 = 800;
        const window_height: u32 = 600;
        const window_title = "project_name";

        if (glfw.glfwInit() == glfw.GLFW_FALSE) return Error.failed_to_init_glfw;

        const window = glfw.glfwCreateWindow(
            window_width,
            window_height,
            @ptrCast(&window_title),
            null,
            null,
        ) orelse return Error.failed_to_create_window;
        glfw.glfwMakeContextCurrent(window);

        if (gl.gladLoadGLLoader(@ptrCast(&glfw.glfwGetProcAddress)) == 0) return Error.failed_to_init_gl;
        gl.glViewport(0, 0, window_width, window_height);

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
