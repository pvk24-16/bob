const std = @import("std");
const g = @import("graphics/graphics.zig");
const VertexBuffer = g.buffer.VertexBuffer;
const IndexBuffer = g.buffer.ElementBuffer;
const math = @import("math/math.zig");
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;

const VertexNoTex = struct {
    pos: Vec3,
    norm: Vec3,
};

const VertexWithTex = struct {
    pos: Vec3,
    tex_coord: Vec2,
    norm: Vec3,
};

const VertexData = union(enum) {
    with_tex: []VertexWithTex,
    no_tex: []VertexNoTex,
};

const BufferType = union(enum) {
    no_tex: VertexBuffer(VertexNoTex),
    with_tex: VertexBuffer(VertexWithTex),
};

const Buffers = struct {
    vertex_buffer: BufferType,
    vertex_count: usize,
    index_buffer: IndexBuffer(u32),
    index_count: usize,

    // pub fn deinit(self: *Buffers) void {
    //     self.index_buffer.deinit();
    //     switch (self.vertex_buffer) {
    //         .with_tex => |buf| {
    //             buf.deinit();
    //         },
    //         .no_tex => |buf| {
    //             buf.deinit();
    //         },
    //     }
    // }
};

fn parseIndices(comptime T: type, tokens: *std.mem.TokenIterator(T, .any)) usize {
    var count: usize = 0;
    while (tokens.next()) |_| {
        count += 1;
    }
    if (count == 4) {
        return 6; // 2 triangles for a quad
    } else {
        return count;
    }
}

fn populateBuffers(
    comptime TokenT: type,
    index: *usize,
    tokens: *std.mem.TokenIterator(TokenT, .any),
    vertices: *[]Vec3,
    tex_coords: *[]Vec2,
    normals: *[]Vec3,
    index_data: *[]u32,
    vertex_data: *VertexData,
) !void {
    var face_count: usize = 0;
    while (tokens.next()) |token| {
        face_count += 1;
        var indices = std.mem.tokenizeAny(u8, token, "/");

        // Parse indicies as vert_index/tex_index/norm_index or vert_index//norm_index
        var vert_index = try std.fmt.parseUnsigned(u32, indices.next().?, 10);
        var tex_index = try std.fmt.parseUnsigned(u32, indices.next().?, 10);
        var norm_index = std.fmt.parseUnsigned(u32, indices.next() orelse "none", 10) catch tex_index;

        // .obj file uses 1-indexing, subtract 1 for 0-indexing
        vert_index -= 1;
        tex_index -= 1;
        norm_index -= 1;

        // Quad format parsed as 2 triangles
        if (face_count == 4) {
            index_data.*[index.*] = index_data.*[index.* - 3];
            index_data.*[index.* + 1] = index_data.*[index.* - 1];

            index.* += 2;
        }

        index_data.*[index.*] = vert_index;
        index.* += 1;

        switch (vertex_data.*) {
            .with_tex => |data| {
                const vertex: Vec3 = vertices.*[vert_index];
                const tex_coord: Vec2 = tex_coords.*[tex_index];
                const norm: Vec3 = normals.*[norm_index];

                data[vert_index] = VertexWithTex{
                    .pos = vertex,
                    .tex_coord = tex_coord,
                    .norm = norm,
                };
            },
            .no_tex => |data| {
                const vertex: Vec3 = vertices.*[vert_index];
                const norm: Vec3 = normals.*[norm_index];

                data[vert_index] = VertexNoTex{
                    .pos = vertex,
                    .norm = norm,
                };
            },
        }
    }
}

