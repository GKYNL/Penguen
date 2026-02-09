extends Node

# Augment isimlerine göre sahneleri tutalım
var pool_templates = {
	"orbital_laser": preload("res://Scenes/VFX/OrbitalLaser.tscn"),
	"explosion": preload("res://Scenes/VFX/vfx_explosion.tscn"),
	"static_field": preload("res://Scenes/VFX/static_field.tscn"),
	"thunder": preload("res://Scenes/VFX/lightning.tscn")
}

var pools = {}

func _ready():
	# Her template için bir havuz oluştur
	for key in pool_templates:
		pools[key] = []
		_pre_fill_pool(key, 15) # Her birinden 15 tane hazırla

func _pre_fill_pool(key: String, amount: int):
	for i in range(amount):
		var vfx = pool_templates[key].instantiate()
		_return_to_pool(vfx, key)

func spawn_vfx(key: String, pos: Vector3):
	if not pools.has(key) or pools[key].is_empty():
		# Havuz boşsa yeni yarat (Acil durum)
		var vfx = pool_templates[key].instantiate()
		vfx.set_meta("pool_key", key)
		get_tree().root.add_child(vfx)
		vfx.global_position = pos
		_activate_vfx(vfx)
		return vfx
	
	var vfx = pools[key].pop_back()
	vfx.global_position = pos
	vfx.visible = true
	vfx.process_mode = Node.PROCESS_MODE_INHERIT
	_activate_vfx(vfx)
	return vfx

func _activate_vfx(vfx):
	# Partikülleri ateşle
	for child in vfx.find_children("*", "GPUParticles3D"):
		child.emitting = true
	for child in vfx.find_children("*", "CPUParticles3D"):
		child.emitting = true
	
	# Efekt süresi bitince geri dönsün (Örn: 2 saniye)
	var duration = 2.0 
	get_tree().create_timer(duration).timeout.connect(func(): _return_to_pool(vfx, vfx.get_meta("pool_key")))

func _return_to_pool(vfx, key):
	vfx.visible = false
	vfx.process_mode = Node.PROCESS_MODE_DISABLED
	vfx.global_position = Vector3(0, -100, 0) # Harita altına çek
	if not vfx.is_inside_tree():
		get_tree().root.add_child.call_deferred(vfx)
	vfx.set_meta("pool_key", key)
	pools[key].append(vfx)
