extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var za_warudo_sound_effect: AudioStreamPlayer = $ZaWarudoSoundEffect


func _ready():
	# Başlangıçta görünmez (Normal ekran)
	color_rect.material.set_shader_parameter("intensity", 0.0)
	
	# BU ÇOK ÖNEMLİ:
	# Oyun dursa bile bu efektin çalışması lazım ki grileşmeyi görebilelim.
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_effect():
	# Giriş (Hızlıca Griye Dön)
	za_warudo_sound_effect.play(0.0)
	var mat = color_rect.material as ShaderMaterial
	var tw = create_tween()
	tw.tween_method(func(v): mat.set_shader_parameter("intensity", v), 0.0, 1.0, 0.2).set_ease(Tween.EASE_OUT)

func stop_effect():
	# Çıkış (Normale Dön)
	var mat = color_rect.material as ShaderMaterial
	var tw = create_tween()
	tw.tween_method(func(v): mat.set_shader_parameter("intensity", v), 1.0, 0.0, 0.5).set_ease(Tween.EASE_IN)
	# Tween bitince yok etmeye gerek yok, sahnede kalsın tekrar kullanılır.
