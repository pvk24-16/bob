#version 330 core

layout(location = 0) in vec3 pos;

out vec3 o_col;

uniform float time;
uniform mat4 perspectiveMatrix;
uniform mat4 transformMatrix;

void main() {
    gl_Position = perspectiveMatrix * transformMatrix * vec4(pos, 1.0);
    o_col = vec3(1.0, 0.0, 0.0);
}