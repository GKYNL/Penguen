shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform float expansion : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
    // Yankı hissi için mor renk
    ALBEDO = vec3(0.6, 0.0, 1.0) * 2.0;
    ALPHA = fresnel * (1.0 - expansion);
}