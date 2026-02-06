shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_opaque;

uniform vec4 lightning_color : source_color = vec4(0.2, 0.8, 1.0, 1.0); // Neon Mavi
uniform float speed : hint_range(0.0, 20.0) = 10.0;
uniform float chaos : hint_range(0.0, 1.0) = 0.3; // Ne kadar yamulsun?
uniform float thickness : hint_range(0.0, 0.5) = 0.05; // Kalınlık

// SİNÜS TOPLAMI (KOPMAZ FORMÜL)
// Rastgelelik yerine, farklı frekanslardaki dalgaları üst üste bindiriyoruz.
float bolt_wave(float y, float time) {
    float wave = 0.0;
    // Ana dalga (Gövde)
    wave += sin(y * 10.0 + time) * 0.5;
    // Detay dalga (Titreşim)
    wave += sin(y * 33.0 - time * 2.5) * 0.25;
    // İnce detay (Cızırtı)
    wave += sin(y * 57.0 + time * 5.0) * 0.125;
    return wave;
}

void vertex() {
    // Kameraya dönme (Billboard)
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
    // Zaman akışı
    float t = TIME * speed;
    
    // UV.y üzerinden dalgayı hesapla
    float bolt_offset = bolt_wave(UV.y, t);
    
    // Merkezi kaydır (X ekseninde yamult)
    float centerline = UV.x + (bolt_offset * chaos);
    
    // Çizgiyi oluştur (Merkezden uzaklaştıkça sön)
    float glow = 1.0 - abs(centerline - 0.5) / thickness;
    glow = clamp(glow, 0.0, 1.0);
    glow = pow(glow, 3.0); // Keskinleştir
    
    // Uçları yumuşat (Küt diye bitmesin)
    float fade = smoothstep(0.0, 0.1, UV.y) * smoothstep(1.0, 0.9, UV.y);
    
    ALBEDO = lightning_color.rgb;
    ALPHA = glow * fade * lightning_color.a;
}