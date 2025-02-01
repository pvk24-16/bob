#version 330 core

in vec2 tex_coord;
in vec3 normal;

out vec4 o_col;

uniform sampler2D tex;

void main() {
    float shade = dot(normal, vec3(0.0, 0.0, 1.0));
    vec4 clr = texture2D(tex, tex_coord);
    o_col = clr;
}
