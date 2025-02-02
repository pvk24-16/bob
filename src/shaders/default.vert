#version 330 core

layout(location = 0) in vec3 i_pos;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec3 norm;

out vec2 tex_coord;
out vec3 normal;

uniform float time;
uniform mat4 perspectiveMatrix;

mat3 rotationMatrixY(float angleRadians) {
    float c = cos(angleRadians);
    float s = sin(angleRadians);

    return mat3(
        c, 0.0, s,
        0.0, 1.0, 0.0,
        -s, 0.0, c
    );
}

void main() {
    gl_Position = perspectiveMatrix * vec4(i_pos + vec3(2., 0., -4.0), 1.0);
    tex_coord = uv;
    normal = norm;
}
