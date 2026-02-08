extends CharacterBody3D

enum EnemyType { MELEE, ARCHER }

const STAGE_COLORS := {
	1: Color.DARK_GOLDENROD, 2: Color.GREEN, 3: Color.BLUE,
	4: Color.PURPLE, 5: Color.ORANGE, 6: Color.RED, 7: Color.BLACK
}
const FROZEN_COLOR := Color(0.267, 0.655, 1.0, 1.0)

var is_dying: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var player = get_tree().get_first_node_in_group("player")
@onready var execution_mark = get_node_or_null("ExecutionMark")

var logic_timer: Timer

@export var explosion_vfx_scene: PackedScene 
@export var xp_orb_scene: PackedScene 
@export var projectile_scene: PackedScene 
@export var movement_speed: float = 6.5 
@export var attack_range: float = 2.5
@export var attack_cooldown: float = 1.0
@export var stage: int = 1: 
	set(value):
		stage = clamp(value, 1, 7)
		if is_inside_tree():
			setup_stats_by_stage()
			update_visuals()

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var max_hp := 30.0
var current_hp := 30.0
var damage := 10.0
var xp_reward := 100
var is_elite := false
var is_frozen := false
var can_attack := true
var type: EnemyType = EnemyType.MELEE

# Yavaşlatma Değişkenleri
var current_slow_factor: float = 0.0
var slow_timer: Timer

func _ready():
	add_to_group("Enemies")
	setup_stats_by_stage()
	update_visuals()
	if execution_mark: execution_mark.hide()
	
	logic_timer = Timer.new()
	add_child(logic_timer)
	logic_timer.wait_time = 0.1
	logic_timer.timeout.connect(_on_logic_tick)
	logic_timer.start()
	
	# Slow reset timer
	slow_timer = Timer.new()
	slow_timer.one_shot = true
	add_child(slow_timer)
	slow_timer.timeout.connect(func(): current_slow_factor = 0.0)

func _physics_process(delta):
	if current_hp <= 0 or is_dying or is_frozen: 
		velocity = Vector3.ZERO
		return
	if not is_on_floor(): 
		velocity.y -= gravity * delta * 4.0
	else:
		velocity.y = 0
	move_and_slide()

func _on_logic_tick():
	if is_dying or is_frozen or player == null: return
	var diff = player.global_position - global_position
	diff.y = 0
	var dist = diff.length()
	var dir = diff.normalized()

	# HIZ HESABI: Yavaşlatma faktörünü uygula
	var final_speed = movement_speed * (1.0 - current_slow_factor)

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
		if dist <= attack_range:
			velocity.x = 0; velocity.z = 0
			attack_player()
		else:
			velocity.x = dir.x * final_speed
			velocity.z = dir.z * final_speed

	if velocity.length() > 0.1:
		var look_target = global_position + dir
		if global_position.distance_to(look_target) > 0.1:
			look_at(look_target, Vector3.UP)

func apply_slow(amount: float, duration: float):
	if is_elite: amount *= 0.5 
	if amount > current_slow_factor:
		current_slow_factor = amount
	slow_timer.start(duration)

func take_damage(dmg: float):
	if current_hp <= 0 or is_dying: return
	
	var final_dmg = dmg
	_show_damage_numbers(final_dmg, Color.WHITE)
	current_hp -= final_dmg
	
	if AugmentManager.mechanic_levels.has("gold_3"):
		var threshold = AugmentManager.player_stats.get("execution_threshold", 0.0)
		if current_hp > 0 and current_hp <= max_hp * threshold:
			_execute_enemy()
			return

	if current_hp <= 0: 
		pre_die()

func _show_damage_numbers(amount: float, color: Color = Color.WHITE):
	if not has_node("Label3D"): return
	var label = $Label3D.duplicate()
	add_child(label)
	label.show()
	label.text = str(ceil(amount))
	label.modulate = color
	
	var random_x = randf_range(-1.0, 1.0)
	label.position = Vector3(random_x, 2.0, 0)
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", 4.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position:x", random_x * 2.0, 0.5)
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tw.finished.connect(label.queue_free)

func _execute_enemy():
	if is_dying: return
	is_dying = true
	current_hp = 0
	
	if execution_mark: 
		execution_mark.show()
		var tw = create_tween()
		tw.tween_property(execution_mark, "scale", Vector3.ONE * 2.0, 0.1)
		tw.tween_property(execution_mark, "scale", Vector3.ONE, 0.2)
	
	_show_damage_numbers(666, Color.RED)
	
	# KRİTİK DEĞİŞİKLİK: await ve time_scale kaldırıldı.
	# Böylece oyun akışı donmaz, sadece bu düşman ölür.
	pre_die()

func pre_die():
	is_dying = true
	collision_layer = 0
	collision_mask = 0
	logic_timer.stop()
	
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.3).set_ease(Tween.EASE_IN)
	tw.finished.connect(die)

func die():
	var wm = get_tree().get_first_node_in_group("weapon_manager")
	if wm and wm.has_method("on_enemy_killed"):
		wm.on_enemy_killed(self)
	
	spawn_xp_reward()
	queue_free()

func spawn_xp_reward():
	if xp_orb_scene:
		var orb = xp_orb_scene.instantiate()
		get_tree().root.add_child(orb)
		orb.global_position = global_position + Vector3(0, 0.5, 0)
		if "xp_value" in orb: orb.xp_value = xp_reward

func setup_stats_by_stage():
	max_hp = 25.0 * stage 
	damage = 8.0 * stage 
	xp_reward = 45 * stage 
	if is_elite: 
		max_hp *= 4.0
		damage *= 1.5
		xp_reward *= 5
	current_hp = max_hp

func update_visuals():
	if not mesh: return
	var mat := StandardMaterial3D.new()
	if is_frozen:
		mat.albedo_color = FROZEN_COLOR
		mat.emission_enabled = true
		mat.emission = FROZEN_COLOR * 2.0
	else:
		var color :Color = STAGE_COLORS.get(stage, Color.WHITE)
		mat.albedo_color = color
		if is_elite: 
			mat.emission_enabled = true
			mat.emission = color * 2.0
		if type == EnemyType.ARCHER: mesh.scale = Vector3(0.7, 1.3, 0.7)
	mesh.material_override = mat

func make_elite():
	is_elite = true
	setup_stats_by_stage()
	scale = Vector3(1.8, 1.8, 1.8)
	movement_speed *= 0.8
	update_visuals()

func make_archer():
	type = EnemyType.ARCHER
	attack_range = 15.0
	attack_cooldown = 2.0
	movement_speed *= 1.1
	update_visuals()

func shoot_at_player():
	if not can_attack or is_frozen or projectile_scene == null or player == null: return
	can_attack = false
	var proj = projectile_scene.instantiate()
	get_tree().root.add_child(proj)
	proj.global_position = global_position + Vector3(0, 1.5, 0)
	proj.direction = (player.global_position - proj.global_position).normalized()
	proj.damage = damage
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func attack_player():
	if not can_attack or is_frozen or player == null: return
	can_attack = false
	if player.has_method("take_damage"): player.take_damage(damage)
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func apply_freeze(duration: float):
	if is_elite: return
	is_frozen = true
	update_visuals()
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		is_frozen = false
		update_visuals()
