extends CharacterBody3D
class_name Player

signal health_changed(current_health, max_health)

@export var acceleration: float = 60.0 
@export var deceleration: float = 40.0
@export var gravity_mult: float = -2.0 
@export var wind_vfx_scene: PackedScene 

@onready var camera = $"../Camera3D" 
@onready var body_mesh: MeshInstance3D = $Penguin_v2/Armature/Skeleton3D/Penguin_body_low
@onready var animation_tree: AnimationTree = $Penguin_v2/AnimationTree
@onready var frost_aura = get_node_or_null("VFX_Frost")
@onready var lifesteal_aura = get_node_or_null("VFX_Lifesteal")
@onready var static_field_vfx = get_node_or_null("VFX_Static")

# WeaponManager referansı
@onready var weapon_manager = get_node_or_null("WeaponManager")

var current_hp: float = 100.0
var can_dash: bool = true
var dash_speed_bonus: float = 1.0
var current_dash_charges: int = 1
var aura_timer: Timer

func _ready() -> void:
	add_to_group("player")
	current_hp = AugmentManager.player_stats["max_hp"]
	health_changed.emit(current_hp, AugmentManager.player_stats["max_hp"])
	
	current_dash_charges = AugmentManager.player_stats.get("dash_charges", 1)

	for vfx in [frost_aura, lifesteal_aura, static_field_vfx]:
		if vfx: vfx.hide()
	
	aura_timer = Timer.new()
	aura_timer.wait_time = 0.5
	aura_timer.autostart = true
	aura_timer.timeout.connect(_process_active_auras)
	add_child(aura_timer)

func _physics_process(delta: float) -> void:
	_handle_look_at(delta) 
	_handle_movement_logic(delta)
	_manage_aura_visibility() 
	_handle_titan_form() 
	move_and_slide()

func _handle_look_at(delta: float) -> void:
	var target_dir: Vector3 = Vector3.ZERO
	var wm = weapon_manager
	
	if not is_instance_valid(wm):
		wm = get_tree().get_first_node_in_group("weapon_manager")
	
	if is_instance_valid(wm):
		if wm.has_method("_find_closest_enemy"):
			var enemy = wm._find_closest_enemy()
			if is_instance_valid(enemy) and enemy.current_hp > 0:
				target_dir = (enemy.global_position - global_position).normalized()

	if target_dir.length() < 0.1:
		if velocity.length() > 0.1:
			target_dir = velocity.normalized()
	
	if target_dir.length() > 0.1:
		target_dir.y = 0
		
		var target_pos = global_position + target_dir
		if global_position.distance_to(target_pos) > 0.01:
			var look_transform = body_mesh.global_transform.looking_at(target_pos, Vector3.UP)
			
			# DÜZELTME: Karakterin modelini 180 derece (PI radyan) döndürerek önünü hedefe bakacak hale getiriyoruz
			look_transform.basis = look_transform.basis.rotated(Vector3.UP, PI)
			
			body_mesh.global_transform = body_mesh.global_transform.interpolate_with(look_transform, delta * 30.0)
			
			body_mesh.rotation.x = 0
			body_mesh.rotation.z = 0

func _handle_movement_logic(delta: float) -> void:
	var base_speed = AugmentManager.player_stats["speed"]
	var target_max_speed = base_speed * dash_speed_bonus
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis = camera.global_transform.basis
	var forward = Vector3(cam_basis.z.x, 0, cam_basis.z.z).normalized()
	var right = Vector3(cam_basis.x.x, 0, cam_basis.x.z).normalized()
	var direction = (right * input_dir.x + forward * input_dir.y).normalized()

	if not is_on_floor(): velocity.y -= (get_gravity().y * gravity_mult) * delta
	else: velocity.y = 0

	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var target_velocity = direction * target_max_speed
	if direction.length() > 0: horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
	else: horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, deceleration * delta)
	
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	
	if Input.is_action_just_pressed("dash"): execute_dash()
	
	var anim_speed_ratio = horizontal_velocity.length() / base_speed
	animation_tree["parameters/VelocitySpace/blend_position"] = lerpf(animation_tree["parameters/VelocitySpace/blend_position"], anim_speed_ratio, delta * 10.0)

