extends CharacterBody3D
class_name Player

signal health_changed(current_health, max_health)

@export var acceleration: float = 60.0 
@export var deceleration: float = 40.0
@export var gravity_mult: float = -2.0 
@export var wind_vfx_scene: PackedScene 
@export var stomp_vfx_scene: PackedScene # BU KALIYOR (Sahne Taslağı)

@onready var camera = $"../Camera3D" 
@onready var body_mesh: MeshInstance3D = $Penguin_v2/Armature/Skeleton3D/Penguin_body_low
@onready var animation_tree: AnimationTree = $Penguin_v2/AnimationTree
@onready var frost_aura = get_node_or_null("VFX_Frost")
@onready var lifesteal_aura = get_node_or_null("VFX_Lifesteal")
@onready var static_field_vfx = get_node_or_null("VFX_Static")
@onready var weapon_manager = get_node_or_null("WeaponManager")
@onready var spell_weaver_aura = get_node_or_null("VFX_SpellWeaver")

# DİKKAT: @onready var stomp_vfx_scene... SATIRINI SİLDİM! ÇAKIŞMA YARATIYORDU.

var current_hp: float = 100.0
var can_dash: bool = true
var dash_speed_bonus: float = 1.0
var current_dash_charges: int = 1
var aura_timer: Timer

# Titan Değişkenleri
var stomp_timer: float = 0.0
var stomp_interval: float = 0.6

# Black Hole Değişkenleri
var black_hole_timer: float = 0.0
var black_hole_cooldown: float = 8.0

func _ready() -> void:
	add_to_group("player")
	
	sync_stats_from_manager()
	
	current_dash_charges = AugmentManager.player_stats.get("dash_charges", 1)

	# Auraları gizle
	for vfx in [frost_aura, lifesteal_aura, static_field_vfx, spell_weaver_aura]:
		if vfx: vfx.hide()
	
	aura_timer = Timer.new()
	aura_timer.wait_time = 0.5
	aura_timer.autostart = true
	aura_timer.timeout.connect(_process_active_auras)
	add_child(aura_timer)
	
	# STOMP EFEKTİNİ YÜKLE
	# Eğer editörden atanmadıysa kodla yükle
	if not stomp_vfx_scene:

		var path = "res://shaders/VFXGroundCrack.tscn"
		
		if ResourceLoader.exists(path):
			stomp_vfx_scene = load(path)

	
	call_deferred("_manage_aura_visibility")

func sync_stats_from_manager():
	var stats = AugmentManager.player_stats
	var new_max = stats["max_hp"]
	
	# Eğer Max HP artmışsa, aradaki farkı mevcut cana ekle
	# (100/100 -> 600/600 olması için)
	if new_max > current_hp:
		# Eğer canı zaten full ise (veya yakınsa), yeni max'a çek
		if current_hp >= (new_max - 550.0): # 500 bonus geldiyse eski can 100'dür
			current_hp = new_max
		else:
			# Değilse sadece farkı ekle
			current_hp += (new_max - 100.0) # Basit mantık
	
	health_changed.emit(current_hp, new_max)
	print("✅ [PLAYER] Sync Tamam. HP: %s/%s, Armor: %s, Stomp: %s" % [
		current_hp, new_max, stats["armor"], stats["stomp_damage"]
	])
func _physics_process(delta: float) -> void:
	_handle_look_at(delta)
	_handle_movement_logic(delta)
	_manage_aura_visibility()
	_handle_titan_mechanics(delta)
	move_and_slide()
	_handle_black_hole_mechanic(delta)
# --- TITAN FORM ---
func _handle_titan_mechanics(delta: float) -> void:
	if not AugmentManager.mechanic_levels.has("prism_3"): return
	
	var lv = AugmentManager.mechanic_levels["prism_3"]
	
	# 1. SCALE
	var target_scale_val = 1.5 + ((lv - 1) * 0.15) 
	var target_vec = Vector3.ONE * target_scale_val
	scale = scale.lerp(target_vec, delta * 2.0)
	
	# 2. STOMP (EZME)
	var s_dmg = AugmentManager.player_stats.get("stomp_damage", 0.0)
	
	# DÜZELTME: Sadece Yatay Hızı Al (Y eksenini, yani yerçekimini yoksay)
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	
	# Kural: Hasar > 0 OLSUN + Yatay Hız > 2.0 OLSUN + Yerde OLSUN
	if s_dmg > 0 and horizontal_speed > 2.0 and is_on_floor():
		stomp_timer -= delta
		if stomp_timer <= 0.0:
			stomp_timer = stomp_interval
			_execute_titan_stomp_guaranteed(s_dmg)
	else:
		# Duruyorsak timer'ı resetleme, olduğu yerde beklesin (Opsiyonel)
		# Ama yürümeye başlayınca hemen vurması için timer'ı biraz kısabilirsin
		pass

