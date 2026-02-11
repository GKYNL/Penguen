extends CharacterBody3D

enum EnemyType { MELEE, ARCHER }

const STAGE_COLORS := {
	1: Color.DARK_GOLDENROD, 2: Color.GREEN, 3: Color.BLUE,
	4: Color.PURPLE, 5: Color.ORANGE, 6: Color.RED, 7: Color.BLACK
}
const FROZEN_COLOR := Color(0.267, 0.655, 1.0, 1.0)

# --- SİNYALLER ---
signal returned_to_pool(enemy_node)

# --- REFERANSLAR ---
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var player = get_tree().get_first_node_in_group("player")
@onready var execution_mark = get_node_or_null("ExecutionMark")

# --- AUGMENT SAHNELERİ ---
@export var explosion_vfx_scene: PackedScene 
@export var xp_orb_scene: PackedScene 
@export var projectile_scene: PackedScene 

# --- STATLAR ---
var max_hp := 30.0
var current_hp := 30.0
var damage := 10.0
var xp_reward := 100
var movement_speed: float = 6.5 
@export var attack_range: float = 2.5
@export var attack_cooldown: float = 1.0

# --- DURUM ---
var is_elite := false
var is_frozen := false
var is_dying := false
var can_attack := true
var type: EnemyType = EnemyType.MELEE
var current_slow_factor: float = 0.0

var logic_timer: Timer
var slow_timer: Timer
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var stage: int = 1: 
	set(value):
		stage = clamp(value, 1, 7)
		if is_inside_tree():
			setup_stats_by_stage()
			update_visuals()

func _ready():
	add_to_group("Enemies")
	
	# FIX: Execution mark başlangıçta kesinlikle gizli olmalı
	if execution_mark: 
		execution_mark.hide()
		execution_mark.scale = Vector3.ONE 
	
	logic_timer = Timer.new()
	logic_timer.wait_time = 0.1
	logic_timer.timeout.connect(_on_logic_tick)
	add_child(logic_timer)
	
	slow_timer = Timer.new()
	slow_timer.one_shot = true
	add_child(slow_timer)
	slow_timer.timeout.connect(func(): current_slow_factor = 0.0)

func _physics_process(delta):
	if is_dying or is_frozen: 
		velocity = Vector3.ZERO
		return
	if not is_on_floor(): 
		velocity.y -= gravity * delta * 4.0
	else:
		velocity.y = 0
	move_and_slide()

func _on_logic_tick():
	if is_dying or is_frozen or !is_instance_valid(player): return
	var diff = player.global_position - global_position
	diff.y = 0
	var dist = diff.length()
	var dir = diff.normalized()

	var final_speed = movement_speed * (1.0 - current_slow_factor)
	final_speed = max(0.5, final_speed)

	var target_radius = 0.5 
	if player.scale.x > 1.0:
		target_radius *= player.scale.x 
	
	var effective_attack_range = attack_range + target_radius 

	if type == EnemyType.ARCHER:
		var keep_dist = 12.0
		if dist > keep_dist + 1.5:
			velocity.x = dir.x * final_speed
			velocity.z = dir.z * final_speed
		elif dist < keep_dist - 1.5:
			velocity.x = -dir.x * final_speed * 0.5
			velocity.z = -dir.z * final_speed * 0.5
		else:
			velocity.x = 0; velocity.z = 0
		if can_attack and dist <= 18.0: shoot_at_player()
	else:
		if dist <= effective_attack_range:
			velocity.x = 0; velocity.z = 0
			attack_player()
		else:
			velocity.x = dir.x * final_speed
			velocity.z = dir.z * final_speed

	if velocity.length() > 0.1:
		var look_target = global_position + dir
		if global_position.distance_to(look_target) > 0.1:
			look_at(look_target, Vector3.UP)

# --- HASAR & ÖLÜM ---
func take_damage(amount: float):
	if is_dying: return
	current_hp -= amount
	_show_damage_numbers(amount, Color.WHITE)
	
	# FIX: GOLD_4 (Executioner) Kontrolü
	if AugmentManager.mechanic_levels.has("gold_4"):
		var threshold = AugmentManager.player_stats.get("execution_threshold", 0.15)
		# Can %15'in altındaysa ve ölmediyse idam et
		if current_hp > 0 and current_hp <= max_hp * threshold:
			_execute_enemy()
			return
			
	if current_hp <= 0: die()

