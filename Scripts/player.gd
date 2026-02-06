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

# YENİ: Çift Dash için şarj sistemi
var current_dash_charges: int = 1

func _ready() -> void:
	add_to_group("player")
	current_hp = AugmentManager.player_stats["max_hp"]
	health_changed.emit(current_hp, AugmentManager.player_stats["max_hp"])
	
	# Başlangıç dash hakkını al
	current_dash_charges = AugmentManager.player_stats.get("dash_charges", 1)

	for vfx in [frost_aura, lifesteal_aura, static_field_vfx]:
		if vfx: vfx.hide()

func _physics_process(delta: float) -> void:
	_handle_look_at()
	_handle_movement_logic(delta)
	_manage_aura_visibility() 
	_handle_titan_form() # Büyüme kontrolü
	move_and_slide()

func _handle_titan_form() -> void:
	# TITAN FORM (Prism 3): Büyüme mekaniği
	if AugmentManager.mechanic_levels.has("prism_3"):
		var scale_bonus = 1.0 + (AugmentManager.mechanic_levels["prism_3"] * 0.15)
		if abs(scale.x - scale_bonus) > 0.01:
			scale = scale.lerp(Vector3.ONE * scale_bonus, 0.1)

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
	
	if Input.is_action_just_pressed("dash"): execute_dash()
	
	var anim_speed_ratio = horizontal_velocity.length() / base_speed
	animation_tree["parameters/VelocitySpace/blend_position"] = lerpf(animation_tree["parameters/VelocitySpace/blend_position"], anim_speed_ratio, delta * 10.0)

func execute_dash() -> void:
	# WIND WALKER: Dash Charge ve Cooldown Sistemi
	var max_charges = AugmentManager.player_stats.get("dash_charges", 1)
	if AugmentManager.mechanic_levels.get("gold_8", 0) >= 3: max_charges += 1
	
	if current_dash_charges <= 0: return # Hakkımız yoksa dash atma
	
	current_dash_charges -= 1
	can_dash = false # Anlık kilit (animasyon vs. için)
	
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
	
	# MANA FLOW: Cooldown Reduction Uygula
	var base_cd = max(0.4, 3.0 + AugmentManager.player_stats.get("dash_cooldown", 0.0))
	var cdr = AugmentManager.player_stats.get("cooldown_reduction", 0.0)
	var final_cd = base_cd * (1.0 - cdr)
	
	# Dash dolumu için bekle
	await get_tree().create_timer(final_cd).timeout
	
	if current_dash_charges < max_charges:
		current_dash_charges += 1

func _manage_aura_visibility() -> void:
	if AugmentManager.mechanic_levels.has("gold_2") and frost_aura:
		if not frost_aura.visible:
			frost_aura.show()
			_animate_vfx_entry(frost_aura)
	
	if AugmentManager.mechanic_levels.has("gold_7") and lifesteal_aura:
		if not lifesteal_aura.visible:
			lifesteal_aura.show()
			_animate_vfx_entry(lifesteal_aura)

	if AugmentManager.mechanic_levels.has("gold_9") and static_field_vfx:
		if not static_field_vfx.visible:
			static_field_vfx.show()
			_animate_vfx_entry(static_field_vfx)

func _animate_vfx_entry(node):
	node.scale = Vector3.ZERO
	var tw = create_tween()
	tw.tween_property(node, "scale", node.scale, 0.5).from(Vector3.ZERO).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func take_damage(amount: float) -> void:
	# THORNS: Optimize edilmiş fizik sorgusu
	if AugmentManager.mechanic_levels.get("gold_2", 0) >= 3:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsShapeQueryParameters3D.new()
		var shape = SphereShape3D.new()
		shape.radius = 5.0
		query.shape = shape
		query.transform = global_transform
		var results = space_state.intersect_shape(query, 24)
		
		for result in results:
			var collider = result.collider
			if collider.is_in_group("Enemies") and collider.has_method("take_damage"):
				collider.take_damage(35.0)
				
	current_hp = clamp(current_hp - amount, 0, AugmentManager.player_stats["max_hp"])
	health_changed.emit(current_hp, AugmentManager.player_stats["max_hp"])
	
	if current_hp <= 0:
		print("Player Died") # Buraya oyun bitiş ekranı gelir

func heal(amount: float) -> void:
	current_hp = clamp(current_hp + amount, 0, AugmentManager.player_stats["max_hp"])
	health_changed.emit(current_hp, AugmentManager.player_stats["max_hp"])
