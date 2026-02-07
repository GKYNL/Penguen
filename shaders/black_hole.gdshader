shader_type spatial;
// ÖNCEKİ TAKTİK: Işık yok, Ters yüzey yok, Derinlik testi var
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque;

uniform vec4 core_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Merkez (Siyah)
uniform vec4 edge_color : source_color = vec4(0.5, 0.0, 1.0, 1.0); // Kenar Enerjisi (Mor)
uniform float swirl_strength : hint_range(0.0, 10.0) = 3.0; // Dönüş bükülmesi
uniform float time_speed : hint_range(0.0, 5.0) = 1.0; // Dönüş hızı
uniform float hole_size : hint_range(0.0, 1.0) = 0.3; // Siyah deliğin boyutu
uniform float fade_edge : hint_range(0.0, 1.0) = 0.5; // Dış kenar yumuşaklığı

// Girdap dokusu (Noise Texture atayacağız)
uniform sampler2D swirl_noise : hint_default_black, filter_linear_mipmap, repeat_enable;

// GÖRÜNMEZLİK SORUNU ÇÖZÜCÜ
void vertex() {
	VERTEX.y += 0.2; // Yeri delmemesi için 20cm yukarı kaldırıyoruz
}

void fragment() {
	vec2 centered_uv = UV - 0.5;
	float dist = length(centered_uv) * 2.0; // 0 (merkez) -> 1 (kenar)
	
	// --- POLAR KOORDİNATLAR (GİRDAP MATEMATİĞİ) ---
	float angle = atan(centered_uv.y, centered_uv.x);
	
	// Açıyı mesafeye göre bük (Merkez daha hızlı döner)
	// TIME ile animasyon katıyoruz
	float spiral_angle = angle + (swirl_strength / (dist + 0.1)) - (TIME * time_speed);
	
	// Yeni UV koordinatlarını oluştur (Polar -> Cartesian)
	// x: Dönüş açısı, y: Merkeze uzaklık
	vec2 polar_uv = vec2(spiral_angle / 6.28, dist);
	
	// Noise dokusunu bu bükülmüş koordinatlarla oku
	float noise_val = texture(swirl_noise, polar_uv).r;
	
	// --- RENKLENDİRME ---
	// Olay Ufku (Merkezdeki Siyahlık)
	// smoothstep ile keskin ama hafif yumuşak bir geçiş yapıyoruz
	float black_hole_mask = smoothstep(hole_size, hole_size + 0.05, dist);
	
	// Kenar Enerjisi
	// Noise değerini kullanarak enerjik bir halka oluştur
	vec3 energy = edge_color.rgb * noise_val * 2.0; // *2 ile parlat
	
	// Birleştir: Merkez siyah, dışarısı renkli
	vec3 final_color = mix(core_color.rgb, energy, black_hole_mask);
	
	// --- ALPHA / MASKİNG ---
	// 1. Dış kenarları yumuşat (Kare olmasın, yuvarlak olsun)
	float circle_mask = 1.0 - smoothstep(1.0 - fade_edge, 1.0, dist);
	
	// 2. Merkezdeki siyahlık tam opak olsun, enerji kısmı noise'a göre şeffaflaşsın
	float alpha_noise = mix(1.0, noise_val * 1.5, black_hole_mask);
	
	ALBEDO = final_color;
	ALPHA = circle_mask * alpha_noise;
}