fn create_buffers(vertex_data: *VertexData, index_data: *[]u32) Buffers {
    var index_buffer = IndexBuffer(u32).init();

    index_buffer.bind();
    index_buffer.write(index_data.*, .static);
    index_buffer.unbind();

    switch (vertex_data.*) {
        .with_tex => |data| {
            var vertex_buffer = VertexBuffer(VertexWithTex).init();

            vertex_buffer.bind();

            vertex_buffer.write(data, .static);
            vertex_buffer.enableAttribute(0, 3, .float, false, 0);
            vertex_buffer.enableAttribute(1, 2, .float, false, @offsetOf(VertexWithTex, "tex_coord"));
            vertex_buffer.enableAttribute(2, 3, .float, false, @offsetOf(VertexWithTex, "norm"));

            vertex_buffer.unbind();

            return Buffers{
                .vertex_buffer = BufferType{ .with_tex = vertex_buffer },
                .vertex_count = data.len,
                .index_buffer = index_buffer,
                .index_count = @intCast(index_data.*.len),
            };
        },
        .no_tex => |data| {
            var vertex_buffer = VertexBuffer(VertexNoTex).init();

            vertex_buffer.bind();

            vertex_buffer.write(data, .static);
            vertex_buffer.enableAttribute(0, 3, .float, false, 0);
            vertex_buffer.enableAttribute(1, 3, .float, false, @offsetOf(VertexNoTex, "norm"));

            vertex_buffer.unbind();

            return Buffers{
                .vertex_buffer = BufferType{ .no_tex = vertex_buffer },
                .vertex_count = data.len,
                .index_buffer = index_buffer,
                .index_count = @intCast(index_data.*.len),
            };
        },
    }
}

pub fn parseObj(
    file_path: []const u8,
    allocator: std.mem.Allocator,
) !Buffers {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(file_contents);

    var lines = std.mem.tokenizeAny(u8, file_contents, "\n");

    var num_vertices: usize = 0;
    var num_tex_coords: usize = 0;
    var num_normals: usize = 0;
    var num_indices: usize = 0;

    // Count vertices, texture coordinates and normals
    while (lines.next()) |line| {
        var split = std.mem.tokenizeAny(u8, line, " \n\r");

        const s = split.next() orelse {
            continue;
        };
        if (std.mem.eql(u8, s, "v")) {
            num_vertices += 1;
        } else if (std.mem.eql(u8, s, "vt")) {
            num_tex_coords += 1;
        } else if (std.mem.eql(u8, s, "vn")) {
            num_normals += 1;
        } else if (std.mem.eql(u8, s, "f")) {
            num_indices += parseIndices(u8, &split);
        }
    }

    var vertices: []Vec3 = try allocator.alloc(Vec3, num_vertices);
    var tex_coords: []Vec2 = try allocator.alloc(Vec2, num_tex_coords);
    var normals: []Vec3 = try allocator.alloc(Vec3, num_normals);

    const has_tex_coord = num_tex_coords > 0;

    var vertex_data: VertexData = if (has_tex_coord)
        VertexData{ .with_tex = try allocator.alloc(VertexWithTex, num_vertices) }
    else
        VertexData{ .no_tex = try allocator.alloc(VertexNoTex, num_vertices) };

    var index_data: []u32 = try allocator.alloc(u32, num_indices);

    lines = std.mem.tokenizeAny(u8, file_contents, "\n\r");

    var v_i: usize = 0;
    var vt_i: usize = 0;
    var vn_i: usize = 0;
    var f_i: usize = 0;

    // Iterate again to populate vertex data
    while (lines.next()) |line| {
        var split = std.mem.tokenizeAny(u8, line, " \n\r");

        const s = split.next() orelse {
            continue;
        };

        if (std.mem.eql(u8, s, "v")) {
            const x = try std.fmt.parseFloat(f32, split.next().?);
            const y = try std.fmt.parseFloat(f32, split.next().?);
            const z = try std.fmt.parseFloat(f32, split.next().?);

            vertices[v_i] = Vec3{ .x = x, .y = y, .z = z };
            v_i += 1;
        } else if (std.mem.eql(u8, s, "vt")) {
            const u = try std.fmt.parseFloat(f32, split.next().?);
            const v = try std.fmt.parseFloat(f32, split.next().?);

            tex_coords[vt_i] = Vec2{ .x = u, .y = v };

            vt_i += 1;
        } else if (std.mem.eql(u8, s, "vn")) {
            const n_x = try std.fmt.parseFloat(f32, split.next().?);
            const n_y = try std.fmt.parseFloat(f32, split.next().?);
            const n_z = try std.fmt.parseFloat(f32, split.next().?);

            normals[vn_i] = Vec3{ .x = n_x, .y = n_y, .z = n_z };
            vn_i += 1;
        } else if (std.mem.eql(u8, s, "f")) {
            try populateBuffers(
                u8,
                &f_i,
                &split,
                &vertices,
                &tex_coords,
                &normals,
                &index_data,
                &vertex_data,
            );
        }
    }

    return create_buffers(&vertex_data, &index_data);
}
