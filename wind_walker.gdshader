shader_type spatial;
render_mode unshaded, blend_add;

void fragment() {
    vec2 uv = UV;
    // Rüzgar çizgileri akışı
    float lines = step(0.8, sin(uv.y * 50.0 + TIME * 20.0));
    float fade = uv.x * (1.0 - uv.x); // Kenarlara doğru sönme
    
    ALBEDO = vec3(0.8, 0.9, 1.0);
    ALPHA = lines * fade * 0.5;
}