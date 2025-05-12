#version 330 core

layout (location = 0) in vec2 aPos;

out vec4 vertexColor;

void main() {
    gl_Position = vec4(aPos, 0.0, 1.0);
    
    // Calculate color based on position
    // For the circle: use position to create a gradient
    // For the corners: use white
    if (abs(aPos.x) > 0.8 || abs(aPos.y) > 0.8) {
        // Corners are white with some transparency
        vertexColor = vec4(1.0, 1.0, 1.0, 0.8);
    } else {
        // Circle uses a vibrant gradient based on position
        float angle = atan(aPos.y, aPos.x);
        float intensity = length(aPos);
        
        // Create a more vibrant colorful gradient
        vec3 color = vec3(
            0.5 + 0.5 * sin(angle * 2.0),
            0.5 + 0.5 * sin(angle * 2.0 + 2.094),
            0.5 + 0.5 * sin(angle * 2.0 + 4.189)
        );
        
        // Make colors more vibrant
        color = color * 1.5;
        
        // Add some brightness based on intensity
        color += vec3(0.2) * intensity;
        
        // Ensure colors are in valid range
        color = clamp(color, 0.0, 1.0);
        
        vertexColor = vec4(color, 1.0);
    }
}
