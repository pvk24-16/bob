#version 330 core

in vec2 tex_coord;
in vec3 normal;

out vec4 o_col;

void main() {
    float clr = dot(normal, vec3(0.0, 1.0, 0.0));
    o_col = vec4(vec3(clr), 1.0);
}
