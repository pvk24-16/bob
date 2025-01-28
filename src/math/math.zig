const std = @import("std");

pub const Vec2 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
};

pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
};

pub const Vec4 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    w: f32 = 0.0,
};

pub const Mat4 = struct {
    arr: [16]f32,

    pub fn set(self: *Mat4, i: usize, j: usize, elm: f32) void {
        self.arr[4 * i + j] = elm;
    }
    pub fn get(self: *Mat4, i: usize, j: usize) f32 {
        return self.arr[4 * i + j];
    }
    pub fn identity() Mat4 {
        return Mat4{ .arr = .{
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0,
        } };
    }
    pub fn perspective(fov_degrees: f32, near: f32, far: f32) Mat4 {
        const s = 1.0 / std.math.tan((fov_degrees / 2.0) * (std.math.pi / 180.0));

        return Mat4{ .arr = .{
            s,   0.0, 0.0,                          0.0,
            0.0, s,   0.0,                          0.0,
            0.0, 0.0, -far / (far - near),          -1.0,
            0.0, 0.0, -(far * near) / (far - near), 0.0,
        } };
    }
};
