extends CharacterBody3D
class_name Player

signal health_changed(current_health, max_health)

@export var acceleration: float = 60.0 
@export var deceleration: float = 40.0
@export var gravity_mult: float = -2.0 

@onready var camera = $"../Camera3D" 
@onready var body_mesh: MeshInstance3D = $Penguin_v2/Armature/Skeleton3D/Penguin_body_low
@onready var animation_tree: AnimationTree = $Penguin_v2/AnimationTree
@onready var frost_aura = get_node_or_null("VFX_Frost")
@onready var lifesteal_aura = get_node_or_null("VFX_Lifesteal")
@onready var static_field_vfx = get_node_or_null("VFX_Static")
@onready var weapon_manager = get_node_or_null("WeaponManager")
@onready var spell_weaver_aura = get_node_or_null("VFX_SpellWeaver")
@onready var pause_menu = $PauseMenu
@onready var hud_node: hud = $HUD

# Sürekli sahnede kalan efektler
var winter_aura_instance = null
var time_stop_instance = null

var current_hp: float = 100.0

var current_dash_charges: int = 1
var max_dash_charges: int = 1
var dash_timer: float = 0.0
var dash_cooldown: float = 3.0
var can_dash: bool = true
var dash_speed_bonus: float = 1.0
var final_cd: float = 3.0
var dash_cooldown_base: float = 3.0
var is_recharging: bool = false

# Skill Variables
var dragon_timer: float = 0.0
var dragon_cooldown: float = 4.0 
var active_clones: Array = []

# Godspeed Variables
var godspeed_instance = null
var godspeed_current_mult: float = 1.0 # Anlık hız çarpanı
var godspeed_target_mult: float = 1.0 # Hedef hız çarpanı
var godspeed_has_trail: bool = false 
var godspeed_has_damage: bool = false 
var godspeed_active: bool = false
var godspeed_max_mult: float = 1.0
var godspeed_damage_timer: float = 0.0

# Skill Timers
var stomp_timer: float = 0.0
var stomp_interval: float = 0.6
var black_hole_timer: float = 0.0
var black_hole_cooldown: float = 8.0
var winter_tick_timer: float = 0.0
var time_stop_timer: float = 0.0
var base_time_stop_cd: float = 30.0
var is_time_stopped: bool = false
var time_stop_remaining_duration: float = 0.0
var clone_update_timer: float = 0.0
var aura_timer: Timer



var health: float = 100.0
var statss: Dictionary = {"strength": 10, "agility": 10}
var augments: Array = []
var mana: float = 50.0


func _ready() -> void:
	add_to_group("player")
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var saved_data = SaveSystem.load_save_data()
	
	# GÜVENLİ KONTROL: saved_data null değilse ve içinde 'player_pos' varsa devam et
	if saved_data and saved_data.has("player_pos"):
		var pos = saved_data["player_pos"]
		global_position = Vector3(
			pos.get("x", global_position.x), 
			pos.get("y", global_position.y), 
			pos.get("z", global_position.z)
		)
		
		# game_stats kontrolü
		if saved_data.has("game_stats"):
			var stats = saved_data["game_stats"]
			current_hp = stats.get("hp", 100.0)
			_load_brain_data(stats)
	else:
		# Eğer save dosyası yoksa veya eskiyse statları temiz çek
		sync_stats_from_manager()
		print("SİSTEM: Geçerli save bulunamadı, sıfırdan başlanıyor.")


func _restore_cds(cd_data):
	for skill_name in cd_data:
		var timer = get_node("SkillTimers/" + skill_name)
		if timer and cd_data[skill_name] > 0:
			timer.start(cd_data[skill_name])

func _load_brain_data(stats_data):
	# AugmentManager'daki verileri direkt save dosyasındakiyle ezüyoruz
	AugmentManager.current_xp = stats_data.xp
	AugmentManager.current_level = stats_data.level
	AugmentManager.mechanic_levels = stats_data.mechanic_levels
	AugmentManager.player_stats = stats_data.player_stats
	
	# Statlar yüklendi, şimdi player'ın hızı/canı vb. güncellensin
	sync_stats_from_manager()
	# Aktif auralları/vfxleri kontrol et
	_manage_aura_visibility()
	
	print("BEDEN: Pozisyon yüklendi. BEYİN: Tüm statlar ve augmentler senkronize edildi.")



