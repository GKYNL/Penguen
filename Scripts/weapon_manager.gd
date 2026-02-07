extends Node3D
class_name WeaponManager

signal skill_fired(skill_name: String, cooldown: float)

@export var thunder_vfx: PackedScene
@export var echo_vfx: PackedScene
@export var explosion_vfx: PackedScene 

@onready var snowball_shooting_component = $snowball_shooting_component
@onready var ice_shard_shooting_component = $ice_shard_shooting_component

var active_auto_weapon = null 
var cooldowns = {}
var attack_timer: Timer

func _ready():
	if not is_in_group("weapon_manager"):
		add_to_group("weapon_manager")
		
	AugmentManager.mechanic_unlocked.connect(_on_mechanic_unlocked)
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.timeout.connect(_auto_primary_fire)
	attack_timer.start(1.0) 
	
	if not explosion_vfx:
		explosion_vfx = load("res://vfx/vfx_explosion.tscn")

func _process(_delta):
	# Thunderlord Kontrolü
	if AugmentManager.mechanic_levels.get("gold_1", 0) > 0 and not is_on_cooldown("Thunder"):
		_execute_thunderlord()

# --- MERKEZİ ANALİZ FONKSİYONU (GÜVENLİ) ---
func _get_lv_data(aug_id: String):
	var lv = AugmentManager.mechanic_levels.get(aug_id, 0)
	if lv <= 0: return null
	
	var pools = [AugmentManager.tier_1_pool, AugmentManager.tier_2_pool, AugmentManager.tier_3_pool]
	for pool in pools:
		# Yeni JSON yapısı (Dictionary içinde 'augments')
		if pool is Dictionary and pool.has("augments"):
			for aug in pool["augments"]:
				if aug.id == aug_id:
					var levels = aug.get("levels", [])
					return levels[clamp(lv - 1, 0, levels.size() - 1)]
		# Eski JSON yapısı (Direkt Array)
		elif pool is Array:
			for aug in pool:
				if aug.id == aug_id:
					var levels = aug.get("levels", [])
					# Eğer levels yoksa (Stat kartıysa) null döner
					if levels.is_empty(): return null
					return levels[clamp(lv - 1, 0, levels.size() - 1)]
	return null

# --- MERKEZİ COOLDOWN HESAPLAYICI ---
func calculate_cooldown(base_cd: float) -> float:
	var cdr_stat = AugmentManager.player_stats.get("cooldown_reduction", 0.0)
	var final_cd = base_cd * (1.0 - cdr_stat)
	return max(0.05, final_cd)

# --- ÖLÜM YÖNETİMİ (VAMPIRISM FIX) ---
func on_enemy_killed(enemy_node):
	var pos = enemy_node.global_position
	
	# DÜZELTME: Vampirism için JSON araması YAPMA.
	# Doğrudan stat'ı oku. Çünkü Silver 5 seçilince stat zaten artıyor.
	var lifesteal_amount = AugmentManager.player_stats.get("lifesteal_flat", 0)
	if lifesteal_amount > 0:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("heal"):
			player.heal(float(lifesteal_amount))
	
	# Gold 4: Chain Reaction
	var chain_data = _get_lv_data("gold_4")
	if chain_data:
		var chance = float(chain_data.get("chance", 0.1))
		if randf() < chance:
			_spawn_explosion(pos, chain_data)

func _spawn_explosion(pos, data):
	var radius = float(data.get("radius", 5.0))
	var damage = float(data.get("damage", 30.0))
	
	if explosion_vfx:
		var vfx = explosion_vfx.instantiate()
		get_tree().root.add_child(vfx)
		vfx.global_position = pos
		if vfx.has_method("play_effect"):
			vfx.play_effect(damage)
	
	_deal_aoe_damage(pos, radius, damage)

func _deal_aoe_damage(pos, radius, dmg):
	var enemies = get_tree().get_nodes_in_group("Enemies")
	for e in enemies:
		if is_instance_valid(e) and not e.get("is_dying") and e.global_position.distance_to(pos) <= radius:
			e.take_damage(dmg)

# --- HASAR HESAPLAMA ---
func calculate_damage(base_damage: float, target_node = null) -> float:
	var final_damage = base_damage * AugmentManager.player_stats.get("damage_mult", 1.0)
	
	if target_node and (target_node.is_in_group("Tank") or target_node.get("is_tank")):
		var gs_data = _get_lv_data("gold_5")
		if gs_data:
			var bonus = float(gs_data.get("tank_damage_mult", 0.2))
			final_damage *= (1.0 + bonus)
			
	if target_node and AugmentManager.player_stats["execution_threshold"] > 0:
		var hp_pct = target_node.current_hp / target_node.max_hp
		if hp_pct <= AugmentManager.player_stats["execution_threshold"]:
			final_damage *= 2.0 
			
	return final_damage

