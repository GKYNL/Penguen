extends CanvasLayer

@onready var color_rect = $ColorRect

func _ready():
	# Başlangıçta görünmez olsun
	color_rect.material.set_shader_parameter("intensity", 0.0)
	
	# BU ÇOK ÖNEMLİ:
	# Oyun dursa bile bu efektin çalışması lazım.
	process_mode = Node.PROCESS_MODE_ALWAYS

func play_effect(duration: float):
	var mat = color_rect.material as ShaderMaterial
	
	# 1. Giriş (Hızlıca Griye Dön)
	var tw = create_tween()
	tw.tween_method(func(v): mat.set_shader_parameter("intensity", v), 0.0, 1.0, 0.2).set_ease(Tween.EASE_OUT)
	
	# 2. Bekle (Zamanın durduğu süre)
	tw.tween_interval(duration)
	
	# 3. Çıkış (Normale Dön)
	tw.tween_method(func(v): mat.set_shader_parameter("intensity", v), 1.0, 0.0, 0.5).set_ease(Tween.EASE_IN)