func _execute_titan_stomp_guaranteed(damage_amount: float):
	var hit_range = 4.0 * scale.x 
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var hit_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		if global_position.distance_to(enemy.global_position) <= hit_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage_amount)
				hit_count += 1
	
	if hit_count > 0:
		print("🦶 STOMP! %d düşmana %.0f hasar verildi!" % [hit_count, damage_amount])
	
	# VFX - ARTIK PATLAMAYACAK
	if stomp_vfx_scene:
		var vfx = stomp_vfx_scene.instantiate()
		get_tree().root.add_child(vfx)
		vfx.global_position = global_position
		# Base scale'i biraz küçülttüm çünkü PlaneMesh 5x5 çok büyük olabiliyor
		var effect_scale = scale.x * 1.0 
		vfx.scale = Vector3(effect_scale, 1.0, effect_scale)
	
	if camera.has_method("add_trauma"):
		camera.add_trauma(0.35)

# --- STANDART FONKSİYONLAR ---
func take_damage(amount: float) -> void:
	var armor = AugmentManager.player_stats.get("armor", 0.0)
	var reduced_damage = amount * (100.0 / (100.0 + armor))
	print("🛡️ Hasar Alındı: %.1f (Armor: %.0f -> Net: %.1f)" % [amount, armor, reduced_damage])
	var thorns_dmg = AugmentManager.player_stats.get("thorns", 0.0)
	if thorns_dmg > 0: _execute_titan_stomp_guaranteed(thorns_dmg)
	current_hp = clamp(current_hp - reduced_damage, 0, AugmentManager.player_stats["max_hp"])
	health_changed.emit(current_hp, AugmentManager.player_stats["max_hp"])

func _manage_aura_visibility() -> void:
	var levels = AugmentManager.mechanic_levels
	if levels.has("gold_2") and frost_aura: if not frost_aura.visible: frost_aura.show(); _animate_vfx_entry(frost_aura)
	if levels.has("gold_7") and lifesteal_aura: if not lifesteal_aura.visible: lifesteal_aura.show(); _animate_vfx_entry(lifesteal_aura)
	if levels.has("gold_9") and static_field_vfx: if not static_field_vfx.visible: static_field_vfx.show(); _animate_vfx_entry(static_field_vfx)
	if levels.has("prism_2") and spell_weaver_aura:
		if not spell_weaver_aura.visible: spell_weaver_aura.show(); _animate_vfx_entry(spell_weaver_aura)
		if spell_weaver_aura.has_method("set_level"): spell_weaver_aura.set_level(levels["prism_2"])

func _animate_vfx_entry(node):
	node.scale = Vector3.ZERO
	var tw = create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _process_active_auras():
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = SphereShape3D.new()
	query.shape = shape
	query.transform = global_transform
	var results = space_state.intersect_shape(query, 32)
	for res in results:
		var target = res.collider
		if not is_instance_valid(target) or not target.is_in_group("Enemies"): continue
		if AugmentManager.mechanic_levels.has("gold_7"):
			var lvl = AugmentManager.mechanic_levels["gold_7"]
			var lifesteal_pct = [0.02, 0.05, 0.08, 0.12][lvl-1]
			if target.has_method("take_damage"): target.take_damage(5.0); heal(5.0 * lifesteal_pct)
		if AugmentManager.mechanic_levels.has("gold_9"):
			var stun_chance = 0.2 + (AugmentManager.mechanic_levels["gold_9"] * 0.1)
			if target.has_method("apply_status"):
				if randf() < stun_chance: target.apply_status("stun", 0.5)
				else: target.apply_status("shock", 1.0)
		if AugmentManager.mechanic_levels.has("gold_2"):
			var slow_amount = [0.2, 0.4, 0.5, 0.7][AugmentManager.mechanic_levels["gold_2"]-1]
			if target.has_method("apply_slow"): target.apply_slow(slow_amount, 0.6)

func heal(amount: float) -> void:
	var max_h = AugmentManager.player_stats["max_hp"]
	current_hp = clamp(current_hp + amount, 0, max_h)
	health_changed.emit(current_hp, max_h)

func _handle_black_hole_mechanic(delta: float):
	# Yetenek açık mı?
	if not AugmentManager.mechanic_levels.has("prism_4"): return

	black_hole_timer -= delta
	if black_hole_timer <= 0.0:
		black_hole_timer = black_hole_cooldown
		_spawn_black_hole()

