shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;

uniform vec4 color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float speed_lines : hint_range(0.0, 20.0) = 10.0;
uniform float transparency : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	// Vertexleri rüzgar gibi titret
	float wave = sin(VERTEX.z * 2.0 + TIME * 20.0) * 0.1;
	VERTEX.x += wave * UV.y; 
}

void fragment() {
	// Çizgili rüzgar efekti
	float lines = sin((UV.x * speed_lines) + (TIME * -30.0));
	lines = smoothstep(0.4, 0.6, lines);
	
	// Uçlara doğru şeffaflaşsın
	float alpha_fade = 1.0 - UV.y; 
	
	ALBEDO = color.rgb;
	ALPHA = lines * alpha_fade * transparency * color.a;
}