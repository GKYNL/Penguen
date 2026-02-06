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

var current_hp: float = 100.0
var can_dash: bool = true
var dash_speed_bonus: float = 1.0

func _ready() -> void:
	add_to_group("player")
	current_hp = AugmentManager.player_stats["max_hp"]
	health_changed.emit(current_hp, AugmentManager.player_stats["max_hp"])
	# Hepsini başlangıçta gizle
	for vfx in [frost_aura, lifesteal_aura, static_field_vfx]:
		if vfx: vfx.hide()

func _physics_process(delta: float) -> void:
	_handle_look_at()
	_handle_movement_logic(delta)
	_manage_aura_visibility() # Sadece görünürlük yönetimi
	move_and_slide()

func _handle_look_at() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var result = space_state.intersect_ray(query)
	if result:
		var look_dir = Vector3(result.position.x - global_position.x, 0, result.position.z - global_position.z)
		if look_dir.length() > 0.1:
			body_mesh.look_at(global_position + look_dir, Vector3.UP, true)
			body_mesh.rotation.x = 0; body_mesh.rotation.z = 0

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
	
	velocity.x = horizontal_velocity.x; velocity.z = horizontal_velocity.z
	if Input.is_action_just_pressed("dash") and can_dash: execute_dash()
	var anim_speed_ratio = horizontal_velocity.length() / base_speed
	animation_tree["parameters/VelocitySpace/blend_position"] = lerpf(animation_tree["parameters/VelocitySpace/blend_position"], anim_speed_ratio, delta * 10.0)

func execute_dash() -> void:
	can_dash = false
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

	velocity.x *= 3.0; velocity.z *= 3.0
	dash_speed_bonus = 1.6
	var tw_bonus = create_tween()
	tw_bonus.tween_property(self, "dash_speed_bonus", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	var cd = max(0.4, 3.0 + AugmentManager.player_stats.get("dash_cooldown", 0.0))
	if AugmentManager.mechanic_levels.get("gold_8", 0) >= 3: cd *= 0.5
	await get_tree().create_timer(cd).timeout
	can_dash = true

func _manage_aura_visibility() -> void:
	# Frost Aura (Gold 2)
	if AugmentManager.mechanic_levels.has("gold_2") and frost_aura:
		if not frost_aura.visible:
			frost_aura.show()
			_animate_vfx_entry(frost_aura)
	
	# Lifesteal Aura (Gold 7)
	if AugmentManager.mechanic_levels.has("gold_7") and lifesteal_aura:
		if not lifesteal_aura.visible:
			lifesteal_aura.show()
			_animate_vfx_entry(lifesteal_aura)

	# Static Field (Gold 9)
	if AugmentManager.mechanic_levels.has("gold_9") and static_field_vfx:
		if not static_field_vfx.visible:
			static_field_vfx.show()
			_animate_vfx_entry(static_field_vfx)
	
	# Lifesteal Aura
	if AugmentManager.mechanic_levels.has("gold_7") and lifesteal_aura:
		if not lifesteal_aura.visible:
			lifesteal_aura.show()
			_animate_vfx_entry(lifesteal_aura)

func _animate_vfx_entry(node):
	node.scale = Vector3.ZERO
	var tw = create_tween()
	tw.tween_property(node, "scale", node.scale, 0.5).from(Vector3.ZERO).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func take_damage(amount: float) -> void:
	# Thorns mantığı (Daha basit mesafe kontrolü)
	if AugmentManager.mechanic_levels.get("gold_2", 0) >= 3:
		for e in get_tree().get_nodes_in_group("Enemies"):
			if is_instance_valid(e) and global_position.distance_to(e.global_position) < 5.0:
				e.take_damage(35.0)
				
	current_hp = clamp(current_hp - amount, 0, AugmentManager.player_stats["max_hp"])
	health_changed.emit(current_hp, AugmentManager.player_stats["max_hp"])
	
func heal(amount: float) -> void:
	current_hp = clamp(current_hp + amount, 0, AugmentManager.player_stats["max_hp"])
	health_changed.emit(current_hp, AugmentManager.player_stats["max_hp"])
