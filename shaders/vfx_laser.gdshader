shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_opaque;

// RENK AYARLARI
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Çekirdek (Beyaz)
uniform vec4 glow_color : source_color = vec4(0.5, 0.0, 1.0, 1.0); // Dış Hale (Mor)
uniform float thickness : hint_range(0.0, 1.0) = 0.4; // Çekirdek kalınlığı

// HAREKET AYARLARI
uniform float beam_speed : hint_range(0.0, 20.0) = 8.0; // Akış hızı
uniform float flicker_speed : hint_range(0.0, 50.0) = 20.0; // Titreme hızı

// DOKU (Bunu Inspector'dan ata!)
uniform sampler2D noise_tex : repeat_enable; // Seamless Noise Texture

void vertex() {
    // JÖLE YOK! Sadece kalınlık hafifçe titrer (Nabız gibi)
    // Vertexleri sağa sola yamultmak yerine sadece normal yönünde şişiriyoruz.
    float pulse = sin(TIME * flicker_speed) * 0.02; 
    VERTEX += NORMAL * pulse; 
}

void fragment() {
	
    // 1. AKIŞ EFEKTİ (Çift Katmanlı)
    // İki farklı hızda kayan dokuyu üst üste bindiriyoruz ki "bayağı hızlı" görünsün.
	vec2 flow_uv1 = vec2(UV.x * 10.0 - TIME * beam_speed, UV.y);
    vec2 flow_uv2 = vec2(UV.x - TIME * (beam_speed * 1.5), UV.y * 2.0);
    
    float noise1 = texture(noise_tex, flow_uv1).r;
    float noise2 = texture(noise_tex, flow_uv2).r;
    
    // Enerji yoğunluğu (İkisinin çarpımı daha kaotik durur)
    float energy = (noise1 + noise2);
    
    // 2. ÇEKİRDEK (CORE) MANTIĞI
    // UV.y (dikey eksen) üzerinden lazerin ortasını buluyoruz.
    // 0.5 ortasıdır. Kenarlara gidildikçe değer artar.
    float center_dist = abs(UV.y - 0.5) * 2.0; // 0 (orta) -> 1 (kenar)
    
    // Kenarları yumuşat ama ortayı sert tut
    float beam_mask = 1.0 - center_dist;
    beam_mask = pow(beam_mask, 2.0); // Keskinleştir
    
    // 3. RENK KARIŞIMI
    // Eğer merkeze yakınsa Beyaz (Core), uzaksa Mor (Glow)
    vec3 final_color = mix(glow_color.rgb, core_color.rgb, step(thickness, beam_mask * energy));
    
    // Kenarları silikleştir (Borunun kenarları görünmesin)
    float alpha_fade = smoothstep(0.0, 0.3, beam_mask);
    
    ALBEDO = final_color * (1.5 + energy); // Parlaklığı kökle
    ALPHA = alpha_fade * glow_color.a;
}