func sync_stats_from_manager():
	var stats = AugmentManager.player_stats
	var new_max = stats["max_hp"]
	if new_max > current_hp:
		current_hp += (new_max - 100.0)
	health_changed.emit(current_hp, new_max)
	
	# Level atlandığında Godspeed verilerini güncelle
	if AugmentManager.mechanic_levels.has("prism_9"):
		_update_godspeed_stats()

# --- OPTİMİZASYON: GODSPEED VERİSİNİ SADECE GEREKTİĞİNDE GÜNCELLE ---
func _update_godspeed_stats():
	var g_lv = AugmentManager.mechanic_levels["prism_9"]
	godspeed_active = true
	
	# Varsayılanlar
	godspeed_max_mult = 1.0
	godspeed_has_trail = false
	godspeed_has_damage = false
	
	# JSON'dan Veri Çekme (Tier 3 Pool'dan)
	var card_data = null
	if "tier_3_pool" in AugmentManager:
		for card in AugmentManager.tier_3_pool:
			if card.id == "prism_9": card_data = card; break
	
	if card_data:
		for i in range(g_lv):
			if i < card_data["levels"].size():
				var info = card_data["levels"][i]
				if info.has("speed"): godspeed_max_mult = float(info["speed"])
				if info.has("trail"): godspeed_has_trail = bool(info["trail"])
				if info.has("dmg_speed"): godspeed_has_damage = true

func _physics_process(delta: float) -> void:
	# --- PAUSE KONTROLÜ ---
	if get_tree().paused and not is_time_stopped: 
		return

	if AugmentManager.is_selection_active: return 

	if is_time_stopped:
		time_stop_remaining_duration -= delta
		if time_stop_remaining_duration <= 0.0: _end_time_stop()
		_handle_look_at(delta)
		_handle_movement_logic(delta)
	else:
		_handle_look_at(delta)
		_handle_movement_logic(delta)
		_manage_aura_visibility()
		_handle_titan_mechanics(delta)
		_handle_black_hole_mechanic(delta)
		_handle_winter_mechanic(delta)
		_handle_dragon_breath_mechanic(delta)
		_handle_mirror_image_mechanic(delta)
		_handle_godspeed_mechanic(delta)
		_handle_time_stop_mechanic(delta)
	
	move_and_slide()

# --- HAREKET MANTIĞI (DÜZELTİLDİ) ---
func _handle_movement_logic(delta: float) -> void:
	var base_speed = AugmentManager.player_stats["speed"]
	
	if AugmentManager.mechanic_levels.has("gold_8"):
		var ww_lvl = AugmentManager.mechanic_levels["gold_8"]
		# Her seviye için %10 hız bonusu verelim
		base_speed *= (1.0 + (ww_lvl * 0.10))
	
	# Titan Yavaşlatması
	if AugmentManager.mechanic_levels.has("prism_3"): base_speed *= 0.85
	
	# Godspeed İvmelenmesi (Ramp-Up)
	if godspeed_active:
		var is_moving = Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.1
		
		if is_moving:
			# Hedef hıza doğru yavaşça çık (1.5 sn sürer)
			godspeed_current_mult = move_toward(godspeed_current_mult, godspeed_max_mult, delta * 1.5)
		else:
			# Durunca hızla normale dön
			godspeed_current_mult = move_toward(godspeed_current_mult, 1.0, delta * 4.0)
			
		base_speed *= godspeed_current_mult
	else:
		godspeed_current_mult = 1.0
	
	# Dash Bonus Hızı
	var target_max_speed = base_speed * dash_speed_bonus
	
	# Hareket Fiziği
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis = camera.global_transform.basis
	var forward = Vector3(cam_basis.z.x, 0, cam_basis.z.z).normalized()
	var right = Vector3(cam_basis.x.x, 0, cam_basis.x.z).normalized()
	var direction = (right * input_dir.x + forward * input_dir.y).normalized()
	
	if not is_on_floor(): velocity.y -= (get_gravity().y * gravity_mult) * delta
	else: velocity.y = 0
	
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var target_velocity = direction * target_max_speed
	
	if direction.length() > 0: 
		horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
	else: 
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, deceleration * delta)
	
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	
	if Input.is_action_just_pressed("dash"): execute_dash()
	
	# Animasyon
	var anim_speed_ratio = horizontal_velocity.length() / AugmentManager.player_stats["speed"]
	animation_tree["parameters/VelocitySpace/blend_position"] = lerpf(animation_tree["parameters/VelocitySpace/blend_position"], anim_speed_ratio, delta * 10.0)

