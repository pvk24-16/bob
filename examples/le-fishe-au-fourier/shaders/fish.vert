#version 330 core

layout(location = 0) in vec3 i_pos;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec3 norm;
layout(location = 3) in vec4 wiggle_coefs;
layout(location = 4) in vec4 offset;
layout(location = 5) in float freq;
layout(location = 6) in float prev_freq;

out vec2 tex_coord;
out vec3 normal;
out vec3 pos;
out vec3 lightPos;

uniform float time;
uniform float freq_time;
uniform float interp_time;
uniform mat4 scaleRotateMatrix;
uniform mat4 translateMatrix;
uniform mat4 perspectiveMatrix;
uniform float minFreq;
uniform float amplitude;

const float PI = 3.14159265359;

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

float get_interp_coef() {
    float t = (time - freq_time) / interp_time;
    // return 0.5 + 0.5 * sin(2.0 * PI * x - PI / 2.0);
    return t * t * (3.0 - 2.0 * t);
}

float get_freq_coef() {
    float interp_coef = get_interp_coef();
    float interpolated_freq = (1 - interp_coef) * prev_freq + interp_coef * freq;
    return sqrt(interpolated_freq * amplitude);
}

vec4 transformPos(vec3 pos) {
    float adjusted_freq = get_freq_coef();

    float a_1 = wiggle_coefs.x;
    float p_1 = pos.z + wiggle_coefs.y * time;
    float angle = mod(wiggle_coefs.w - time, 2.0 * PI);

    float side_to_side_wiggle = pos.x + exp(-pos.x-1.0) * a_1 * sin(-p_1);
    float up_down_wiggle = pos.y;
    float front_back_wiggle = pos.z;

    vec4 wiggly_pos = vec4(side_to_side_wiggle, up_down_wiggle, front_back_wiggle, 1.0);

    vec4 scaled_rotated_pos = scaleRotateMatrix * wiggly_pos;
    vec4 translated_pos = (minFreq + adjusted_freq) * offset  + translateMatrix * scaled_rotated_pos;
    mat4 rotation_matrix = rotationMatrixZ(0.35 * PI * sin(angle)) * rotationMatrixY(angle) ;

    return vec4(0., 0., -1.0, 0.0) + rotation_matrix * translated_pos;
}

void main() {
    lightPos = transformPos(vec3(2.0, 5.0, 1.0)).xyz;

    vec4 transformedPos = transformPos(i_pos);
    gl_Position = perspectiveMatrix * transformedPos;

    normal = norm;
    tex_coord = uv;
    pos = transformedPos.xyz;
}