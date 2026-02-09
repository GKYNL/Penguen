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
	if execution_mark: execution_mark.hide()
	
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
	# 1. GÜVENLİK KONTROLLERİ
	if is_dying or is_frozen or !is_instance_valid(player): 
		velocity = Vector3.ZERO
		return
	
	# 2. HEDEF HESAPLAMA (Input ASLA kullanılmaz)
	var diff = player.global_position - global_position
	diff.y = 0 # Yüksekliği yok say
	var dist = diff.length()
	var dir = diff.normalized()

	# 3. HIZ VE DURUM
	var final_speed = movement_speed * (1.0 - current_slow_factor)
	final_speed = max(0.5, final_speed)

	# 4. DAVRANIŞ (Sadece Mesafeye Göre)
	if type == EnemyType.ARCHER:
		_process_archer_logic(dist, dir, final_speed)
	else:
		_process_melee_logic(dist, dir, final_speed)

	# 5. YÖNELME
	if velocity.length() > 0.1:
		var look_target = global_position + dir
		look_at(look_target, Vector3.UP)

func _process_melee_logic(dist, dir, speed):
	# Çevrelenmeyi önlemek için oyuncuya yapışma, 2.2 metrede dur ve vur
	if dist <= 2.2: 
		velocity = Vector3.ZERO
		attack_player()
	else:
		# INPUT DEĞİL, SADECE OYUNCUYA DOĞRU VEKTÖR
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed

func _process_archer_logic(dist, dir, speed):
	var keep_dist = 14.0
	if dist > keep_dist + 1.5:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	elif dist < keep_dist - 1.5:
		# Oyuncudan kaçarken bile inputa bakmaz, ters vektör alır
		velocity.x = -dir.x * speed * 0.5
		velocity.z = -dir.z * speed * 0.5
	else:
		velocity = Vector3.ZERO
		if can_attack: shoot_at_player()
		
# --- HASAR & ÖLÜM ---
func take_damage(amount: float):
	if is_dying: return
	current_hp -= amount
	_show_damage_numbers(amount, Color.WHITE)
	
	if AugmentManager.mechanic_levels.has("gold_3"):
		var threshold = AugmentManager.player_stats.get("execution_threshold", 0.15)
		if current_hp <= max_hp * threshold:
			_execute_enemy()
			return
	if current_hp <= 0: die()

func _execute_enemy():
	if is_dying: return
	is_dying = true
	current_hp = 0
	if execution_mark: 
		execution_mark.show()
		create_tween().tween_property(execution_mark, "scale", Vector3.ONE * 1.5, 0.15).set_trans(Tween.TRANS_BOUNCE)
	_show_damage_numbers(666, Color.RED)
	die()

func die():
	is_dying = true
	collision_layer = 0
	collision_mask = 0
	logic_timer.stop()
	
	# WeaponManager Habercisi
	var wm = get_tree().get_first_node_in_group("weapon_manager")
	if wm and wm.has_method("on_enemy_killed"): wm.on_enemy_killed(self)
	
	# XP & Efekt
	if xp_orb_scene:
		var orb = xp_orb_scene.instantiate()
		get_tree().root.add_child(orb)
		orb.global_position = global_position + Vector3(0, 0.5, 0)
		if "xp_value" in orb: orb.xp_value = xp_reward
	if explosion_vfx_scene and AugmentManager.mechanic_levels.has("prism_1"):
		var vfx = explosion_vfx_scene.instantiate()
		get_tree().root.add_child(vfx)
		vfx.global_position = global_position

	# KÜÇÜLTME VE HARİTA ALTINA IŞINLAMA
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.3).set_ease(Tween.EASE_IN)
	tw.finished.connect(_send_to_underworld)

func _send_to_underworld():
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	global_position = Vector3(0, -50, 0) # Haritanın altına ışınla
	emit_signal("returned_to_pool", self) # Spawner'a "yerime geçtim" de

# --- RE-SETUP (HAVUZDAN ÇIKARKEN) ---
func reset_for_spawn():
	is_dying = false
	is_frozen = false
	can_attack = true
	current_slow_factor = 0.0
	scale = Vector3.ONE
	visible = true
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 2
	collision_mask = 7
	logic_timer.start()
	update_visuals()

# --- DİĞER FONKSİYONLAR (Görsel, Saldırı, Hasar Sayıları) ---
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
	label.global_position = global_position + Vector3(0, 2.0, 0)
	label.text = str(int(value))
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	label.font_size = 64
	var random_offset = Vector3(randf_range(-1,1), randf_range(1,2), randf_range(-1,1))
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position", label.global_position + random_offset, 0.6).set_ease(Tween.EASE_OUT)
	label.scale = Vector3.ZERO
	tw.tween_property(label, "scale", Vector3.ONE * 3.0, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.3)
	tw.chain().tween_callback(label.queue_free)
