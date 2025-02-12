#version 330 core

layout(location = 0) in vec2 i_pos;
layout(location = 1) in float i_temp;
layout(location = 2) in float i_intensity;

out float f_temp;
out float f_intensity;

void main() {
    gl_Position = vec4(i_pos, 0.0, 1.0);
    f_temp = i_temp;
    f_intensity = i_intensity;
}
