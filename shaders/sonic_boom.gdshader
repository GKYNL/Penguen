shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 shock_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float power : hint_range(0.0, 1.0) = 0.0; 

void vertex() {
	// Koniyi ileri geri titret
	float boom = sin(TIME * 50.0) * 0.05 * power;
	// VERTEX (Değişken) büyük, vertex (Fonksiyon) küçük
	VERTEX += NORMAL * boom;
}

void fragment() {
	// Fresnel etkisi
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
	
	// Aşağıdan yukarıya gradient
	float fade = 1.0 - UV.y;
	
	ALBEDO = shock_color.rgb;
	ALPHA = (fresnel + 0.2) * fade * power * shock_color.a;
}