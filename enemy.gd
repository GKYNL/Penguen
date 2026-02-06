extends CharacterBody3D

enum EnemyType { MELEE, ARCHER }

# --- SABİTLER (Eksik olanlar buraya eklendi) ---
const STAGE_COLORS := {
	1: Color.DARK_GOLDENROD, 2: Color.GREEN, 3: Color.BLUE,
	4: Color.PURPLE, 5: Color.ORANGE, 6: Color.RED, 7: Color.BLACK
}
const FROZEN_COLOR := Color(0.267, 0.655, 1.0, 1.0)

# --- TOPLAMA SİSTEMİ ---
var damage_accumulator: float = 0.0
var is_dying: bool = false

# --- NODE REFERANSLARI ---
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var player = get_tree().get_first_node_in_group("player")
@onready var execution_mark = get_node_or_null("ExecutionMark")
@onready var label_3d: Label3D = $Label3D

# --- OPTİMİZASYON İÇİN TİMERLAR ---
var logic_timer: Timer
var damage_display_timer: Timer

# --- EXPORTLAR ---
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
var base_speed: float = 5.0

func _ready():
	add_to_group("Enemies")
	base_speed = movement_speed
	setup_stats_by_stage()
	update_visuals()
	if execution_mark: execution_mark.hide()
	if label_3d: label_3d.text = ""

	# MANTIKSAL TİMER: Saniyede 10 kez karar vermesi yeterli
	logic_timer = Timer.new()
	add_child(logic_timer)
	logic_timer.wait_time = 0.1
	logic_timer.timeout.connect(_on_logic_tick)
	logic_timer.start()

	# HASAR GÖSTERGE TİMERI: Saniyede 1 kez
	damage_display_timer = Timer.new()
	add_child(damage_display_timer)
	damage_display_timer.wait_time = 1.0
	damage_display_timer.timeout.connect(_on_damage_display_tick)
	damage_display_timer.start()

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

	var speed_mult = 1.0
	if AugmentManager.mechanic_levels.has("gold_2") and dist < 6.0:
		speed_mult = 1.0 - [0.2, 0.4, 0.5, 0.7][AugmentManager.mechanic_levels["gold_2"]-1]
	
	var final_speed = movement_speed * speed_mult

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
		
		if can_attack and dist <= 18.0:
			shoot_at_player()
	else:
		if dist <= attack_range:
			velocity.x = 0; velocity.z = 0
			attack_player()
		else:
			velocity.x = dir.x * final_speed
			velocity.z = dir.z * final_speed

	if velocity.length() > 0.1:
		look_at(global_position + dir, Vector3.UP)

func _on_damage_display_tick():
	if damage_accumulator > 0 and not is_dying:
		_show_damage_numbers(damage_accumulator)
		damage_accumulator = 0.0

func take_damage(dmg):
	if current_hp <= 0 or is_dying: return
	
	current_hp -= dmg
	damage_accumulator += dmg
	
	if AugmentManager.mechanic_levels.has("gold_3") and current_hp > 0:
		var threshold = AugmentManager.player_stats.get("execution_threshold", 0.0)
		if current_hp <= max_hp * threshold:
			_execute_enemy()
			return

	if current_hp <= 0: 
		pre_die()

func pre_die():
	if is_dying: return
	is_dying = true
	
	logic_timer.stop()
	damage_display_timer.stop()
	
	if damage_accumulator > 0:
		_show_damage_numbers(damage_accumulator)
	
	await get_tree().create_timer(0.5).timeout
	die()

func _show_damage_numbers(amount: float, color: Color = Color.WHITE):
	if not label_3d: return
	label_3d.text = str(ceil(amount))
	label_3d.modulate = color
	label_3d.position.y = 2.0
	label_3d.modulate.a = 1.0
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label_3d, "position:y", 3.5, 0.4)
	tw.tween_property(label_3d, "modulate:a", 0.0, 0.4)

func _execute_enemy():
	if is_dying: return
	is_dying = true
	current_hp = 0
	logic_timer.stop()
	if execution_mark: 
		execution_mark.show()
		var tw = create_tween()
		tw.tween_property(execution_mark, "scale", Vector3.ONE * 1.5, 0.1)
		tw.tween_property(execution_mark, "scale", Vector3.ONE, 0.1)
	_show_damage_numbers(666, Color.RED)
	await get_tree().create_timer(0.5).timeout
	die()

func die():
	if AugmentManager.player_stats.get("lifesteal_flat", 0) > 0:
		if player and player.has_method("heal"): player.heal(AugmentManager.player_stats["lifesteal_flat"])
	
	if AugmentManager.mechanic_levels.has("gold_4"):
		var chance = [0.1, 0.2, 0.3, 0.5][AugmentManager.mechanic_levels["gold_4"]-1]
		if randf() < chance: 
			_explode()
			return

	spawn_xp_reward()
	queue_free()

func _explode():
	if not explosion_vfx_scene: 
		spawn_xp_reward()
		queue_free()
		return
	var vfx = explosion_vfx_scene.instantiate()
	get_tree().root.add_child(vfx)
	vfx.global_position = global_position
	if vfx.has_method("play_effect"): vfx.play_effect(damage)
	spawn_xp_reward()
	queue_free()

func spawn_xp_reward():
	if xp_orb_scene == null: return
	var orb = xp_orb_scene.instantiate()
	get_tree().root.add_child(orb)
	orb.global_position = global_position + Vector3(0, 1.0, 0)
	orb.xp_value = xp_reward

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
		mat.emission_enabled = true; mat.emission = FROZEN_COLOR * 2.0
	else:
		var color :Color = STAGE_COLORS.get(stage, Color.WHITE)
		mat.albedo_color = color
		if is_elite: 
			mat.emission_enabled = true; mat.emission = color * 4.0
		if type == EnemyType.ARCHER: mesh.scale = Vector3(0.7, 1.3, 0.7)
	mesh.material_override = mat

func shoot_at_player():
	if not can_attack or is_frozen or projectile_scene == null or player == null: return
	can_attack = false
	var proj = projectile_scene.instantiate()
	get_tree().root.add_child(proj)
	proj.global_position = global_position + Vector3(0, 1.5, 0)
	proj.direction = (player.global_position - proj.global_position).normalized()
	proj.damage = damage
	await get_tree().create_timer(attack_cooldown * 2.0).timeout
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
