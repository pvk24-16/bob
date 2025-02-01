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

mat3 rotationMatrixZ(float angleDegrees) {
    float angleRadians = radians(angleDegrees); // Convert angle to radians
    float c = cos(angleRadians);
    float s = sin(angleRadians);

    return mat3(
        c, -s, 0.0,
        s,  c, 0.0,
        0.0, 0.0, 1.0
    );
}

void main() {
    mat3 transform = rotationMatrixY(-time) * rotationMatrixZ(time * time);
    vec3 pos = transform * i_pos + vec3(0., 0., -4.);
    gl_Position = perspectiveMatrix * vec4(pos, 1.0);
    tex_coord = uv;
    normal = transform * norm;
}