# --- GODSPEED MEKANİĞİ ---
func _handle_godspeed_mechanic(delta: float):
	if not godspeed_active: return
	
	# Input Yönünü Al (Sonic Boom için)
	var input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# 1. VFX Spawn & Update
	if godspeed_has_trail:
		if not is_instance_valid(godspeed_instance):
			godspeed_instance = VFXPoolManager.spawn_vfx("godspeed", Vector3.ZERO)
			if godspeed_instance:
				# --- DEĞİŞİKLİK: SELF (ROOT)'A BAĞLA ---
				# Body_mesh yerine direkt Player root'a bağlıyoruz.
				# Rotasyonu vfx scripti input'a göre kendi halledecek.
				if godspeed_instance.get_parent() != self:
					godspeed_instance.reparent(self)
				
				# Pozisyon: Göğüs hizası (0.8), hafif önde (-0.2)
				# Root'a bağlı olduğu için offsetleri sabit veriyoruz.
				godspeed_instance.position = Vector3(0, 0.8, 0.0) 
				
				if godspeed_instance.has_method("activate_effect"):
					godspeed_instance.activate_effect()
		
		# VFX Güncelleme
		if is_instance_valid(godspeed_instance) and godspeed_instance.has_method("update_effect"):
			# Hız Oranı Hesapla
			var denom = (godspeed_max_mult - 1.0)
			var ratio = 0.0
			if denom > 0.01:
				ratio = (godspeed_current_mult - 1.0) / denom
			
			# Yeni fonksiyona INPUT VECTÖRÜNÜ de gönderiyoruz!
			godspeed_instance.update_effect(input_vector, clamp(ratio, 0.0, 1.0), godspeed_has_damage)

	# 2. Sonic Boom Hasarı (Mantık aynı)
	if godspeed_has_damage:
		godspeed_damage_timer -= delta
		if godspeed_damage_timer <= 0:
			godspeed_damage_timer = 0.15
			if godspeed_current_mult > 1.3:
				_apply_velocity_damage(godspeed_current_mult)

func _apply_velocity_damage(mult: float):
	var dmg = mult * 25.0
	var hit_range = 2.5 
	var enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		var my_flat = Vector3(global_position.x, 0, global_position.z)
		var en_flat = Vector3(enemy.global_position.x, 0, enemy.global_position.z)
		if my_flat.distance_to(en_flat) <= hit_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg)

