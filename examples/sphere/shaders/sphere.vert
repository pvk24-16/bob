#version 330 core

layout(location = 0) in vec3 pos;

uniform float time;
uniform mat4 perspectiveMatrix;
uniform mat4 transformMatrix;

void main() {
    vec3 p = vec3(pos.x, pos.y + sin(time) * 0.05, pos.z);
    gl_Position = perspectiveMatrix * transformMatrix * vec4(p, 1.0);
}
