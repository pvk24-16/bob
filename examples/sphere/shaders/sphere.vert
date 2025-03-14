#version 330 core

layout(location = 0) in vec3 pos;

uniform float time;
uniform mat4 perspectiveMatrix;
uniform mat4 transformMatrix;

void main() {
    gl_Position = perspectiveMatrix * transformMatrix * vec4(pos, 1.0);
}