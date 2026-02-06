extends Node3D
class_name WeaponManager

signal skill_fired(skill_name: String, cooldown: float)

@export var thunder_vfx: PackedScene
@onready var snowball_shooting_component = $snowball_shooting_component
@onready var ice_shard_shooting_component = $ice_shard_shooting_component

var cooldowns = {}
var attack_timer: Timer
var active_auto_weapon = null

func _ready():
	# KRİTİK DÜZELTME: Bu satır olmazsa düşmanlar bu scripti bulamaz!
	add_to_group("weapon_manager")
	
	AugmentManager.mechanic_unlocked.connect(_on_mechanic_unlocked)
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.timeout.connect(_auto_primary_fire)
	attack_timer.start(1.0) 

func _process(_delta):
	# Thunderlord Kontrolü
	if AugmentManager.mechanic_levels.get("gold_1", 0) > 0 and not is_on_cooldown("Thunder"):
		_execute_thunderlord()

# MERKEZİ DÜŞMAN ÖLÜM YÖNETİMİ
func on_enemy_killed(enemy_node):
	var pos = enemy_node.global_position
	
	# Silver 5: Vampirism
	var heal_val = AugmentManager.player_stats.get("lifesteal_flat", 0)
	if heal_val > 0:
		var player = get_tree().get_first_node_in_group("player")
		if player: player.heal(heal_val)
	
	# Gold 10: Alchemist
	if AugmentManager.mechanic_levels.get("gold_10", 0) > 0:
		var luck = AugmentManager.player_stats.get("luck", 0.0)
		# Şansına göre ekstra ödül mantığı buraya eklenebilir
	
	# Gold 4: Chain Reaction (Patlama)
	if AugmentManager.mechanic_levels.get("gold_4", 0) > 0:
		var lvl = AugmentManager.mechanic_levels["gold_4"]
		var chance = [0.1, 0.2, 0.3, 0.5][lvl-1]
		if randf() < chance:
			_spawn_explosion(pos, lvl)

func _spawn_explosion(pos, lvl):
	var radius = 5.0 if lvl < 3 else 8.0
	var damage = 30.0 * lvl
	
	if thunder_vfx:
		var vfx = thunder_vfx.instantiate()
		get_tree().root.add_child(vfx)
		vfx.global_position = pos
		# Efekti 0.6sn sonra kesin temizle
		get_tree().create_timer(0.6).timeout.connect(vfx.queue_free)
	
	var enemies = get_tree().get_nodes_in_group("Enemies")
	for e in enemies:
		if is_instance_valid(e) and e.global_position.distance_to(pos) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(damage)

func calculate_damage(base_damage: float, target_node = null) -> float:
	var final_damage = base_damage * AugmentManager.player_stats.get("damage_mult", 1.0)
	
	if target_node and AugmentManager.mechanic_levels.get("gold_5", 0) > 0:
		if target_node.is_in_group("Tank") or target_node.get("is_tank"):
			var lvl = AugmentManager.mechanic_levels["gold_5"]
			final_damage *= (1.0 + [0.2, 0.4, 0.6, 1.0][lvl-1])
			
	if target_node and AugmentManager.player_stats["execution_threshold"] > 0:
		var hp_pct = target_node.current_hp / target_node.max_hp
		if hp_pct <= AugmentManager.player_stats["execution_threshold"]:
			final_damage *= 2.0 
			
	return final_damage

func _execute_thunderlord():
	var lvl = AugmentManager.mechanic_levels["gold_1"]
	var count = [3, 5, 8, 12][lvl-1]
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var valid_enemies = enemies.filter(func(e): return is_instance_valid(e) and e.current_hp > 0)
	
	if valid_enemies.is_empty(): return
	valid_enemies.shuffle()
	
	var targets_found = 0
	for i in range(min(count, valid_enemies.size())):
		var target = valid_enemies[i]
		if is_instance_valid(target):
			targets_found += 1
			_spawn_thunder_effect(target)
			var dmg = calculate_damage([50, 80, 120, 200][lvl-1], target)
			target.take_damage(dmg)
	
	if targets_found > 0:
		var cd = 5.0 * (1.0 - AugmentManager.player_stats.get("cooldown_reduction", 0.0))
		start_cooldown("Thunder", cd)
		emit_signal("skill_fired", "Thunder", cd)