# --- DASH DÜZELTMESİ (UÇMAYI ENGELLEME) ---
func execute_dash() -> void:
	if current_dash_charges <= 0: return 
	
	var ww_level = AugmentManager.mechanic_levels.get("gold_8", 0)
	current_dash_charges -= 1
	
	# 1. YÖN HESAPLAMA
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = -body_mesh.global_transform.basis.z.normalized()
	if input_dir.length() > 0.1:
		var cam_basis = camera.global_transform.basis
		direction = (Vector3(cam_basis.x.x, 0, cam_basis.x.z).normalized() * input_dir.x + 
					 Vector3(cam_basis.z.x, 0, cam_basis.z.z).normalized() * input_dir.y).normalized()

	# 2. VFX
	var dash_vfx = VFXPoolManager.spawn_vfx("wind_dash", global_position)
	if dash_vfx:
		dash_vfx.look_at(global_position + direction, Vector3.UP)
		dash_vfx.rotate_object_local(Vector3.RIGHT, PI/2)

	# 3. HAREKET
	if ww_level >= 4:
		global_position += direction * 8.5
	else:
		velocity = direction * 40.0
		if ww_level >= 2:
			dash_speed_bonus = 2.0
			var tw = create_tween()
			tw.tween_property(self, "dash_speed_bonus", 1.0, 1.2)

	# 4. COOLDOWN HESABI (Şarj dolumuna başlamadan ÖNCE hesapla)
	var cdr = AugmentManager.player_stats.get("cooldown_reduction", 0.0)
	final_cd = dash_cooldown_base * (1.0 - cdr)
	if ww_level >= 3: final_cd *= 0.5
	
	# Maksimum şarj sayısını güncelle (HUD buna bakıyor)
	max_dash_charges = AugmentManager.player_stats.get("dash_charges", 1)
	if ww_level >= 3: max_dash_charges += 1

	# 5. ŞARJ DOLUMUNU TETİKLE (Zaten dolmuyorsa başlat)
	if not is_recharging:
		_start_recharge_cycle()

# Şarj Doldurma (Level 3 ekstra yük kapasitesi sağlar)
func _start_recharge_cycle():
	if current_dash_charges >= max_dash_charges:
		is_recharging = false
		dash_timer = 0
		return
		
	is_recharging = true
	dash_timer = final_cd # Barı tam doluya çek
	
	var tw = create_tween()
	# dash_timer'ı wait_time (final_cd) süresince 0'a indirir
	tw.tween_property(self, "dash_timer", 0.0, final_cd)
	
	await tw.finished
	
	current_dash_charges += 1
	
	# Eğer hala eksik şarj varsa döngüyü devam ettir
	if current_dash_charges < max_dash_charges:
		_start_recharge_cycle()
	else:
		is_recharging = false

func _clear_projectiles_in_range(radius: float):
	# Düşman mermilerini EnemyProjectiles grubundan siler
	var projs = get_tree().get_nodes_in_group("EnemyProjectiles")
	for p in projs:
		if is_instance_valid(p) and global_position.distance_to(p.global_position) < radius:
			p.queue_free()


# --- DİĞER MEKANİKLER (Aynı Kaldı) ---

func _handle_time_stop_mechanic(delta: float):
	if not AugmentManager.mechanic_levels.has("prism_6"): return
	time_stop_timer -= delta
	if time_stop_timer <= 0.0:
		var stats = AugmentManager.player_stats
		var duration = stats.get("time_stop_duration", 0.0)
		if duration <= 0: return
		
		var total_cd = base_time_stop_cd * stats.get("time_stop_cooldown_mult", 1.0)
		total_cd *= (1.0 - stats.get("cooldown_reduction", 0.0))
		time_stop_timer = max(5.0, total_cd)
		_trigger_time_stop(duration)

func _trigger_time_stop(duration: float):
	print("ZA WARUDO!")
	is_time_stopped = true
	time_stop_remaining_duration = duration
	
	if not time_stop_instance:
		time_stop_instance = VFXPoolManager.spawn_vfx("time_stop", Vector3.ZERO)
		
		if time_stop_instance:
			time_stop_instance.process_mode = Node.PROCESS_MODE_ALWAYS
			if time_stop_instance is Node3D:
				if time_stop_instance.get_parent() != self:
					time_stop_instance.reparent(self) 
					time_stop_instance.position = Vector3.ZERO
	
	if time_stop_instance and time_stop_instance.has_method("start_effect"):
		time_stop_instance.start_effect()
	
	get_tree().paused = true

func _end_time_stop():
	is_time_stopped = false
	get_tree().paused = false
	if time_stop_instance and time_stop_instance.has_method("stop_effect"):
		time_stop_instance.stop_effect()

