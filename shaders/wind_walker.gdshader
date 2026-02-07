shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

uniform vec4 wind_color : source_color = vec4(0.2, 0.5, 1.0, 1.0); // Daha doygun bir mavi
uniform float speed : hint_range(5.0, 50.0) = 25.0;

// Çizgileri daha keskin ve rastgele yapan yardımcı fonksiyon
float hash(float n) { return fract(sin(n) * 43758.5453123); }

void fragment() {
    vec2 uv = UV;
    
    // 1. Akış hızı ve Rastgelelik
    // Çizgileri Y ekseninde (boyuna) dağıtıyoruz
    float line_id = floor(uv.y * 40.0); 
    float offset = hash(line_id) * 10.0;
    
    // X ekseninde (ileriye doğru) hızla akan çizgiler
    float flow = step(0.6, sin(uv.x * 2.0 - (TIME * speed) + offset));
    
    // 2. Kenarları Yumuşatma (Fade)
    // Hem X hem Y ekseninde yumuşatıyoruz ki plane'in kare olduğu belli olmasın
    float mask = smoothstep(0.0, 0.2, uv.x) * smoothstep(1.0, 0.8, uv.x);
    mask *= smoothstep(0.0, 0.3, uv.y) * smoothstep(1.0, 0.7, uv.y);
    
    // 3. Renk ve Belirginlik
    // Kenarları biraz daha koyu, ortaları daha parlak yapıyoruz (Kontrast)
    vec3 final_color = mix(wind_color.rgb, vec3(1.0), flow * 0.5);
    
    ALBEDO = final_color;
    
    // Mix mode kullandığımız için ALPHA daha önemli hale geldi
    ALPHA = flow * mask * wind_color.a;
    
    // Ekstra parıltı (Emission benzeri etki)
    ALPHA *= 1.5; 
}