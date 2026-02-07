shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

uniform vec4 albedo : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale = 2.0;
uniform sampler2D noise_tex;

// Fonksiyon adı küçük harfle 'vertex' olmalı
void vertex() {
    // Noise verisini al
    float noise = texture(noise_tex, UV * noise_scale + vec2(0.0, progress)).r;
    
    // Titreme miktarını hesapla (Sonlara doğru sönümlenir)
    float displacement = noise * 0.5 * (1.0 - progress);
    
    // Değişken olan VERTEX'e ekleme yap
    VERTEX += NORMAL * displacement;
    
    // Büyüme çarpanı
    VERTEX *= (1.0 + (progress * 5.0));
}

void fragment() {
    // Fresnel (Kenar parlaması)
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 2.0);
    vec3 color = albedo.rgb;
    
    // Görünürlük ayarı
    float alpha = fresnel * (1.0 - progress); 
    
    ALBEDO = color;
    ALPHA = alpha;
}