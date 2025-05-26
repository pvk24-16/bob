#version 330 core

in vec2 v_pos;
in vec3 v_col;
out vec2 f_pos;
out vec3 f_col;

void main() {
    f_pos = v_pos;
    f_col = v_col;
    gl_Position = vec4(v_pos, 0.0, 1.0);
}