func _spawn_black_hole():
	# Kara deliği rastgele bir düşmanın dibinde veya en yakındakinde aç
	var target_pos = global_position # Varsayılan: Kendi altımız

	# En yakın düşmanı bul
	var wm = weapon_manager
	if not is_instance_valid(wm): wm = get_tree().get_first_node_in_group("weapon_manager")
	if is_instance_valid(wm) and wm.has_method("_find_closest_enemy"):
		var enemy = wm._find_closest_enemy()
		if is_instance_valid(enemy):
			target_pos = enemy.global_position

	# Sahneyi oluştur
	# NOT: VFX_BlackHole sahnesini yüklemelisin.
	# Eğer sahne yoksa kodla oluşturmayı deneriz ama sahne olması daha iyi.
	var bh_scene = load("res://shaders/vfx_black_hole.tscn")
	if bh_scene:
		var bh = bh_scene.instantiate()
		get_tree().root.add_child(bh)
		bh.global_position = target_pos

		# Level verisini gönder
		var lv = AugmentManager.mechanic_levels["prism_4"]
		# AugmentManager'dan o levelin JSON verisini bulmamız lazım ama
		# Basitçe manuel data uyduralım veya AugmentManager'a bir "get_stats" yazalım.
		# Şimdilik manuel mapping yapıyorum (JSON'u ezberledik zaten):

		var stats = {}
		if lv == 1: stats = {"radius": 10}
		elif lv == 2: stats = {"radius": 15}
		elif lv == 3: stats = {"radius": 15, "damage": 40}
		elif lv >= 4: stats = {"radius": 22, "damage": 100}

		bh.setup_from_level(stats)


func _handle_look_at(delta: float) -> void:
	var target_dir: Vector3 = Vector3.ZERO
	var wm = weapon_manager
	if not is_instance_valid(wm): wm = get_tree().get_first_node_in_group("weapon_manager")
	if is_instance_valid(wm) and wm.has_method("_find_closest_enemy"):
		var enemy = wm._find_closest_enemy()
		if is_instance_valid(enemy) and enemy.current_hp > 0:
			target_dir = (enemy.global_position - global_position).normalized()
	if target_dir.length() < 0.1 and velocity.length() > 0.1: target_dir = velocity.normalized()
	if target_dir.length() > 0.1:
		target_dir.y = 0
		var look_transform = body_mesh.global_transform.looking_at(global_position + target_dir, Vector3.UP)
		look_transform.basis = look_transform.basis.rotated(Vector3.UP, PI)
		body_mesh.global_transform = body_mesh.global_transform.interpolate_with(look_transform, delta * 30.0)
		body_mesh.rotation.x = 0; body_mesh.rotation.z = 0

func _handle_movement_logic(delta: float) -> void:
	var base_speed = AugmentManager.player_stats["speed"]
	if AugmentManager.mechanic_levels.has("prism_3"): base_speed *= 0.85
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
	var max_charges = AugmentManager.player_stats.get("dash_charges", 1)
	if AugmentManager.mechanic_levels.get("gold_8", 0) >= 3: max_charges += 1
	if current_dash_charges <= 0: return 
	current_dash_charges -= 1
	if wind_vfx_scene:
		var wind = wind_vfx_scene.instantiate()
		get_tree().root.add_child(wind)
		wind.global_position = global_position + Vector3(0, 1.2, 0)
		var move_dir = Vector3(velocity.x, 0, velocity.z).normalized()
		if move_dir.length() < 0.1: move_dir = -body_mesh.global_transform.basis.z.normalized() 
		wind.look_at(wind.global_position + move_dir, Vector3.UP)
		wind.rotate_object_local(Vector3.RIGHT, PI/2.0) 
		var tw = create_tween()
		tw.tween_property(wind, "global_position", wind.global_position + move_dir * 8.0, 0.4)
		tw.parallel().tween_property(wind, "scale", Vector3(0.2, 0.2, 2.5), 0.4).set_ease(Tween.EASE_IN)
		tw.finished.connect(wind.queue_free)
	var dash_force = 3.5
	velocity.x *= dash_force; velocity.z *= dash_force
	dash_speed_bonus = 1.6
	var tw_bonus = create_tween()
	tw_bonus.tween_property(self, "dash_speed_bonus", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	
	if AugmentManager.mechanic_levels.has("prism_3"):
		var s_dmg = AugmentManager.player_stats.get("stomp_damage", 0.0)
		if s_dmg > 0: _execute_titan_stomp_guaranteed(s_dmg)
		
	var final_cd = (3.0 + AugmentManager.player_stats.get("dash_cooldown", 0.0)) * (1.0 - AugmentManager.player_stats.get("cooldown_reduction", 0.0))
	await get_tree().create_timer(max(0.4, final_cd)).timeout
	if current_dash_charges < max_charges: current_dash_charges += 1
