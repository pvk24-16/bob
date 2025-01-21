const std = @import("std");
const gl = @import("c.zig").gl;
const glfw = @import("c.zig").glfw;
const os_tag = @import("builtin").os.tag;

pub const Error = error{
    failed_to_init_glfw,
    failed_to_init_gl,
    failed_to_create_window,
    max_callbacks_exceeded,
};

pub const CallbackKind = enum {
    resize,
    keyboard,
    mouse,
    cursor,
};

fn errorCallback(err: c_int, msg: [*c]const u8) callconv(.C) void {
    std.debug.print("Error code: {} message: {s}\n", .{ err, msg });
}

pub fn Window(comptime max_callbacks: usize) type {
    return struct {
        const Self = @This();

        const window_width: u32 = 800;
        const window_height: u32 = 600;
        const window_title = "project_name";

        window_handle: *glfw.GLFWwindow = undefined,

        resize_callbacks: [max_callbacks]*const fn (i32, i32, ?*anyopaque) void = undefined,
        key_callbacks: [max_callbacks]*const fn (i32, i32, i32, i32, ?*anyopaque) void = undefined,
        mouse_callbacks: [max_callbacks]*const fn (i32, i32, i32, ?*anyopaque) void = undefined,
        cursor_callbacks: [max_callbacks]*const fn (f64, f64, ?*anyopaque) void = undefined,

        resize_userdata: [max_callbacks]?*anyopaque = undefined,
        key_userdata: [max_callbacks]?*anyopaque = undefined,
        mouse_userdata: [max_callbacks]?*anyopaque = undefined,
        cursor_userdata: [max_callbacks]?*anyopaque = undefined,

        resize_num: usize = 0,
        key_num: usize = 0,
        mouse_num: usize = 0,
        cursor_num: usize = 0,

        /// Create renderer.
        /// To use callbacks, call setUserPointer() after initializing.
        pub fn init() !Self {
            if (glfw.glfwInit() == glfw.GLFW_FALSE) return Error.failed_to_init_glfw;
            _ = glfw.glfwSetErrorCallback(errorCallback);
            glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
            glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
            glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_COMPAT_PROFILE);
            if (os_tag == .macos) {
                glfw.glfwWindowHint(glfw.GLFW_OPENGL_FORWARD_COMPAT, glfw.GLFW_TRUE);
            }

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

            return Self{ .window_handle = window };
        }

        /// Destroy renderer.
        pub fn deinit(self: *Self) void {
            glfw.glfwDestroyWindow(self.window_handle);
            glfw.glfwTerminate();
        }

        /// Set user pointer and callbacks.
        pub fn setUserPointer(self: *Self) void {
            glfw.glfwSetWindowUserPointer(self.window_handle, @ptrCast(self));
            _ = glfw.glfwSetFramebufferSizeCallback(self.window_handle, resizeCallback);
            _ = glfw.glfwSetKeyCallback(self.window_handle, keyboardCallback);
            _ = glfw.glfwSetMouseButtonCallback(self.window_handle, mouseCallback);
            _ = glfw.glfwSetCursorPosCallback(self.window_handle, cursorPositionCallback);
        }

        /// Swap buffers and poll events.
        pub fn update(self: *Self) void {
            glfw.glfwSwapBuffers(self.window_handle);
            glfw.glfwPollEvents();
        }

        /// Returns false if the window should close.
        pub fn running(self: *Self) bool {
            return glfw.glfwWindowShouldClose(self.window_handle) == glfw.GLFW_FALSE;
        }

        /// Assign function for callback.
        /// Returns an error if maximum number of callbacks is exceeded.
        pub fn pushCallback(self: *Self, pfn: anytype, userdata: ?*anyopaque, comptime kind: CallbackKind) !void {
            const T = @TypeOf(pfn);

            switch (kind) {
                .resize => {
                    const expected = @TypeOf(self.resize_callbacks[0]);
                    if (T != expected) {
                        @compileError("Expected " ++ @typeName(expected) ++ ", found: " ++ @typeName(T));
                    }

                    if (self.resize_num >= 8) return Error.max_callbacks_exceeded;
                    self.resize_callbacks[self.resize_num] = pfn;
                    self.resize_userdata[self.resize_num] = userdata;
                    self.resize_num += 1;
                },

                .keyboard => {
                    const expected = @TypeOf(self.key_callbacks[0]);
                    if (T != expected) {
                        @compileError("Expected " ++ @typeName(expected) ++ ", found: " ++ @typeName(T));
                    }

                    if (self.key_num >= 8) return Error.max_callbacks_exceeded;
                    self.key_callbacks[self.key_num] = pfn;
                    self.key_userdata[self.key_num] = userdata;
                    self.key_num += 1;
                },

                .mouse => {
                    const expected = @TypeOf(self.mouse_callbacks[0]);
                    if (T != expected) {
                        @compileError("Expected " ++ @typeName(expected) ++ ", found: " ++ @typeName(T));
                    }

                    if (self.mouse_num >= 8) return Error.max_callbacks_exceeded;
                    self.mouse_callbacks[self.mouse_num] = pfn;
                    self.mouse_userdata[self.mouse_num] = userdata;
                    self.mouse_num += 1;
                },

                .cursor => {
                    const expected = @TypeOf(self.cursor_callbacks[0]);
                    if (T != expected) {
                        @compileError("Expected " ++ @typeName(expected) ++ ", found: " ++ @typeName(T));
                    }

                    if (self.cursor_num >= 8) return Error.max_callbacks_exceeded;
                    self.cursor_callbacks[self.cursor_num] = pfn;
                    self.cursor_userdata[self.cursor_num] = userdata;
                    self.cursor_num += 1;
                },
            }
        }

        /// Upon window resize, call all registered callbacks.
        fn resizeCallback(
            h: ?*glfw.GLFWwindow,
            width: c_int,
            height: c_int,
        ) callconv(.C) void {
            const self: *Self = @alignCast(@ptrCast(glfw.glfwGetWindowUserPointer(h)));
            gl.glViewport(0, 0, width, height); // TODO: Maybe the user should decide this?

            for (0..self.resize_num) |i| {
                self.resize_callbacks[i](
                    @intCast(width),
                    @intCast(height),
                    self.resize_userdata[i],
                );
            }
        }

        /// Upon keyboard input, call all registered callbacks.
        fn keyboardCallback(
            h: ?*glfw.GLFWwindow,
            key: c_int,
            scancode: c_int,
            action: c_int,
            mods: c_int,
        ) callconv(.C) void {
            const self: *Self = @alignCast(@ptrCast(glfw.glfwGetWindowUserPointer(h)));

            for (0..self.key_num) |i| {
                self.key_callbacks[i](
                    @intCast(key),
                    @intCast(scancode),
                    @intCast(action),
                    @intCast(mods),
                    self.key_userdata[i],
                );
            }
        }

        /// Upon mouse input, call all registered callbacks.
        fn mouseCallback(
            h: ?*glfw.GLFWwindow,
            button: c_int,
            action: c_int,
            mods: c_int,
        ) callconv(.C) void {
            const self: *Self = @alignCast(@ptrCast(glfw.glfwGetWindowUserPointer(h)));

            for (0..self.mouse_num) |i| {
                self.mouse_callbacks[i](
                    @intCast(button),
                    @intCast(action),
                    @intCast(mods),
                    self.mouse_userdata[i],
                );
            }
        }

        /// Upon cursor movement, call all registered callbacks.
        fn cursorPositionCallback(
            h: ?*glfw.GLFWwindow,
            x_pos: f64,
            y_pos: f64,
        ) callconv(.C) void {
            const self: *Self = @alignCast(@ptrCast(glfw.glfwGetWindowUserPointer(h)));

            for (0..self.cursor_num) |i| {
                self.cursor_callbacks[i](
                    x_pos,
                    y_pos,
                    self.cursor_userdata[i],
                );
            }
        }
    };
}