func _handle_titan_mechanics(delta: float) -> void:
	if not AugmentManager.mechanic_levels.has("prism_3"): return
	var lv = AugmentManager.mechanic_levels["prism_3"]
	var target_vec = Vector3.ONE * (1.5 + ((lv - 1) * 0.15))
	scale = scale.lerp(target_vec, delta * 2.0)
	
	var s_dmg = AugmentManager.player_stats.get("stomp_damage", 0.0)
	if s_dmg > 0 and Vector2(velocity.x, velocity.z).length() > 2.0 and is_on_floor():
		stomp_timer -= delta
		if stomp_timer <= 0.0:
			stomp_timer = stomp_interval
			_execute_titan_stomp(s_dmg)

func _execute_titan_stomp(damage_amount: float):
	var hit_range = 4.0 * scale.x 
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var vfx = VFXPoolManager.spawn_vfx("titan_stomp", global_position)
	if vfx:
		var effect_scale = scale.x * 1.0 
		vfx.scale = Vector3(effect_scale, 1.0, effect_scale)
	
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		var flat_pos = Vector3(global_position.x, 0, global_position.z)
		var flat_enemy = Vector3(enemy.global_position.x, 0, enemy.global_position.z)
		if flat_pos.distance_to(flat_enemy) <= hit_range:
			if enemy.has_method("take_damage"): enemy.take_damage(damage_amount)
	
	if camera.has_method("add_trauma"): camera.add_trauma(0.35)

func _handle_winter_mechanic(delta: float):
	if not AugmentManager.mechanic_levels.has("prism_5"): return
	winter_tick_timer -= delta
	if winter_tick_timer <= 0.0:
		winter_tick_timer = 0.25 
		var stats = AugmentManager.player_stats
		var radius = stats.get("winter_radius", 8.0)
		var damage = stats.get("winter_damage", 0.0) * 0.25
		var slow = stats.get("winter_slow", 0.0)
		
		var enemies = get_tree().get_nodes_in_group("Enemies")
		for enemy in enemies:
			if not is_instance_valid(enemy): continue
			if global_position.distance_to(enemy.global_position) <= radius:
				if damage > 0 and enemy.has_method("take_damage"): enemy.take_damage(damage)
				if slow > 0 and enemy.has_method("apply_slow"): enemy.apply_slow(slow, 0.5)

func _handle_black_hole_mechanic(delta: float):
	if not AugmentManager.mechanic_levels.has("prism_4"): return
	black_hole_timer -= delta
	if black_hole_timer <= 0.0:
		black_hole_timer = black_hole_cooldown
		_spawn_black_hole()

func _spawn_black_hole():
	var target_pos = global_position 
	var wm = weapon_manager
	if not is_instance_valid(wm): wm = get_tree().get_first_node_in_group("weapon_manager")
	if is_instance_valid(wm) and wm.has_method("_find_closest_enemy"):
		var enemy = wm._find_closest_enemy()
		if is_instance_valid(enemy): target_pos = enemy.global_position

	var bh = VFXPoolManager.spawn_vfx("black_hole", target_pos)
	if bh and bh.has_method("setup_from_level"):
		var lv = AugmentManager.mechanic_levels["prism_4"]
		var stats = {"radius": 10}
		if lv == 2: stats = {"radius": 15}
		elif lv == 3: stats = {"radius": 15, "damage": 40}
		elif lv >= 4: stats = {"radius": 22, "damage": 100}
		bh.setup_from_level(stats)

func take_damage(amount: float) -> void:
	var armor = AugmentManager.player_stats.get("armor", 0.0)
	var reduced_damage = amount * (100.0 / (100.0 + armor))
	var thorns_dmg = AugmentManager.player_stats.get("thorns", 0.0)
	if thorns_dmg > 0: _execute_titan_stomp(thorns_dmg)
	current_hp = clamp(current_hp - reduced_damage, 0, AugmentManager.player_stats["max_hp"])
	health_changed.emit(current_hp, AugmentManager.player_stats["max_hp"])
	if current_hp <= 0:
		_die()
