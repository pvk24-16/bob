#version 330 core

layout(location = 0) in vec3 i_pos;
layout(location = 1) in vec3 i_col;

out vec3 vs_col;

// uniform float time;

void main() {
    // vec4 pos = vec4(
    //     i_pos.x,
    //     i_pos.y + 0.1 * sin(i_pos.y + 2.0 * i_pos.x + time),
    //     i_pos.z,
    //     1.0
    // );
    gl_Position = vec4(i_pos, 1.0);
    vs_col = i_col;
}
