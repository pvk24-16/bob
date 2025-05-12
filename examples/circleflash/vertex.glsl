#version 330 core

layout (location = 0) in vec2 aPos;

out vec4 vertexColor;

void main() {
    gl_Position = vec4(aPos, 0.0, 1.0);
    
    // Calculate color based on position
    // For the circle: use position to create a gradient
    // For the corners: use white
    if (abs(aPos.x) > 0.8 || abs(aPos.y) > 0.8) {
        // Corners are white
        vertexColor = vec4(1.0, 1.0, 1.0, 1.0);
    } else {
        // Circle uses a gradient based on position
        float angle = atan(aPos.y, aPos.x);
        float intensity = length(aPos);
        
        // Create a colorful gradient
        vec3 color = vec3(
            0.5 + 0.5 * sin(angle),
            0.5 + 0.5 * sin(angle + 2.094),
            0.5 + 0.5 * sin(angle + 4.189)
        );
        
        vertexColor = vec4(color, 1.0);
    }
}
