extends Node3D

enum State { IDLE, FIRING, COOLDOWN }
var current_state = State.IDLE

# --- AYARLAR ---
var damage: float = 150.0
var fire_cooldown: float = 5.0
var beam_duration: float = 1.0
var beam_width: float = 1.0  # Daha kalın ve görünür
var beam_length: float = 20.0

var state_timer: float = 0.0
var is_active: bool = false
var enemies_hit: Array = []
var locked_transform: Transform3D

# DÜZENLENMİŞ HİYERARŞİ YOLLARI
@onready var pivot = get_node_or_null("BeamPivot")
@onready var area = get_node_or_null("BeamPivot/Area3D")
@onready var mesh = get_node_or_null("BeamPivot/MeshInstance3D")

func _ready():
	visible = false
	top_level = false
	
	# Sahne kontrolü
	if not pivot:
		print("❌ HATA: 'BeamPivot' isimli bir Node3D (child) oluşturmalısın!")
		return

	_setup_visuals()
	
	AugmentManager.mechanic_unlocked.connect(_on_mechanic_unlocked)
	if AugmentManager.mechanic_levels.has("prism_1"):
		_on_mechanic_unlocked("prism_1")

func _setup_visuals():
	if mesh:
		# Mesh'i Z eksenine (İleri) bakacak şekilde zorla ayarla
		mesh.rotation_degrees = Vector3(90, 0, 0)
		mesh.position = Vector3(0, 0, -beam_length / 2.0)
		if mesh.mesh is CylinderMesh:
			mesh.mesh.height = beam_length
			mesh.mesh.top_radius = 1.0
			mesh.mesh.bottom_radius = 1.0
		mesh.scale = Vector3(0, 1, 0) # X ve Z kalınlığı sıfır başla

	if area:
		area.monitoring = false
		area.position = Vector3(0, 0, -beam_length / 2.0)
		var shape = area.get_node_or_null("CollisionShape3D")
		if shape and shape.shape is CylinderShape3D:
			shape.shape.height = beam_length
			shape.shape.radius = 2.0 # Baz yarıçap
			shape.rotation_degrees = Vector3(90, 0, 0)

func _on_mechanic_unlocked(id):
	if id == "prism_1":
		_update_stats_from_json()
		is_active = true
		current_state = State.COOLDOWN
		state_timer = 2.0 

func _update_stats_from_json():
	var lvl = AugmentManager.mechanic_levels.get("prism_1", 1)
	for card in AugmentManager.tier_3_pool:
		if card.id == "prism_1":
			var data = card["levels"][lvl-1]
			damage = data.get("damage", 150.0)
			fire_cooldown = data.get("cooldown", 5.0)
			beam_duration = data.get("duration", 1.0)
			break

func _process(delta):
	if not is_active: return

	match current_state:
		State.COOLDOWN:
			state_timer -= delta
			if state_timer <= 0:
				_try_fire()
		
		State.FIRING:
			# ATEŞ EDERKEN DÜNYADA ÇAKILI KALMASI İÇİN GLOBAL TRANSFORMU KİLİTLE
			global_transform = locked_transform
			state_timer -= delta
			if state_timer <= 0:
				_stop_firing()

func _try_fire():
	var target = _find_nearest_enemy()
	if target:
		_start_firing(target)
	else:
		state_timer = 0.5 

func _start_firing(target):
	current_state = State.FIRING
	state_timer = beam_duration
	enemies_hit.clear()
	
	# 1. HEDEFLEME (Pivot üzerinden değil, root üzerinden look_at yapıyoruz)
	look_at(target.global_position, Vector3.UP)
	# 180 derece ters çıkıyorsa alttaki satırın başındaki '#' işaretini kaldır:
	# rotate_y(PI) 
	
	# 2. TRANSFORM KİLİTLE (Sen gitsen de lazer burada kalsın)
	locked_transform = global_transform
	
	visible = true
	if area: area.monitoring = true
	
	# 3. KALINLIK ANİMASYONU
	if mesh:
		var tw = create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		# Mesh yatık olduğu için X ve Z (genişlik) büyüyor
		tw.tween_property(mesh, "scale:x", beam_width, 0.2).from(0.0)
		tw.parallel().tween_property(mesh, "scale:z", beam_width, 0.2).from(0.0)
	
	_apply_instant_damage()

func _stop_firing():
	if area: area.monitoring = false
	
	if mesh:
		var tw = create_tween()
		tw.tween_property(mesh, "scale:x", 0.0, 0.15)
		tw.parallel().tween_property(mesh, "scale:z", 0.0, 0.15)
		# Atış bitince transformu sıfırla (Player'a geri dön)
		tw.finished.connect(func(): 
			visible = false
			transform = Transform3D.IDENTITY
			current_state = State.COOLDOWN
			state_timer = fire_cooldown
		)

func _apply_instant_damage():
	if area:
		for body in area.get_overlapping_bodies():
			_hit_enemy(body)

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
	if enemies.is_empty(): return null
	var nearest = null
	var min_dist = 99999.0
	for e in enemies:
		if is_instance_valid(e):
			var d = global_position.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				nearest = e
	return nearest
