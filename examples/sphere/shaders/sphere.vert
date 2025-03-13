#version 330 core

layout(location = 0) in vec3 pos;

uniform float time;
uniform mat4 perspectiveMatrix;

void main() {
    gl_Position = perspectiveMatrix * vec4(pos, 1.0);
}