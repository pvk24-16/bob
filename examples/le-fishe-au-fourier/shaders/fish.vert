#version 330 core

layout(location = 0) in vec3 i_pos;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec3 norm;
layout(location = 3) in vec4 wiggle_coefs;
layout(location = 4) in vec4 offset;


out vec2 tex_coord;
out vec3 normal;

uniform float time;
uniform mat4 scaleRotateMatrix;
uniform mat4 translateMatrix;
uniform mat4 perspectiveMatrix;

mat4 rotationMatrixY(float angleRadians) {
    float c = cos(angleRadians);
    float s = sin(angleRadians);

    return mat4(
        c, 0.0, s, 0.0,
        0.0, 1.0, 0.0, 0.0,
        -s, 0.0, c, 0.0,
        0.0, 0.0, 0.0, 1.0
    );
}

mat4 rotationMatrixZ(float angleRadians) {
    float c = cos(angleRadians);
    float s = sin(angleRadians);

    return mat4(
        1.0, 0.0, 0.0, 0.0,
        0.0, c, s, 0.0,
        0.0, -s, c, 0.0,
        0.0, 0.0, 0.0, 1.0
    );
}

vec4 transformPos(vec3 pos) {
    float a_1 = wiggle_coefs.x;
    float p_1 = pos.z + wiggle_coefs.y * time;
    float angle = wiggle_coefs.w - time;

    float side_to_side_wiggle = pos.x + a_1 * sin(p_1);
    float up_down_wiggle = pos.y;
    float front_back_wiggle = pos.z;

    vec4 wiggly_pos = vec4(side_to_side_wiggle, up_down_wiggle, front_back_wiggle, 1.0);

    vec4 scaled_rotated_pos = scaleRotateMatrix * wiggly_pos;
    vec4 translated_pos = offset + translateMatrix * scaled_rotated_pos;

    return vec4(0., 0., -1., 0.0) + rotationMatrixZ(-0.5 * angle) * rotationMatrixY(angle) * translated_pos;
}

void main() {
    float angle = wiggle_coefs.w - time;

    gl_Position = perspectiveMatrix * transformPos(i_pos);
    normal = transformPos(norm).xyz;
    tex_coord = uv;
}