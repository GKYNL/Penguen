shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque; 
// unshaded: Işık gölge almaz, kendi parlar.
// cull_disabled: İçi dışı görünür.

uniform vec4 storm_color : source_color = vec4(0.2, 0.8, 1.0, 0.8); // Buz Mavisi
uniform float rotation_speed : hint_range(0.0, 10.0) = 3.0; // Dönme hızı
uniform float density : hint_range(0.0, 2.0) = 1.0; // Şeffaflık ayarı

// Inspector'dan Noise Texture atamayı UNUTMA!
uniform sampler2D noise_tex; 

void vertex() {
    // Vertexleri (noktaları) hafifçe şişirip indir (Nefes alma efekti)
    // Ama çok abartma ki şekli bozulmasın.
    float breathe = sin(TIME * 2.0 + VERTEX.y) * 0.1;
    VERTEX.x += NORMAL.x * breathe;
    VERTEX.z += NORMAL.z * breathe;
}

void fragment() {
    // 1. DÖNME EFEKTİ (UV Scrolling)
    // UV.x (Yatay) ekseninde zamanla kaydırıyoruz.
    vec2 swirl_uv = vec2(UV.x - (TIME * rotation_speed * 0.2), UV.y);
    
    // 2. İKİNCİ KATMAN (Kaos için ters yöne hafif hareket)
    vec2 chaos_uv = vec2(UV.x + (TIME * rotation_speed * 0.1), UV.y * 0.5 - TIME * 0.1);
    
    // Noise texture'dan iki değeri oku ve karıştır
    float noise1 = texture(noise_tex, swirl_uv).r;
    float noise2 = texture(noise_tex, chaos_uv).r;
    float combined_noise = (noise1 + noise2) * 0.5;
    
    // 3. FRESNEL (Kenar Parlaması - Hacim Hissi)
    // Bakış açısına dik olan yerler (kenarlar) parlak, ortası şeffaf.
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 2.0);
    
    // 4. MASK (Alt ve Üstü Yumuşat)
    // Hortumun en tepesi ve en dibi küt diye bitmesin, silikleşsin.
    float fade_mask = smoothstep(0.0, 0.2, UV.y) * smoothstep(1.0, 0.8, UV.y);
    
    // Rengi ayarla
    ALBEDO = storm_color.rgb;
    
    // Görünürlük hesabı:
    // Fresnel (Kenar) + Noise (Doku) * Maske
    float alpha = (fresnel + combined_noise * density) * fade_mask * storm_color.a;
    ALPHA = clamp(alpha, 0.0, 1.0);
}