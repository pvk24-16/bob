#version 330 core

layout(location = 0) in vec3 iPos;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec3 norm;
layout(location = 3) in vec4 wiggleCoefs;
layout(location = 4) in vec4 offset;
layout(location = 5) in float pulse;
layout(location = 6) in float prevPulse;

out vec2 texCoord;
out vec3 normal;
out vec3 pos;
out vec3 lightPos;

uniform float time;
uniform float pulseTime;
uniform float interpTime;
uniform mat4 scaleRotateMatrix;
uniform mat4 translateMatrix;
uniform mat4 perspectiveMatrix;
uniform float minPulse;
uniform float amplitude;

uniform float xRotationCoef;
uniform float yRotationCoef;
uniform float zRotationCoef;
uniform vec3 absoluteOffset;

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

mat4 rotationMatrixX(float angleRadians) {
    float c = cos(angleRadians);
    float s = sin(angleRadians);

    return mat4(
        c, s, 0.0, 0.0,
        -s, c, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    );
}

float getInterpCoef() {
    float t = (time - pulseTime) / interpTime;
    // return 0.5 + 0.5 * sin(2.0 * PI * x - PI / 2.0);
    return t * t * (3.0 - 2.0 * t);
}

float getPulseCoef() {
    float interpCoef = getInterpCoef();
    float interpolatedPulse = (1 - interpCoef) * prevPulse + interpCoef * pulse;
    return interpolatedPulse * amplitude;
}

vec4 transformPos(vec3 pos) {
    float adjustedPulse = getPulseCoef();

    float a1 = wiggleCoefs.x;
    float p1 = pos.z + wiggleCoefs.y * time;
    float angle = wiggleCoefs.w - time;

    float sideToSideWiggle = pos.x + exp(-pos.x-1.0) * a1 * sin(-1.5 * p1);
    float upDownWiggle = pos.y;
    float frontBackWiggle = pos.z;

    vec4 wigglyPos = vec4(sideToSideWiggle, upDownWiggle, frontBackWiggle, 1.0);

    vec4 scaledRotatedPos = scaleRotateMatrix * wigglyPos;
    vec4 translatedPos = (minPulse + adjustedPulse) * offset + translateMatrix * scaledRotatedPos;
    mat4 rotationMatrix = rotationMatrixX(xRotationCoef * angle) * rotationMatrixY(yRotationCoef * angle) * rotationMatrixZ(zRotationCoef * angle);

    return vec4(absoluteOffset, 1.0) + rotationMatrix * translatedPos;
}

void main() {
    lightPos = transformPos(vec3(2.0, 5.0, 1.0)).xyz;

    vec4 transformedPos = transformPos(iPos);
    gl_Position = perspectiveMatrix * transformedPos;

    normal = norm;
    texCoord = uv;
    pos = transformedPos.xyz;
}
