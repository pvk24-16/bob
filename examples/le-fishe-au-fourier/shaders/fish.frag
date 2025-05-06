#version 330 core

in vec2 tex_coord;
in vec3 normal;
in vec3 pos;
in vec3 lightPos;

out vec4 o_col;

uniform sampler2D tex;
uniform float time;

const float fogNear = 0.5;
const float fogFar = 2.0;

float directionalNoise(vec2 dir) {
    // Fake caustics with directional sine pattern (replace with noise if desired)
    float pattern = sin(dir.x * 40.0 + time * 2.0) + sin(dir.y * 30.0 - time * 1.5);
    return pattern * 0.5 + 0.5;
}

void main() {
    // Direction from fragment to light
    vec3 lightDir = normalize(lightPos - pos);

    // Project direction onto a plane (e.g., XZ or XY)
    vec2 projected = lightDir.xz;

    // Sample a directional light pattern
    float rayIntensity = directionalNoise(projected * 1.0); // scale = density

    float facing = clamp(dot(normalize(normal), normalize(lightDir)), 0.0, 1.0);

    vec3 texColor = 0.5 * texture2D(tex, tex_coord).xyz;
    vec3 lightColor = vec3(0.75, 0.81, 0.62) * rayIntensity * facing;

    // Calculate depth factor based on z (or any axis depending on camera orientation)
    float depth = abs(pos.z); 
    float fogFactor = smoothstep(fogNear, fogFar, depth);
    vec3 fogColor = vec3(0.14, 0.04, 0.39);

    vec3 sceneColor = texColor + rayIntensity * lightColor;
    vec3 finalColor = mix(sceneColor, fogColor, fogFactor);

    o_col = vec4(finalColor, 1.0);
}