func execute_dash() -> void:
	var max_charges = AugmentManager.player_stats.get("dash_charges", 1)
	if AugmentManager.mechanic_levels.get("gold_8", 0) >= 3: max_charges += 1
	
	if current_dash_charges <= 0: return 
	current_dash_charges -= 1
	
	if wind_vfx_scene:
		var wind = wind_vfx_scene.instantiate()
		get_tree().root.add_child(wind)
		wind.global_position = global_position
		var dash_dir = Vector3(velocity.x, 0, velocity.z).normalized()
		if dash_dir.length() > 0.1: wind.look_at(global_position + dash_dir, Vector3.UP)
		var tw = create_tween()
		tw.tween_property(wind, "global_position", global_position + dash_dir * 8.0, 0.4)
		tw.parallel().tween_property(wind, "scale", Vector3.ZERO, 0.4).set_delay(0.2)
		tw.finished.connect(wind.queue_free)
		
		if AugmentManager.mechanic_levels.get("gold_8", 0) >= 2:
			var projectiles = get_tree().get_nodes_in_group("EnemyProjectile")
			for proj in projectiles:
				if proj.global_position.distance_to(global_position) < 5.0: proj.queue_free()

	velocity.x *= 3.0
	velocity.z *= 3.0
	dash_speed_bonus = 1.6
	var tw_bonus = create_tween()
	tw_bonus.tween_property(self, "dash_speed_bonus", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	
	var final_cd = (3.0 + AugmentManager.player_stats.get("dash_cooldown", 0.0)) * (1.0 - AugmentManager.player_stats.get("cooldown_reduction", 0.0))
	await get_tree().create_timer(max(0.4, final_cd)).timeout
	if current_dash_charges < max_charges: current_dash_charges += 1

func _handle_titan_form() -> void:
	if AugmentManager.mechanic_levels.has("prism_3"):
		var scale_bonus = 1.0 + (AugmentManager.mechanic_levels["prism_3"] * 0.15)
		scale = scale.lerp(Vector3.ONE * scale_bonus, 0.1)

func _process_active_auras():
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 6.0
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 2
	
	if AugmentManager.mechanic_levels.has("gold_7"):
		var results = space_state.intersect_shape(query, 16)
		var damage_tick = 5.0
		var heal_tick = 0
		var lvl = AugmentManager.mechanic_levels["gold_7"]
		var lifesteal_pct = [0.02, 0.05, 0.08, 0.12][lvl-1]
		for res in results:
			if res.collider.has_method("take_damage"):
				res.collider.take_damage(damage_tick)
				heal_tick += damage_tick * lifesteal_pct
		if heal_tick > 0: heal(heal_tick)
	
	if AugmentManager.mechanic_levels.has("gold_9"):
		var results = space_state.intersect_shape(query, 12)
		var stun_chance = 0.2 + (AugmentManager.mechanic_levels["gold_9"] * 0.1)
		for res in results:
			if res.collider.has_method("apply_status"):
				if randf() < stun_chance: res.collider.apply_status("stun", 0.5)
				else: res.collider.apply_status("shock", 1.0)
	
	if AugmentManager.mechanic_levels.has("gold_2"):
		var results = space_state.intersect_shape(query, 12)
		var slow_amount = [0.2, 0.4, 0.5, 0.7][AugmentManager.mechanic_levels["gold_2"]-1]
		for res in results:
			if res.collider.has_method("apply_slow"): res.collider.apply_slow(slow_amount, 0.6)

func _manage_aura_visibility() -> void:
	if AugmentManager.mechanic_levels.has("gold_2") and frost_aura: if not frost_aura.visible: frost_aura.show(); _animate_vfx_entry(frost_aura)
	if AugmentManager.mechanic_levels.has("gold_7") and lifesteal_aura: if not lifesteal_aura.visible: lifesteal_aura.show(); _animate_vfx_entry(lifesteal_aura)
	if AugmentManager.mechanic_levels.has("gold_9") and static_field_vfx: if not static_field_vfx.visible: static_field_vfx.show(); _animate_vfx_entry(static_field_vfx)

func _animate_vfx_entry(node):
	node.scale = Vector3.ZERO
	var tw = create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func take_damage(amount: float) -> void:
	var thorns_dmg = AugmentManager.player_stats.get("thorns", 0.0)
	if thorns_dmg > 0:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsShapeQueryParameters3D.new()
		var shape = SphereShape3D.new()
		shape.radius = 4.0
		query.shape = shape
		query.transform = global_transform
		query.collision_mask = 2
		var results = space_state.intersect_shape(query, 8)
		for result in results:
			if result.collider.has_method("take_damage"): result.collider.take_damage(thorns_dmg)
				
	current_hp = clamp(current_hp - amount, 0, AugmentManager.player_stats["max_hp"])
	health_changed.emit(current_hp, AugmentManager.player_stats["max_hp"])

func heal(amount: float) -> void:
	current_hp = clamp(current_hp + amount, 0, AugmentManager.player_stats["max_hp"])
	health_changed.emit(current_hp, AugmentManager.player_stats["max_hp"])
