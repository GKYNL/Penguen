shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform vec4 color : source_color = vec4(0.0, 0.6, 1.0, 1.0); // Buz mavisi

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv);
    
    // Keskin, altıgenimsi buz halkası
    float ring = smoothstep(0.4, 0.41, dist) - smoothstep(0.42, 0.43, dist);
    
    // Buz kristalleri titremesi
    float crystals = step(0.7, sin(atan(uv.y, uv.x) * 6.0 + TIME));
    float final_mask = ring + (crystals * ring * 0.5);
    
    ALBEDO = color.rgb * 3.0;
    ALPHA = final_mask * (0.6 + 0.2 * sin(TIME * 4.0));
}