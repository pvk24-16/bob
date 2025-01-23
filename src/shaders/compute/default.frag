#version 330 core

out float result;

uniform sampler2D tinput;
uniform ivec2 src_d;
uniform ivec2 dst_d;

void main() {
    // result = 44;
    result = texture2D(tinput, gl_FragCoord.xy / src_d).r * 2.0;
}
