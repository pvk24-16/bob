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
    pub fn perspective(fov_degrees: f32, aspect : f32, near: f32, far: f32) Mat4 {
        const s = 1.0 / std.math.tan((fov_degrees / 2.0) * (std.math.pi / 180.0));

        return Mat4{ .arr = .{
            s / aspect,   0.0, 0.0,                          0.0,
            0.0, s,   0.0,                          0.0,
            0.0, 0.0, -far / (far - near),          -1.0,
            0.0, 0.0, -(far * near) / (far - near), 0.0,
        } };
    }

    pub fn translate(m: Mat4, tx: f32, ty: f32, tz: f32) Mat4 {
        const translation_matrix = Mat4{
            .arr = [16]f32{
                1.0, 0.0, 0.0, 0.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                tx,  ty,  tz,  1.0,
            },
        };
        return translation_matrix.matmul(m);
    }

    pub fn scale(m: Mat4, s: f32) Mat4 {
        const translation_matrix = Mat4{
            .arr = [16]f32{
                s,   0.0, 0.0, 0.0,
                0.0, s,   0.0, 0.0,
                0.0, 0.0, s,   0.0,
                0.0, 0.0, 0.0, 1.0,
            },
        };
        return translation_matrix.matmul(m);
    }

    pub fn rotate(m: Mat4, axis: [3]f32, angle_degrees: f32) Mat4 {
        const radians = angle_degrees * (std.math.pi / 180.0);
        const x = axis[0];
        const y = axis[1];
        const z = axis[2];
        const c = @cos(radians);
        const s = @sin(radians);
        const t = 1.0 - c;

        const rotation_matrix = Mat4{
            .arr = [16]f32{
                t * x * x + c,     t * x * y - s * z, t * x * z + s * y, 0.0,
                t * x * y + s * z, t * y * y + c,     t * y * z - s * x, 0.0,
                t * x * z - s * y, t * y * z + s * x, t * z * z + c,     0.0,
                0.0,               0.0,               0.0,               1.0,
            },
        };
        return rotation_matrix.matmul(m);
    }

    pub fn matmul(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = Mat4{ .arr = std.mem.zeroes([16]f32) };
        for (0..4) |row| {
            for (0..4) |col| {
                var sum: f32 = 0.0;
                for (0..4) |i| {
                    sum += a.arr[row * 4 + i] * b.arr[i * 4 + col];
                }
                result.arr[row * 4 + col] = sum;
            }
        }
        return result;
    }
};
