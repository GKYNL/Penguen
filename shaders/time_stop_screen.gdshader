shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0; // 0: Normal, 1: Tam Zaman Durması
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 screen_col = texture(screen_texture, SCREEN_UV);
	
	// Gri Tonlama (Grayscale) Formülü
	float gray = dot(screen_col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grayscale_col = vec3(gray);
	
	// Hafif Mavimsi/Mor bir ton atalım (Zaman durma klasiği)
	vec3 frozen_col = grayscale_col * vec3(0.8, 0.9, 1.2); 
	
	// Normal renk ile Donmuş rengi karıştır
	vec3 final_col = mix(screen_col.rgb, frozen_col, intensity);
	
	// Renkleri biraz patlat (Contrast)
	COLOR.rgb = final_col;
}