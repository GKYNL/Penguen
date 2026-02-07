shader_type spatial;
render_mode unshaded, blend_add;

void fragment() {
    vec2 uv = UV;
    // Rastgele elektrik atlamaları
    float noise = fract(sin(dot(uv + TIME, vec2(12.9, 78.2))) * 43758.5);
    float sparks = step(0.9, noise);
    
    ALBEDO = vec3(1.0, 1.0, 0.2); // Sarı elektrik
    ALPHA = sparks;
}