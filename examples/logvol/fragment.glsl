#version 330 core

in vec2 f_pos;
out vec4 f_col;

void main() {
    f_col = vec4(
        (f_pos.y + 1.0) / 2.0,
        (2.0 - f_pos.y) / 2.0,
        (f_pos.x + 1.0) / 2.0,
        1.0
    );
}
