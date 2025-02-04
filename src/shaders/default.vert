#version 330 core

layout(location = 0) in vec3 i_pos;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec3 norm;
layout(location = 3) in vec4 wiggle_coefs;


out vec2 tex_coord;
out vec3 normal;

uniform float time;
uniform mat4 transformMatrix;

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
    float a_1 = wiggle_coefs.x;
    float p_1 = i_pos.z + wiggle_coefs.y * time;
    float a_2 = wiggle_coefs.z;
    float p_2 = i_pos.z + 3 * a_1 * time;

    float side_to_side_wiggle = i_pos.x + a_1 * sin(p_1);
    float up_down_wiggle = i_pos.y + a_2 * cos(p_2);
    float front_back_wiggle = i_pos.z;

    vec3 wiggly_pos = vec3(side_to_side_wiggle, up_down_wiggle, front_back_wiggle);

    vec3 scaled_rotated_pos = rotationMatrixY(1.5 * (wiggle_coefs.w - time)) * wiggly_pos;
    vec4 pos = transformMatrix * vec4(scaled_rotated_pos, 1.0);
    gl_Position = pos;
    tex_coord = uv;
    normal = norm;
}