func _execute_enemy():
	if is_dying: return
	
	# Görsel Efekt (Sadece öldürürken görünür)
	if execution_mark: 
		execution_mark.show()
		execution_mark.scale = Vector3.ZERO
		var tw = create_tween()
		tw.tween_property(execution_mark, "scale", Vector3.ONE * 1.5, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	_show_damage_numbers(9999, Color.RED) 
	die()

func die():
	is_dying = true
	current_hp = 0
	collision_layer = 0
	collision_mask = 0
	logic_timer.stop()
	

	
	# --- VAMPIRISM (Gold 1) ---
	if AugmentManager.mechanic_levels.has("gold_1"):
		var p = get_tree().get_first_node_in_group("player")
		if p and p.has_method("heal"):
			p.heal(2.0)

	var wm = get_tree().get_first_node_in_group("weapon_manager")
	if wm and wm.has_method("on_enemy_killed"): wm.on_enemy_killed(self)
	
	# XP Orb
	if xp_orb_scene:
		var orb = xp_orb_scene.instantiate()
		get_tree().root.add_child(orb)
		orb.global_position = global_position + Vector3(0, 0.5, 0)
		if "xp_value" in orb: orb.xp_value = xp_reward
		
	# Ölüm Animasyonu
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.25).set_ease(Tween.EASE_IN)
	tw.finished.connect(_send_to_underworld)
	
	
	for label in get_tree().get_nodes_in_group("damage_labels"):
		if label.get_meta("owner_id", "") == str(get_instance_id()):
			label.queue_free()
	
	collision_layer = 0
	collision_mask = 0

func _send_to_underworld():
	# Havuza dönmeden önce üzerindeki efektleri temizle
	if execution_mark: execution_mark.hide()
	
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	global_position = Vector3(0, -50, 0) 
	emit_signal("returned_to_pool", self) 

# --- RE-SETUP (HAVUZDAN ÇIKARKEN) ---
func reset_for_spawn():
	is_dying = false
	is_frozen = false
	can_attack = true
	current_slow_factor = 0.0
	
	# FIX: Yeni doğan düşmanda Execution Mark GİZLİ olmalı
	if execution_mark: 
		execution_mark.hide()
		execution_mark.scale = Vector3.ONE
	
	scale = Vector3(0.01, 0.01, 0.01) 
	
	visible = true
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 2
	collision_mask = 7
	
	if logic_timer:
		logic_timer.start()

	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector3.ONE, 0.4)
	
	update_visuals()

# --- DİĞER FONKSİYONLAR ---
func setup_stats_by_stage():
	max_hp = 25.0 * stage; damage = 8.0 * stage; xp_reward = 45 * stage
	if is_elite: max_hp *= 4.0; damage *= 1.5; xp_reward *= 5
	current_hp = max_hp

func update_visuals():
	if not mesh: return
	var mat := StandardMaterial3D.new()
	if is_frozen:
		mat.albedo_color = FROZEN_COLOR
		mat.emission_enabled = true; mat.emission = FROZEN_COLOR * 2.0
	else:
		var color :Color = STAGE_COLORS.get(stage, Color.WHITE)
		mat.albedo_color = color
		if is_elite: mat.emission_enabled = true; mat.emission = color * 2.0
		if type == EnemyType.ARCHER: mesh.scale = Vector3(0.7, 1.3, 0.7)
	mesh.material_override = mat

func attack_player():
	if not can_attack or is_frozen or !is_instance_valid(player): return
	can_attack = false
	if player.has_method("take_damage"): player.take_damage(damage)
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func shoot_at_player():
	if not can_attack or is_frozen or !projectile_scene or !is_instance_valid(player): return
	can_attack = false
	var proj = projectile_scene.instantiate()
	get_tree().root.add_child(proj)
	proj.global_position = global_position + Vector3(0, 1.5, 0)
	proj.damage = damage
	proj.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _show_damage_numbers(value, color):
	var label = Label3D.new()
	get_tree().root.add_child(label)
	label.add_to_group("damage_labels")
	label.set_meta("owner_id", str(get_instance_id())) # Kimin yazısı olduğunu işaretle
	
	label.global_position = global_position + Vector3(0, 2.0, 0)
	label.text = str(int(value))
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(label, "global_position:y", label.global_position.y + 2.0, 0.4)
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(label.queue_free)
