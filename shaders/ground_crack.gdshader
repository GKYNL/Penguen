shader_type spatial;
// unshaded: Işıktan etkilenmez, kendi rengini basar
// cull_disabled: Ters dursa da görünür
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque;

uniform vec4 crack_base_color : source_color = vec4(0.1, 0.02, 0.0, 1.0); // Koyu Çatlak (Dış)
uniform vec4 crack_glow_color : source_color = vec4(1.0, 0.3, 0.1, 1.0); // Magma/Kor (İç)

// AYARLAR
uniform float scale : hint_range(1.0, 20.0) = 4.0; 
uniform float crack_width : hint_range(0.0, 0.2) = 0.05; // Hedef Dış kalınlık
uniform float glow_width : hint_range(0.0, 0.1) = 0.015;  // Hedef İç parlak çizgi kalınlığı
uniform float expansion : hint_range(0.0, 1.5) = 0.0; // Yayılma animasyonu (Biraz daha büyüttüm max değeri)
uniform float fade : hint_range(0.0, 1.0) = 0.0;      // Silinme animasyonu

// BU FONKSİYON KORUNDU (Yerden yüksek durmasını sağlar)
void vertex() {
	VERTEX.y += 0.15;
}

vec2 random2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float voronoi_cracks(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float min_dist = 1.0;
	float second_min_dist = 1.0;

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = random2(i + neighbor);
			// point = 0.5 + 0.5 * sin(point * 6.2831); // Hareketi kapattım, statik daha net çatlak verir
			vec2 diff = neighbor + point - f;
			float dist = length(diff);

			if (dist < min_dist) {
				second_min_dist = min_dist;
				min_dist = dist;
			} else if (dist < second_min_dist) {
				second_min_dist = dist;
			}
		}
	}
	return second_min_dist - min_dist;
}

void fragment() {
	vec2 centered_uv = UV - 0.5;
	vec2 scaled_uv = centered_uv * scale;
	
	// 1. Çatlak Hammaddesi
	float crack_raw = voronoi_cracks(scaled_uv);
	
	// 2. Mesafe Hesabı (0: Merkez, 1: Daire kenarı)
	float dist = length(centered_uv) * 2.0;
	
	// --- YENİ KISIM: İLERLEME EFEKTİ ---
	// expansion değerinin "öncü" kısmında çatlaklar ince, arkasında kalın olsun.
	// smoothstep(edge0, edge1, x): x edge0'dayken 0, edge1'deyken 1 döndürür.
	// Burada dist, expansion'a eşitse (en dış kenar) sonuç 0 (incecik).
	// dist, expansion'dan 0.3 gerideyse (merkeze yakın) sonuç 1 (tam kalınlık).
	float growth_factor = smoothstep(expansion, expansion - 0.3, dist);
	
	// Dinamik Kalınlıklar
	// growth_factor ile çarparak, kenarlarda 0 kalınlık, merkezde tam kalınlık elde ediyoruz.
	float current_crack_width = crack_width * growth_factor;
	float current_glow_width = glow_width * growth_factor;
	
	// Sert Yuvarlak Kesim Maskesi (En dış sınır)
	float circle_mask = step(dist, expansion); 
	
	// 3. Çatlak Çizimi (Dinamik kalınlıklarla)
	// Dış Çatlak (Siyah Kısım)
	// +0.01 yumuşatma ekliyoruz ki piksellenmesin
	float outer_crack = 1.0 - smoothstep(current_crack_width, current_crack_width + 0.01, crack_raw);
	
	// İç Çatlak (Parlak Kısım)
	float inner_glow = 1.0 - smoothstep(current_glow_width, current_glow_width + 0.01, crack_raw);
	
	// Renkleri Karıştır
	vec3 final_color = mix(crack_base_color.rgb, crack_glow_color.rgb * 6.0, inner_glow); // Parlaklığı artırdım (*6.0)
	
	// Alpha Hesabı
	// Sadece çatlak var mı? * Dairenin içinde mi? * Silinmemiş mi?
	float final_alpha = outer_crack * circle_mask * (1.0 - fade);
	
	ALBEDO = final_color;
	ALPHA = final_alpha;
}