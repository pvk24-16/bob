#version 330 core

in vec3 vs_col;

out vec4 o_col;

void main() {
    o_col = vec4(vs_col, 1.0);
}
