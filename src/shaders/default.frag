#version 330 core

in float f_temp;
in float f_intensity;

out vec4 o_col;

void main() {
    float r = f_temp;
    float g = f_temp / 2.0;
    float b = 1.0 - f_temp;
    o_col = vec4(r, g, b, f_intensity);
    // o_col = vec4(1.0, 1.0, 0.0, 1.0);
}
