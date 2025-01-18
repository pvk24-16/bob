#version 460

layout(location = 0) in vec3 i_pos;
layout(location = 0) out vec3 o_col;

void main() {
    gl_Position = vec4(i_pos, 1.0);
    o_col = i_pos;
}
