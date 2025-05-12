#version 330 core

in vec2 f_pos;
out vec4 f_col;

uniform vec3 f_color;


void main() {
    f_col = vec4(f_color, 1.0);
}