# --- THUNDERLORD ---
func _execute_thunderlord():
	var data = _get_lv_data("gold_1")
	if not data: return
	
	var count = int(data.get("count", 3))
	var base_dmg = float(data.get("damage", 50.0))
	
	var base_cd = float(data.get("cooldown", 5.0))
	var final_cd = calculate_cooldown(base_cd)
	
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var valid_enemies = enemies.filter(func(e): return is_instance_valid(e) and e.current_hp > 0)
	
	if valid_enemies.is_empty(): return
	valid_enemies.shuffle()
	
	var targets_found = 0
	for i in range(min(count, valid_enemies.size())):
		var target = valid_enemies[i]
		targets_found += 1
		_spawn_thunder_effect(target)
		target.take_damage(calculate_damage(base_dmg, target))
	
	if targets_found > 0:
		start_cooldown("Thunder", final_cd)
		emit_signal("skill_fired", "Thunder", final_cd)

func _spawn_thunder_effect(target):
	if not thunder_vfx: return
	var t_vfx = thunder_vfx.instantiate()
	get_tree().root.add_child(t_vfx)
	t_vfx.global_position = target.global_position
	
	var mesh_node = t_vfx if t_vfx is MeshInstance3D else t_vfx.find_child("MeshInstance3D", true, false)
	if mesh_node:
		var mat = mesh_node.get_surface_override_material(0)
		if mat:
			var local_mat = mat.duplicate()
			mesh_node.set_surface_override_material(0, local_mat)
			var tw = create_tween()
			tw.tween_property(local_mat, "shader_parameter/vanish", 1.0, 0.3).set_delay(0.1)
			tw.finished.connect(t_vfx.queue_free)
		else:
			get_tree().create_timer(0.4).timeout.connect(t_vfx.queue_free)
	else:
		get_tree().create_timer(0.5).timeout.connect(t_vfx.queue_free)

# --- AUTO FIRE ---
func _auto_primary_fire():
	if not active_auto_weapon: return
	var target = _find_closest_enemy()
	if not target: return
	
	var dir = (target.global_position - global_position).normalized()
	dir.y = 0
	
	var echo_data = _get_lv_data("gold_6")
	var waves = int(echo_data.get("waves", 1)) if echo_data else 1
	
	for w in range(waves):
		_fire_projectile_batch(dir)
		if waves > 1: await get_tree().create_timer(0.15).timeout

func _fire_projectile_batch(dir):
	var ms_chance = AugmentManager.player_stats.get("multishot_chance", 0.0)
	var shots = 3 if (ms_chance > 0 and randf() < ms_chance) else 1
	
	var comp = snowball_shooting_component if active_auto_weapon == "snowball" else ice_shard_shooting_component
	
	for s in range(shots):
		var final_dir = dir
		if shots > 1:
			var angle = deg_to_rad((s - 1) * 15.0)
			final_dir = dir.rotated(Vector3.UP, angle)
		comp.shoot(final_dir)

func _on_mechanic_unlocked(id: String):
	if id.begins_with("start_"): 
		active_auto_weapon = id.replace("start_", "")
	_update_weapon_stats()

func _update_weapon_stats():
	if not active_auto_weapon: return
	var data = _get_lv_data("start_" + active_auto_weapon)
	if data:
		var comp = snowball_shooting_component if active_auto_weapon == "snowball" else ice_shard_shooting_component
		
		var base_fire_rate = float(data.get("fire_rate", 1.0))
		var base_wait = 1.0 / (base_fire_rate * AugmentManager.player_stats["attack_speed"])
		var cdr = AugmentManager.player_stats.get("cooldown_reduction", 0.0)
		attack_timer.wait_time = max(0.05, base_wait * (1.0 - cdr))
		
		comp.current_damage = float(data.get("damage", 10.0))
		comp.current_count = int(data.get("count", 1))
		comp.current_pierce = int(data.get("pierce", 1))

func _find_closest_enemy():
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var closest = null; var min_d = 45.0
	for e in enemies:
		if is_instance_valid(e) and e.current_hp > 0:
			var d = global_position.distance_to(e.global_position)
			if d < min_d: min_d = d; closest = e
	return closest

func is_on_cooldown(s): return cooldowns.has(s)
func start_cooldown(s, t):
	cooldowns[s] = true
	get_tree().create_timer(t).timeout.connect(func(): cooldowns.erase(s))
