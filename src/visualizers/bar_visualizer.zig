const std = @import("std");
const g = @import("../graphics/graphics.zig");
const utils = @import("utils.zig");
const Window = g.window.Window;
const Shader = g.shader.Shader;
const VertexBuffer = g.buffer.VertexBuffer;
const ElementBuffer = g.buffer.ElementBuffer;
const UniformBuffer = g.buffer.UniformBuffer;
const AudioAnalysisData = utils.AudioAnalysisData;
const Vertex = utils.Vertex;

fn gen_vertex_data(allocator: std.mem.Allocator, fft_data: []const f32) ![]Vertex {
    var vertex_data = try allocator.alloc(Vertex, fft_data.len * 6);
    const num_data_samples: f32 = @floatFromInt(fft_data.len);
    const step_size: f32 = 2.0 / num_data_samples;

    for (fft_data, 0..) |amp, i| {
        const fi: f32 = @floatFromInt(i);
        const x1 = step_size * fi - 1.0;
        const x2 = x1 + step_size;

        const y1 = 0.0;
        const y2 = y1 + 0.003 + amp;

        vertex_data[6 * i] = Vertex{
            .pos = .{ .x = x1, .y = y1, .z = 0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        };
        vertex_data[6 * i + 1] = Vertex{
            .pos = .{ .x = x1, .y = y2, .z = 0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        };
        vertex_data[6 * i + 2] = Vertex{
            .pos = .{ .x = x2, .y = y1, .z = 0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        };
        vertex_data[6 * i + 3] = Vertex{
            .pos = .{ .x = x1, .y = y2, .z = 0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        };
        vertex_data[6 * i + 4] = Vertex{
            .pos = .{ .x = x2, .y = y2, .z = 0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        };
        vertex_data[6 * i + 5] = Vertex{
            .pos = .{ .x = x2, .y = y1, .z = 0 },
            .col = .{ .x = 1.0, .y = 1.0, .z = 1.0 },
        };
    }

    return vertex_data;
}

pub fn BarVisualizer() type {
    return struct {
        const Self = @This();
        var offset: usize = 0;

        allocator: std.mem.Allocator = undefined,
        shader: Shader = undefined,
        vertex_buffer: VertexBuffer(Vertex) = undefined,
        num_verticies: usize,

        pub fn init() !Self {
            const shader = try Shader.init(
                @embedFile("../shaders/bar.vert"),
                @embedFile("../shaders/bar.frag"),
            );

            const allocator = std.heap.page_allocator;

            var vertex_buffer = VertexBuffer(Vertex).init();

            vertex_buffer.bind();
            vertex_buffer.write(utils.full_quad(), .static);
            vertex_buffer.enableAttribute(0, 3, .float, false, 0);
            vertex_buffer.enableAttribute(1, 3, .float, false, @offsetOf(Vertex, "col"));
            vertex_buffer.unbind();

            return Self{
                .allocator = allocator,
                .shader = shader,
                .vertex_buffer = vertex_buffer,
                .num_verticies = 2,
            };
        }

        pub fn deinit(self: *Self) void {
            self.shader.deinit();
            self.vertex_buffer.deinit();
        }

        pub fn draw(self: *Self, data: *AudioAnalysisData) !void {
            try self.update_verticies(data);

            g.gl.glLineWidth(3);

            g.gl.glClearColor(0.7, 0.4, 0.85, 1.0);
            g.gl.glClear(g.gl.GL_COLOR_BUFFER_BIT);

            self.shader.bind();
            self.vertex_buffer.bindArray();

            g.gl.glDrawArrays(g.gl.GL_TRIANGLES, 0, @intCast(self.num_verticies));

            self.vertex_buffer.unbindArray();
        }

        fn update_verticies(self: *Self, data: *AudioAnalysisData) !void {
            const vertex_data = try gen_vertex_data(self.allocator, data.fft_data);
            defer self.allocator.free(vertex_data);

            self.num_verticies = vertex_data.len;

            self.vertex_buffer.bind();
            self.vertex_buffer.write(vertex_data, .static);
            self.vertex_buffer.enableAttribute(0, 3, .float, false, 0);
            self.vertex_buffer.enableAttribute(1, 3, .float, false, @offsetOf(Vertex, "col"));
            self.vertex_buffer.unbind();
        }
    };
}
