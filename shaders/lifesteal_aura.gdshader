shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform vec4 color : source_color = vec4(0.8, 0.0, 0.0, 1.0); // Kan kırmızısı

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv);
    
    // Dış halka ve içe doğru akan rünler
    float ring = smoothstep(0.45, 0.46, dist) - smoothstep(0.48, 0.49, dist);
    
    // İçe akan enerji çizgileri
    float angle = atan(uv.y, uv.x);
    float flow = step(0.9, sin(angle * 12.0 - TIME * 5.0));
    
    float mask = ring + (flow * (0.45 - dist));
    
    ALBEDO = color.rgb * 2.5;
    ALPHA = clamp(mask, 0.0, 1.0) * 0.7;
}