#version 330 core

layout(location = 0) in vec3 i_pos;
layout(location = 1) in vec3 i_col;

out vec3 vs_col;

uniform float time;
uniform mat4 perspectiveMatrix;

void main() {
    vec4 pos = vec4(
        i_pos.x * cos(time),
        i_pos.y,
        i_pos.z + i_pos.x * sin(time),
        1.0
    );
    gl_Position = perspectiveMatrix * pos;
    vs_col = i_col;
}
