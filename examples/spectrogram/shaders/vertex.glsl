#version 330 core

in vec2 v_pos;
out vec2 f_pos;

void main() {
    f_pos = v_pos;
    gl_Position = vec4(v_pos, 0.0, 1.0);
}