func _spawn_thunder_effect(target):
	if not thunder_vfx: return
	var t_vfx = thunder_vfx.instantiate()
	get_tree().root.add_child(t_vfx)
	t_vfx.global_position = target.global_position
	
	# Görsel temizliği için
	var mesh_node = t_vfx if t_vfx is MeshInstance3D else t_vfx.find_child("MeshInstance3D", true, false)
	if mesh_node:
		var mat = mesh_node.get_surface_override_material(0)
		if mat:
			var tw = create_tween()
			tw.tween_property(mat, "shader_parameter/vanish", 1.0, 0.3).set_delay(0.1)
			tw.finished.connect(t_vfx.queue_free)
		else:
			get_tree().create_timer(0.4).timeout.connect(t_vfx.queue_free)
	else:
		get_tree().create_timer(0.5).timeout.connect(t_vfx.queue_free)

func _on_mechanic_unlocked(id: String):
	if id.begins_with("start_"): active_auto_weapon = id.replace("start_", "")
	_update_weapon_stats()

func _update_weapon_stats():
	if not active_auto_weapon: return
	var weapon_id = "start_" + active_auto_weapon
	var lv_data = _get_weapon_level_data(weapon_id)
	
	if lv_data:
		var comp = snowball_shooting_component if active_auto_weapon == "snowball" else ice_shard_shooting_component
		var base_fire_rate = lv_data.get("fire_rate", 1.0)
		var attack_speed_mult = AugmentManager.player_stats["attack_speed"]
		var cdr = AugmentManager.player_stats.get("cooldown_reduction", 0.0)
		
		var base_wait = 1.0 / (base_fire_rate * attack_speed_mult)
		attack_timer.wait_time = max(0.1, base_wait * (1.0 - cdr))
		
		comp.current_damage = float(lv_data.get("damage", 10.0))
		comp.current_count = int(lv_data.get("count", 1))
		comp.current_pierce = int(lv_data.get("pierce", 1))

func _auto_primary_fire():
	if not active_auto_weapon: return
	var target = _find_closest_enemy()
	if target:
		var dir = (target.global_position - global_position).normalized()
		dir.y = 0
		var waves = 1
		if AugmentManager.mechanic_levels.has("gold_6"): 
			waves = [2, 2, 3, 4][AugmentManager.mechanic_levels["gold_6"]-1]
		
		for w in range(waves):
			# Triple Shot
			var ms_chance = AugmentManager.player_stats.get("multishot_chance", 0.0)
			var shots = 1
			if ms_chance > 0 and randf() < ms_chance:
				shots = 3
			
			for s in range(shots):
				var final_dir = dir
				if shots > 1:
					var angle = deg_to_rad((s - 1) * 15.0)
					final_dir = dir.rotated(Vector3.UP, angle)

				if active_auto_weapon == "snowball": 
					snowball_shooting_component.shoot(final_dir)
				else: 
					ice_shard_shooting_component.shoot(final_dir)
					
			if waves > 1: await get_tree().create_timer(0.2).timeout

func _get_weapon_level_data(id):
	var lv = AugmentManager.mechanic_levels.get(id, 1)
	for item in AugmentManager.tier_1_pool:
		if item.id == id: return item.levels[lv-1]
	return {}

func _find_closest_enemy():
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var closest = null; var min_d = 40.0
	for e in enemies:
		if is_instance_valid(e) and e.current_hp > 0:
			var d = global_position.distance_to(e.global_position)
			if d < min_d: min_d = d; closest = e
	return closest

func is_on_cooldown(s): return cooldowns.has(s)
func start_cooldown(s, t):
	cooldowns[s] = true
	get_tree().create_timer(t).timeout.connect(func(): cooldowns.erase(s))
