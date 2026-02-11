extends Node

# --- TEMPLATE TANIMLARI ---
var pool_templates = {
	# Temel Augmentler
	"orbital_laser": preload("res://Scenes/VFX/OrbitalLaser.tscn"),
	"explosion": preload("res://Scenes/VFX/vfx_explosion.tscn"),
	"static_field": preload("res://Scenes/VFX/static_field.tscn"),
	"thunder": preload("res://Scenes/VFX/lightning.tscn"),
	
	# Prism Yetenekleri
	"black_hole": preload("res://Scenes/VFX/vfx_black_hole.tscn"),
	"wind_dash": preload("res://Scenes/VFX/wind_walker.tscn"),
	"titan_stomp": preload("res://Scenes/VFX/VFXGroundCrack.tscn"),
	"eternal_winter": preload("res://Scenes/VFX/vfx_eternal_winter.tscn"),
	
	# YENİ EKLENENLER (Son 3 Prism)
	"time_stop": preload("res://Scenes/VFX/vfx_time_stop.tscn"),       # 2D (CanvasLayer)
	"dragon_breath": preload("res://Scenes/VFX/vfx_dragon_breath.tscn"), # 3D
	"mirror_image": preload("res://Scenes/VFX/vfx_mirror_clone.tscn"),   # 3D (CharacterBody)
	"godspeed": preload("res://Scenes/VFX/vfx_godspeed.tscn")            # 3D (Shader/Trail)
}

var pools = {}

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
		
		# GÖRÜNMEZ YAP (Pozisyona dokunma, Tree hatasını önler)
		vfx.visible = false
		vfx.process_mode = Node.PROCESS_MODE_DISABLED
		
		# Sahneye eklemeyi sıraya al (Güvenli Yöntem)
		get_tree().root.call_deferred("add_child", vfx)
		
		pools[key].append(vfx)

func spawn_vfx(key: String, pos: Vector3):
	if not pools.has(key):
		printerr("VFXPool: HATA! Key bulunamadi -> ", key)
		return null
		
	var vfx
	if pools[key].is_empty():
		# Havuz boşsa acil durum üretimi
		vfx = pool_templates[key].instantiate()
		vfx.set_meta("pool_key", key)
		get_tree().root.add_child(vfx) 
	else:
		vfx = pools[key].pop_back()
	
	# SAHNE KONTROLÜ (Eğer call_deferred henüz eklemediyse)
	if not vfx.is_inside_tree():
		if vfx.get_parent() == null:
			get_tree().root.add_child(vfx)
	
	# --- POZİSYON AYARI ---
	# Sadece Node3D türevi olanlara (3D objeler) pozisyon veriyoruz.
	# CanvasLayer (Time Stop) veya Control node'larına pozisyon verilmez.
	if vfx is Node3D:
		if vfx.is_inside_tree():
			vfx.global_position = pos
		else:
			vfx.position = pos
	
	vfx.visible = true
	vfx.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Özel Başlatma Fonksiyonları
	if vfx.has_method("on_spawn"): vfx.on_spawn()
	elif vfx.has_method("start_effect"): vfx.start_effect()
	elif vfx.has_method("activate_effect"): vfx.activate_effect() # Godspeed için
	elif vfx.has_method("play_effect"): vfx.play_effect(100.0)
	elif vfx.has_method("restart"): vfx.restart()
	
	_activate_particles(vfx)
	return vfx

func return_to_pool(vfx, key: String = ""):
	_return_to_pool(vfx, key)

func _return_to_pool(vfx, key: String = ""):
	if key == "":
		if vfx.has_meta("pool_key"): key = vfx.get_meta("pool_key")
		else: vfx.queue_free(); return

	# Sahnede değilse sadece listeye ekle
	if not vfx.is_inside_tree():
		pools[key].append(vfx)
		return

	vfx.visible = false
	vfx.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Yer altına sakla (Sadece Node3D ise)
	if vfx is Node3D:
		vfx.global_position = Vector3(0, -500, 0)
	
	pools[key].append(vfx)

func _activate_particles(vfx):
	for child in vfx.find_children("*", "GPUParticles3D"):
		child.restart(); child.emitting = true
	for child in vfx.find_children("*", "CPUParticles3D"):
		child.restart(); child.emitting = true