func _die():
	get_tree().paused = true # Dünyayı durdur
	
	# Sahnedeki HUD'dan süreyi çekebiliriz veya globalden
	var survival_time = ""
	if hud_node:
		survival_time = hud_node.time_label.text

	# Death Screen'i göster
	var death_screen = get_node_or_null("DeathScreen") # Veya hiyerarşindeki yolu
	if death_screen:
		death_screen.setup_and_show(AugmentManager.current_level, survival_time)

func heal(amount: float) -> void:
	var max_h = AugmentManager.player_stats["max_hp"]
	current_hp = clamp(current_hp + amount, 0, max_h)
	health_changed.emit(current_hp, max_h)

func _manage_aura_visibility() -> void:
	var levels = AugmentManager.mechanic_levels
	if levels.has("gold_2") and frost_aura and not frost_aura.visible: frost_aura.show(); _animate_vfx_entry(frost_aura)
	if levels.has("gold_7") and lifesteal_aura and not lifesteal_aura.visible: lifesteal_aura.show(); _animate_vfx_entry(lifesteal_aura)
	if levels.has("gold_9") and static_field_vfx and not static_field_vfx.visible: static_field_vfx.show(); _animate_vfx_entry(static_field_vfx)
	if levels.has("prism_2") and spell_weaver_aura:
		if not spell_weaver_aura.visible: spell_weaver_aura.show(); _animate_vfx_entry(spell_weaver_aura)
		if spell_weaver_aura.has_method("set_level"): spell_weaver_aura.set_level(levels["prism_2"])
	
	if levels.has("prism_5"):
		if not is_instance_valid(winter_aura_instance):
			winter_aura_instance = VFXPoolManager.spawn_vfx("eternal_winter", global_position)
			if winter_aura_instance:
				winter_aura_instance.reparent(self)
				winter_aura_instance.position = Vector3.ZERO
		if winter_aura_instance:
			if not winter_aura_instance.visible: winter_aura_instance.show(); _animate_vfx_entry(winter_aura_instance)
			if winter_aura_instance.has_method("set_radius"): winter_aura_instance.set_radius(AugmentManager.player_stats["winter_radius"])

