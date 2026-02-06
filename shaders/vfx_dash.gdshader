shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_opaque;

// AYARLAR
uniform vec4 trail_color : source_color = vec4(0.0, 0.8, 1.0, 1.0); // Neon Mavi
uniform float wind_speed : hint_range(0.0, 20.0) = 8.0; // Rüzgar hızı
uniform float transparency : hint_range(0.0, 1.0) = 1.0; // Genel görünürlük

// RÜZGAR DOKUSU (Inspector'dan atanacak!)
uniform sampler2D wind_noise : repeat_enable; 

void vertex() {
    // Billboard gerekmez, RibbonTrailMesh kameraya döner.
}

void fragment() {
    // 1. RÜZGAR AKIŞI
    // UV.x şeridin boyudur. Dokuyu geriye doğru çok hızlı kaydırıyoruz.
    // "UV.y * 0.5" ekleyerek dokuyu hafif çapraz yapıyoruz ki aerodinamik dursun.
    vec2 flow_uv = vec2(UV.x * 0.5 + TIME * wind_speed, UV.y);
    
    // Noise dokusunu oku
    float wind_pattern = texture(wind_noise, flow_uv).r;
    
    // 2. KENAR YUMUŞATMA (Jilet gibi kesilmesin)
    // Şeridin altını ve üstünü yumuşatıyoruz.
    float edge_fade = smoothstep(0.0, 0.2, UV.y) * smoothstep(1.0, 0.8, UV.y);
    
    // 3. PARTICLE RENGİ (Color Ramp'ten gelen)
    // ParticleProcessMaterial'daki Gradient buraya "COLOR" olarak gelir.
    vec4 particle_data = COLOR;
    
    // 4. SONUÇ
    // Renk: Mavi * Particle Gradient'i * Parlaklık Çarpanı (3.0)
    ALBEDO = trail_color.rgb * particle_data.rgb * 3.0; 
    
    // Görünürlük: Rüzgar Deseni * Kenar Yumuşatma * Particle Silinmesi
    ALPHA = wind_pattern * edge_fade * particle_data.a * trail_color.a * transparency;
}