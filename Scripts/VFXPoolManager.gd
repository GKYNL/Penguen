extends Node

# --- TEMPLATE TANIMLARI ---
var pool_templates = {
	# Temel Augmentler
	"explosion": preload("res://Scenes/VFX/vfx_explosion.tscn"),
	"static_field": preload("res://Scenes/VFX/static_field.tscn"),
	"thunder": preload("res://Scenes/VFX/lightning.tscn"),
	
	# Prism Yetenekleri
	"orbital_laser": preload("res://Scenes/VFX/OrbitalLaser.tscn"),
	"black_hole": preload("res://Scenes/VFX/vfx_black_hole.tscn"),
	"wind_dash": preload("res://Scenes/VFX/wind_walker.tscn"),
	"titan_stomp": preload("res://Scenes/VFX/VFXGroundCrack.tscn"),
	"eternal_winter": preload("res://Scenes/VFX/vfx_eternal_winter.tscn"),
	"time_stop": preload("res://Scenes/VFX/vfx_time_stop.tscn"),        # 2D (CanvasLayer)
	"dragon_breath": preload("res://Scenes/VFX/vfx_dragon_breath.tscn"), # 3D
	"mirror_image": preload("res://Scenes/VFX/vfx_mirror_clone.tscn"),   # 3D (CharacterBody)
	"godspeed": preload("res://Scenes/VFX/vfx_godspeed.tscn")            # 3D (Shader/Trail)
}

var pools = {} # Değişken adı pools

func _ready():
	for key in pool_templates:
		pools[key] = []
		# Sık kullanılanlar için havuzu geniş tut
		var count = 20 if (key == "wind_dash" or key == "titan_stomp" or key == "godspeed") else 10
		_pre_fill_pool(key, count)

func _pre_fill_pool(key: String, amount: int):
	if not pool_templates.has(key): return
	for i in range(amount):
		var vfx = pool_templates[key].instantiate()
		
		# GÖRÜNMEZ YAP
		vfx.visible = false
		vfx.process_mode = Node.PROCESS_MODE_DISABLED
		
		# Başlangıçta sahne ağacına eklemiyoruz, spawn anında eklenecek
		# Veya istersen burada ekleyip return_to_pool içinde çıkarabilirsin.
		# Şimdilik temiz bir başlangıç için havuzda bekletiyoruz.
		pools[key].append(vfx)

func spawn_vfx(key: String, pos: Vector3):
	if not pools.has(key):
		printerr("VFXPool: HATA! Key bulunamadi -> ", key)
		return null
		
	var vfx
	if pools[key].is_empty():
		vfx = pool_templates[key].instantiate()
		vfx.set_meta("pool_key", key)
	else:
		vfx = pools[key].pop_back()
	
	# HAYALET TEMİZLİĞİ: Önce sahneye ekle
	if not vfx.is_inside_tree():
		get_tree().root.add_child(vfx)
	
	# POZİSYON AYARI
	if vfx is Node3D:
		vfx.global_position = pos
	
	vfx.visible = true
	vfx.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Özel Başlatma Fonksiyonları
	if vfx.has_method("on_spawn"): vfx.on_spawn()
	elif vfx.has_method("start_effect"): vfx.start_effect()
	elif vfx.has_method("activate_effect"): vfx.activate_effect()
	elif vfx.has_method("play_effect"): vfx.play_effect(100.0)
	elif vfx.has_method("restart"): vfx.restart()
	
	_activate_particles(vfx)
	return vfx

func return_to_pool(obj: Node, type: String):
	if obj.has_method("on_return"):
		obj.on_return() # Lazer temizliğini tetikler
	
	obj.visible = false
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	
	# HAYALET TEMİZLİĞİ: Fizik dünyasından tamamen kopar
	if obj.get_parent():
		obj.get_parent().remove_child(obj)
	
	# DÜZELTME: pool yerine pools kullanıyoruz
	if not pools.has(type):
		pools[type] = []
	pools[type].append(obj)

func _activate_particles(vfx):
	for child in vfx.find_children("*", "GPUParticles3D"):
		child.restart(); child.emitting = true
	for child in vfx.find_children("*", "CPUParticles3D"):
		child.restart(); child.emitting = true
