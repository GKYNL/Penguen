extends Node3D

enum State { SPAWNING, FIRING, RETURNING }
var current_state = State.SPAWNING

# --- STATS ---
var damage: float = 150.0
var beam_duration: float = 0.8
var beam_width: float = 2.0  
var beam_length: float = 40.0 # Boyu buradan kısaltabilirsin

var state_timer: float = 0.0
var enemies_hit: Array = []
var locked_transform: Transform3D

# Referanslar (Sahnendeki node isimleri)
@onready var pivot = $BeamPivot
@onready var mesh = $BeamPivot/MeshInstance3D
@onready var area = $BeamPivot/Area3D
@onready var shape_node = $BeamPivot/Area3D/CollisionShape3D

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_PAUSABLE

func on_spawn():
	# 1. KONUMU ZORLA PLAYER'A EŞİTLE
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Player'ın tam göğüs hizası (Uzakta spawn olma hatasını bitirir)
		global_position = player.global_position + Vector3(0, 1.2, 0)
	
	visible = false
	enemies_hit.clear()
	_update_stats()
	
	# 2. SAHNEDEKİ MEVCUT OBJELERİ HİZALA (Reset)
	_reset_local_transforms()
	
	_try_fire()

func _reset_local_transforms():
	# Pivot merkezde
	pivot.position = Vector3.ZERO
	pivot.rotation = Vector3.ZERO
	
	# MESH: Yatay yap ve boyunu ayarla (Yeni mesh spawn etme!)
	mesh.rotation_degrees = Vector3(90, 0, 0)
	# Lazerin ucu player'dan başlasın diye uzunluğun yarısı kadar ileri kaydırıyoruz
	mesh.position = Vector3(0, 0, -beam_length / 2.0)
	mesh.scale = Vector3(0.01, beam_length / 2.0, 0.01) # Başlangıçta ince
	
	# COLLISION: Sahnedekini kullan, yenisini yaratma!
	if shape_node and shape_node.shape:
		shape_node.rotation_degrees = Vector3(90, 0, 0)
		area.position = Vector3(0, 0, -beam_length / 2.0)
		
		# Tip kontrolü yaparak boyutları senkronize et
		if shape_node.shape is CylinderShape3D:
			shape_node.shape.height = beam_length
			shape_node.shape.radius = beam_width / 2.0

func _update_stats():
	var lvl = AugmentManager.mechanic_levels.get("prism_1", 1)
	var pool = AugmentManager.tier_3_pool
	for card in pool:
		if card.id == "prism_1":
			var idx = clamp(lvl - 1, 0, card["levels"].size() - 1)
			damage = float(card["levels"][idx].get("damage", 150.0))
			beam_duration = float(card["levels"][idx].get("duration", 0.8))
			break

func _try_fire():
	var target = _find_nearest_enemy()
	# !v.is_finite() hatasını önlemek için mesafe kontrolü
	if target and global_position.distance_to(target.global_position) > 0.1:
		_start_firing(target)
	else:
		VFXPoolManager.return_to_pool(self, "orbital_laser")

func _start_firing(target):
	current_state = State.FIRING
	state_timer = beam_duration
	
	# Düşmana bak ama yere/havaya sapma (Y eksenini kitle)
	var aim_pos = target.global_position
	aim_pos.y = global_position.y 
	
	look_at(aim_pos, Vector3.UP)
	
	locked_transform = global_transform
	visible = true
	area.monitoring = true
	
	# Shader aktif et
	if mesh.material_override is ShaderMaterial:
		mesh.material_override.set_shader_parameter("active", true)
	
	# Büyüme Animasyonu (Sadece genişlik)
	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(mesh, "scale:x", beam_width, 0.1)
	tw.parallel().tween_property(mesh, "scale:z", beam_width, 0.1)
	
	_apply_instant_damage()

func _process(delta):
	if current_state == State.FIRING:
		global_transform = locked_transform # Titremeyi ve kaymayı engellemek için kilitle
		state_timer -= delta
		if state_timer <= 0:
			_stop_firing()

func _stop_firing():
	area.monitoring = false
	current_state = State.RETURNING
	
	var tw = create_tween()
	tw.tween_property(mesh, "scale:x", 0.0, 0.1)
	tw.parallel().tween_property(mesh, "scale:z", 0.0, 0.1)
	await tw.finished
	
	VFXPoolManager.return_to_pool(self, "orbital_laser")

func _apply_instant_damage():
	for body in area.get_overlapping_bodies():
		_hit_enemy(body)
	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if current_state == State.FIRING:
		_hit_enemy(body)

func _hit_enemy(body):
	if body.is_in_group("Enemies") and not body in enemies_hit:
		if body.has_method("take_damage"):
			body.take_damage(damage)
			enemies_hit.append(body)

func _find_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var nearest = null
	var min_dist = 9999.0
	for e in enemies:
		if is_instance_valid(e) and e.current_hp > 0:
			var d = global_position.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				nearest = e
	return nearest
