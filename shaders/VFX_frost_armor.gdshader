shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform vec4 ice_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float shield_power : hint_range(1.0, 10.0) = 3.0;
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.5;
uniform float crackle_scale : hint_range(1.0, 20.0) = 8.0;

// Sahte Voronoi/Noise fonksiyonu (Buz kırıkları için)
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv);
    
    // 0. ANA DAİRE MASKESİ (Karenin kenarlarını yok eden kısım)
    // Merkeze 0.5 uzaklıktan sonrasını tamamen siler
    float final_mask = smoothstep(0.5, 0.48, dist);
    
    // 1. Temel Halka ve Kenar Yumuşatma
    float ring = smoothstep(0.48, 0.45, dist) * smoothstep(0.3, 0.48, dist);
    
    // 2. Hareketli Buz Kırıkları (Noise)
    vec2 noise_uv = uv * crackle_scale;
    float noise = hash(floor(noise_uv + TIME * 0.1));
    float cracks = smoothstep(0.4, 0.5, noise) * ring;
    
    // 3. İçten Dışa Soğuk Dalgaları
    float waves = sin(dist * 20.0 - TIME * pulse_speed) * 0.5 + 0.5;
    waves *= (1.0 - dist * 2.0); // Merkeze yaklaştıkça sönümle
    
    // 4. Fresnel Etkisi (Kenar Parlaması)
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
    
    // Renk Birleştirme
    vec3 final_color = ice_color.rgb * shield_power;
    
    // Parıltı ekle (Zamanla değişen parlaklık)
    float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
    
    // Tüm katmanları birleştir
    float alpha_content = ring * 0.4;     // Ana koruma katmanı
    alpha_content += cracks * 0.6;        // Buz çatlakları
    alpha_content += waves * 0.2;         // Enerji dalgaları
    alpha_content += fresnel * 0.5;       // Kenar ışıması
    
    ALBEDO = final_color;
    
    // KRİTİK NOKTA: İçeriği ana daire maskesiyle çarparak köşeleri kesiyoruz
    ALPHA = clamp(alpha_content * ice_color.a * pulse * final_mask, 0.0, 1.0);
}