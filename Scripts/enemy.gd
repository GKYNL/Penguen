extends CharacterBody3D

# Düşman Tipleri
enum Type { FODDER = 0, TANK = 1, ARCHER = 2 }

# Görsel Ayarlar (Renkler)
const COLOR_FODDER = Color(0.9, 0.3, 0.3)
const COLOR_TANK = Color(0.2, 0.7, 0.2)
const COLOR_ARCHER = Color(0.9, 0.6, 0.1)
const COLOR_ELITE = Color(0.6, 0.2, 0.9)
const FROZEN_COLOR = Color(0.3, 0.7, 1.0)
const GLOW_INTENSITY = 3.0

# Temel Değişkenler
var my_type: int = Type.FODDER
var is_elite: bool = false
var is_dying: bool = false
var is_frozen: bool = false

# Statlar
var max_hp: float = 30.0
var current_hp: float = 30.0
var damage: float = 10.0
var speed: float = 6.0
var xp_reward: int = 10 # DÜZELTME: Değişken adı xp_reward yapıldı

# Okçu & Saldırı
var attack_range: float = 2.0
var shoot_cooldown: float = 0.0
var can_attack: bool = true

# Referanslar
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var player = get_tree().get_first_node_in_group("player")
@export var projectile_scene: PackedScene 
@export var xp_orb_scene: PackedScene 

var active_labels: Array[Label3D] = []

func _ready():
	add_to_group("Enemies")

# --- SPAWNER İÇİN KOMUT SETİ ---

func setup_standard(type_id: int, hp_mod: float, spd_mod: float):
	cleanup()
	is_elite = false
	is_frozen = false
	is_dying = false
	my_type = type_id
	scale = Vector3.ONE
	
	match my_type:
		Type.FODDER:
			max_hp = 30.0 * hp_mod
			speed = 7.0 * spd_mod
			damage = 10.0
			attack_range = 2.0
			xp_reward = 10 # DÜZELTİLDİ
		Type.TANK:
			max_hp = 90.0 * hp_mod
			speed = 4.5 * spd_mod
			damage = 25.0
			attack_range = 2.5
			xp_reward = 30 # DÜZELTİLDİ
			scale = Vector3.ONE * 1.4
		Type.ARCHER:
			max_hp = 40.0 * hp_mod
			speed = 6.0 * spd_mod
			damage = 15.0
			attack_range = 14.0
			xp_reward = 20 # DÜZELTİLDİ
			scale = Vector3(0.8, 1.2, 0.8)
	
	current_hp = max_hp
	_update_visuals()
	reset_physics()

func setup_elite(hp_mod: float, spd_mod: float):
	cleanup()
	is_elite = true
	is_frozen = false
	is_dying = false
	my_type = Type.TANK 
	
	scale = Vector3.ONE * 2.2
	max_hp = 400.0 * hp_mod
	speed = 5.5 * spd_mod
	damage = 40.0
	attack_range = 3.5
	xp_reward = 500 # DÜZELTİLDİ
	
	current_hp = max_hp
	_update_visuals()
	reset_physics()

func reset_physics():
	collision_layer = 2
	collision_mask = 7 
	show()
	process_mode = Node.PROCESS_MODE_PAUSABLE

func cleanup():
	for l in active_labels: if is_instance_valid(l): l.queue_free()
	active_labels.clear()

# --- OYUN MANTIĞI ---

func _physics_process(delta):
	if is_dying or is_frozen: return
	if not is_instance_valid(player): return
	
	if not is_on_floor(): velocity.y -= 9.8 * delta
	
	var dist = global_position.distance_to(player.global_position)
	var dir = (player.global_position - global_position).normalized()
	dir.y = 0
	
	if my_type == Type.ARCHER:
		_behavior_archer(dist, dir, delta)
	else:
		_behavior_melee(dist, dir, delta)
	
	move_and_slide()
	
	if velocity.length() > 0.1:
		var target = global_position + dir
		if global_position.distance_to(target) > 0.1:
			look_at(target, Vector3.UP)

func _behavior_melee(dist, dir, _delta):
	if dist > attack_range:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = 0; velocity.z = 0
		_attempt_attack()

func _behavior_archer(dist, dir, delta):
	shoot_cooldown -= delta
	if dist < 8.0:
		velocity.x = -dir.x * speed * 0.8
		velocity.z = -dir.z * speed * 0.8
	elif dist > attack_range:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = 0; velocity.z = 0
		
	if dist <= attack_range and shoot_cooldown <= 0:
		_shoot_projectile()

func _attempt_attack():
	if player.has_method("take_damage"):
		player.take_damage(damage * get_physics_process_delta_time())

func _shoot_projectile():
	if not projectile_scene: return
	shoot_cooldown = 2.0
	var proj = projectile_scene.instantiate()
	get_tree().root.add_child(proj)
	proj.global_position = global_position + Vector3(0, 1.5, 0)
	proj.damage = damage
	proj.process_mode = Node.PROCESS_MODE_PAUSABLE
	var target_pos = player.global_position + Vector3(0, 1.0, 0)
	proj.look_at(target_pos, Vector3.UP)

# --- HASAR ---

func take_damage(amount):
	if is_dying: return
	current_hp -= amount
	_spawn_damage_text(amount)
	
	if current_hp <= 0:
		die()

func die():
	# XP Yarat (Buradaki hata çözüldü)
	if xp_orb_scene:
		var xp = xp_orb_scene.instantiate()
		get_tree().root.add_child(xp)
		xp.global_position = global_position
		# Orb'un içindeki değişkene (xp_value), bizim değişkeni (xp_reward) ata
		if "xp_value" in xp: xp.xp_value = xp_reward 
	
	cleanup()
	var spawner = get_tree().get_first_node_in_group("enemy_spawner")
	if spawner and spawner.has_method("_return_to_pool"):
		spawner._return_to_pool(self)
	else:
		queue_free()

func _spawn_damage_text(amount):
	if not has_node("Label3D"): return
	var lbl = $Label3D.duplicate()
	get_tree().root.add_child(lbl)
	lbl.global_position = global_position + Vector3(0, 2.5, 0)
	lbl.text = str(int(amount))
	lbl.show()
	active_labels.append(lbl)
	
	var tw = create_tween()
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y + 1.5, 0.5)
	tw.tween_callback(func(): 
		if is_instance_valid(lbl): lbl.queue_free()
		active_labels.erase(lbl)
	)

func _update_visuals():
	if not mesh: return
	var mat = StandardMaterial3D.new()
	if is_frozen:
		mat.albedo_color = FROZEN_COLOR
		mat.emission_enabled = true
		mat.emission = FROZEN_COLOR
	elif is_elite:
		mat.albedo_color = COLOR_ELITE
		mat.emission_enabled = true
		mat.emission = COLOR_ELITE * GLOW_INTENSITY
	else:
		match my_type:
			Type.FODDER: mat.albedo_color = COLOR_FODDER
			Type.TANK: mat.albedo_color = COLOR_TANK
			Type.ARCHER: mat.albedo_color = COLOR_ARCHER
	mesh.material_override = mat

func apply_freeze(duration):
	if is_elite: return
	is_frozen = true
	_update_visuals()
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		is_frozen = false
		_update_visuals()
