shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque;

uniform vec4 base_color : source_color = vec4(0.0, 0.5, 1.0, 1.0); // Buz Mavisi
uniform vec4 snow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Kar Beyazı
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float time_speed : hint_range(0.0, 5.0) = 1.0;

// Gürültü Dokusu (Noise Texture) - Editörden atayacağız
uniform sampler2D noise_tex : hint_default_black, filter_linear_mipmap, repeat_enable;

// Z-Fighting önlemek için hafif yukarı kaldır
void vertex() {
	VERTEX.y += 0.1;
}

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;
	
	// Polar Koordinatlar (Dönüş Efekti için)
	float angle = atan(uv.y, uv.x);
	
	// 1. Rüzgar Katmanı (Hızlı dönen)
	vec2 wind_uv = vec2(angle / 6.28 + TIME * 0.2 * time_speed, dist - TIME * 0.5);
	float wind_noise = texture(noise_tex, wind_uv).r;
	
	// 2. Kar Katmanı (Ters yöne yavaş dönen)
	vec2 snow_uv = vec2(angle / 6.28 - TIME * 0.1 * time_speed, dist - TIME * 0.2);
	float snow_noise = texture(noise_tex, snow_uv * 2.0).r; // Daha sık
	
	// Kar tanelerini belirginleştir
	float snow_flakes = smoothstep(0.6, 0.7, snow_noise);
	
	// Maskeleme (Kenarları yumuşat, ortayı del)
	// Ortası (oyuncu) boş olsun, kenarlara doğru azalsın
	float circle_mask = smoothstep(0.2, 0.4, dist) * (1.0 - smoothstep(0.8, 1.0, dist));
	
	// Renk Karışımı
	vec3 final_color = mix(base_color.rgb, snow_color.rgb * 2.0, snow_flakes);
	
	// Alpha
	float alpha = (wind_noise * 0.5 + snow_flakes) * circle_mask * intensity;
	
	ALBEDO = final_color;
	ALPHA = alpha;
}