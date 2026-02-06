shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque;

uniform vec4 mark_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float flash_speed = 10.0;

void vertex() {
	// Manuel Billboard Mantığı: 
	// Modelin rotasyonunu kameranın bakış açısına eşitliyoruz.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(INV_VIEW_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
	// Scale'i korumak için (0.5, 0.5, 0.5 gibi)
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

void fragment() {
	vec2 custom_uv = UV - 0.5;
	
	// "X" Şekli Çizimi
	float thickness = 0.1;
	float line1 = 1.0 - step(thickness, abs(custom_uv.x - custom_uv.y));
	float line2 = 1.0 - step(thickness, abs(custom_uv.x + custom_uv.y));
	float x_shape = max(line1, line2);
	
	// Yanıp sönme efekti
	float flash = abs(sin(TIME * flash_speed));
	
	ALBEDO = mark_color.rgb * 2.0;
	ALPHA = x_shape * flash;
}