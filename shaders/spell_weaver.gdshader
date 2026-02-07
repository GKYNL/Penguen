shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(0.5, 0.0, 1.0, 1.0); // Prismatic Moru
uniform float speed : hint_range(0.0, 5.0) = 1.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
// uniform sampler2D rune_texture; // Kullanmıyorsan yorum satırına al veya sil

void vertex() {
	// Billboard efekti için (Yere yapışık kalmasını istiyorsan burayı boş bırak)
	// MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;
	float angle = atan(uv.y, uv.x);
	
	// Dönme Efekti
	float rotation = TIME * speed;
	
	// DÜZELTME: (TIME * 2.0) yerine 'rotation' değişkenini koyduk.
	// Artık 'speed' parametresini değiştirdiğinde dönüş hızı da değişecek.
	float spiral = sin(dist * 10.0 - rotation + angle * 5.0);
	
	// Halka Şekli
	float ring = 1.0 - smoothstep(0.4, 0.5, dist);
	float inner_hole = smoothstep(0.2, 0.3, dist);
	float shape = ring * inner_hole;
	
	// Enerji dalgalanması
	float pulse = 0.5 + 0.5 * sin(TIME * 3.0);
	
	vec3 color = albedo.rgb * (1.0 + spiral * 0.5);
	
	ALBEDO = color * intensity;
	ALPHA = shape * (0.6 + pulse * 0.4) * albedo.a;
}