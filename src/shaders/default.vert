#version 460

layout(location = 0) in vec3 i_pos;

void main() {
    gl_Position = vec4(i_pos, 1.0);
}
