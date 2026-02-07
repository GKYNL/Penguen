extends MeshInstance3D
class_name VFXSpellWeaver

var current_level: int = 1
var shader_path = "res://shaders/spell_weaver.gdshader"

func _ready():
	# 1. Mesh ve Material Kurulumu (Otomatik)
	if not mesh:
		mesh = PlaneMesh.new()
		mesh.size = Vector2(3.0, 3.0)
	
	if not material_override:
		var mat = ShaderMaterial.new()
		var shader = load(shader_path)
		if shader:
			mat.shader = shader
		else:
			push_error("Spell Weaver Shader bulunamadı!")
		material_override = mat
	
	# Başlangıç ayarı (Yerde z-fighting olmasın)
	position = Vector3(0, 0.1, 0)
	
	# İlk açılış animasyonu
	scale = Vector3.ZERO
	_animate_scale_up()

func set_level(lv: int):
	current_level = lv
	_update_visuals()

func _update_visuals():
	var mat = material_override as ShaderMaterial
	if not mat: return
	
	# Hız ve Parlaklık (Level arttıkça coşsun)
	var new_speed = 3.0 + (current_level * 0.8)
	var new_intensity = 20.0 + (current_level * 2.0)
	
	mat.set_shader_parameter("speed", new_speed)
	mat.set_shader_parameter("intensity", new_intensity)
	
	# Renk değişimi (Level 4'te daha koyu mor/kırmızı)
	if current_level >= 4:
		mat.set_shader_parameter("albedo", Color(0.9, 0.0, 0.5, 1.0))
	
	_animate_scale_up()

func _animate_scale_up():
	# Hedef boyut (Level başına %20 büyü)
	var target_size = 7.0 + (current_level * 0.2)
	var target_vec = Vector3(target_size, 1.0, target_size)
	
	# Tween ile "POP" efekti
	var tw = create_tween()
	tw.tween_property(self, "scale", target_vec, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
