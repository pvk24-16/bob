#version 330 core

in vec3 o_col;
out vec4 fragClr;

void main() {
    fragClr = vec4(o_col, 1.0);
}