func _animate_vfx_entry(node):
	node.scale = Vector3.ZERO
	create_tween().tween_property(node, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _process_active_auras():
	if AugmentManager.is_selection_active or get_tree().paused: return
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = SphereShape3D.new()
	shape.radius = AugmentManager.player_stats.get("pickup_range", 5.0) 
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

func _handle_dragon_breath_mechanic(delta: float):
	if not AugmentManager.mechanic_levels.has("prism_7"): return
	
	dragon_timer -= delta
	if dragon_timer <= 0.0:
		dragon_timer = dragon_cooldown
		_trigger_dragon_breath()

func _trigger_dragon_breath():
	var breath = VFXPoolManager.spawn_vfx("dragon_breath", Vector3.ZERO)
	
	if breath:
		if breath.get_parent() != body_mesh:
			breath.reparent(body_mesh)
		
		breath.position = Vector3(0, 0.8, 0.5) 
		breath.rotation = Vector3(0, PI, 0) 
		
		var lv = AugmentManager.mechanic_levels.get("prism_7", 1)
		var stats = {"damage": 60.0, "angle": 45.0, "duration": 2.5}
		
		var card_data = null
		if "tier_3_pool" in AugmentManager:
			for card in AugmentManager.tier_3_pool:
				if card.id == "prism_7":
					card_data = card
					break
		
		if card_data:
			for i in range(lv):
				if i < card_data["levels"].size():
					var level_info = card_data["levels"][i]
					if level_info.has("damage"): stats.damage = float(level_info["damage"])
					if level_info.has("angle"): stats.angle = float(level_info["angle"])
					if level_info.has("duration"): stats.duration = float(level_info["duration"])
		
		if breath.has_method("start_breath"):
			breath.start_breath(stats)

func _handle_mirror_image_mechanic(delta: float):
	if not AugmentManager.mechanic_levels.has("prism_8"): return
	
	clone_update_timer -= delta
	if clone_update_timer > 0: return
	clone_update_timer = 0.5
	
	var lv = AugmentManager.mechanic_levels["prism_8"]
	var target_count = 0
	var dmg_percent = 0.2
	
	var card_data = null
	if "tier_3_pool" in AugmentManager:
		for card in AugmentManager.tier_3_pool:
			if card.id == "prism_8": card_data = card; break
	
	if card_data:
		for i in range(lv):
			if i < card_data["levels"].size():
				var info = card_data["levels"][i]
				if info.has("count"): target_count = int(info["count"])
				if info.has("dmg"): dmg_percent = float(info["dmg"])
	
	var current_weapon = "ice_shard"
	if AugmentManager.mechanic_levels.has("weapon_snowball") or AugmentManager.mechanic_levels.has("snowball"):
		current_weapon = "snowball"
	
	for i in range(active_clones.size() - 1, -1, -1):
		if not is_instance_valid(active_clones[i]) or not active_clones[i].is_inside_tree():
			active_clones.remove_at(i)
	
	if active_clones.size() < target_count:
		var diff = target_count - active_clones.size()
		for i in range(diff):
			var clone = VFXPoolManager.spawn_vfx("mirror_image", global_position)
			if clone: active_clones.append(clone)
	
	elif active_clones.size() > target_count:
		var diff = active_clones.size() - target_count
		for i in range(diff):
			var clone = active_clones.pop_back()
			VFXPoolManager.return_to_pool(clone, "mirror_image")
			
	for i in range(active_clones.size()):
		var c = active_clones[i]
		if c.has_method("setup_stats"):
			c.setup_stats({"dmg": dmg_percent}, i, active_clones.size(), current_weapon)

func _handle_look_at(delta: float) -> void:
	if not is_finite(global_transform.basis.determinant()):
		global_transform = Transform3D.IDENTITY
		return

	var target_dir: Vector3 = Vector3.ZERO
	var wm = weapon_manager
	if not is_instance_valid(wm): wm = get_tree().get_first_node_in_group("weapon_manager")
	
	# 2. DÜŞMAN HEDEFLEME
	if is_instance_valid(wm) and wm.has_method("_find_closest_enemy"):
		var enemy = wm._find_closest_enemy()
		if is_instance_valid(enemy) and enemy.current_hp > 0:
			var dist = global_position.distance_to(enemy.global_position)
			if dist > 0.5: 
				target_dir = (enemy.global_position - global_position).normalized()
	
	# 3. HAREKET YÖNÜNE BAKMA (Düşman Yoksa)
	# Çok yavaşken dönmeye çalışma
	if target_dir.length() < 0.01 and velocity.length() > 0.5: 
		target_dir = velocity.normalized()
	
	# --- GÜVENLİ LOOK_AT (CRASH FIX) ---
	# Vektörün uzunluğu 0.1'den büyükse işlem yap
	if target_dir.length() > 0.1:
		target_dir.y = 0
		target_dir = target_dir.normalized()
		
		# Yukarı/Aşağı tam dik bakmayı engelle (Gimbal Lock)
		if abs(target_dir.dot(Vector3.UP)) > 0.99: return 
		
		var look_target = global_position + target_dir
		
		# Kendine bakmayı engelle (Mesafe kontrolü)
		if global_position.distance_squared_to(look_target) > 0.01:
			var look_transform = body_mesh.global_transform.looking_at(look_target, Vector3.UP)
			look_transform.basis = look_transform.basis.rotated(Vector3.UP, PI)
			
			# HATA DÜZELTİLDİ: Hesaplanan yeni matris bozuk mu (NaN) kontrol et
			if is_finite(look_transform.basis.determinant()):
				body_mesh.global_transform = body_mesh.global_transform.interpolate_with(look_transform, delta * 25.0)
				
				# Yamulmaları düzelt
				body_mesh.rotation.x = 0
				body_mesh.rotation.z = 0
