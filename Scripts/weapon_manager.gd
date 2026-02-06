extends Node3D
class_name WeaponManager

signal skill_fired(skill_name: String, cooldown: float)

@export var thunder_vfx: PackedScene
@export var echo_vfx: PackedScene
@onready var q_component = $thunderstrike
@onready var snowball_shooting_component = $snowball_shooting_component
@onready var ice_shard_shooting_component = $ice_shard_shooting_component

var unlocked_mechanics = []
var active_auto_weapon = null 
var cooldowns = {}
var attack_timer: Timer

func _ready():
	AugmentManager.mechanic_unlocked.connect(_on_mechanic_unlocked)
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.timeout.connect(_auto_primary_fire)
	attack_timer.start(1.0) 

func _process(_delta):
	_check_gold_mechanics()

func _check_gold_mechanics():
	if AugmentManager.mechanic_levels.has("gold_1") and not is_on_cooldown("Thunder"):
		_execute_thunderlord()

func _execute_thunderlord():
	var lv = AugmentManager.mechanic_levels["gold_1"]
	var count = [3, 5, 8, 12][lv-1]
	var enemies = get_tree().get_nodes_in_group("Enemies")
	
	var valid_enemies = enemies.filter(func(e): return is_instance_valid(e) and e.current_hp > 0)
	valid_enemies.shuffle()
	
	var targets_found = 0
	for i in range(min(count, valid_enemies.size())):
		var target = valid_enemies[i]
		if is_instance_valid(target):
			targets_found += 1
			_spawn_thunder_effect(target)
			target.take_damage([50, 80, 120, 200][lv-1])
	
	if targets_found > 0:
		var cd = 5.0 * (1.0 - AugmentManager.player_stats["cooldown_reduction"])
		start_cooldown("Thunder", cd)
		emit_signal("skill_fired", "Thunder", cd)

# HATA BURADAYDI, DÜZELTİLDİ
func _spawn_thunder_effect(target):
	if not thunder_vfx: return
	
	var t_vfx = thunder_vfx.instantiate()
	get_tree().root.add_child(t_vfx)
	t_vfx.global_position = target.global_position
	
	# MeshInstance3D'yi bulmak için daha sağlam bir yöntem (find_child hatası giderildi)
	var mesh_node: MeshInstance3D = null
	if t_vfx is MeshInstance3D:
		mesh_node = t_vfx
	else:
		# Sahne içindeki tüm MeshInstance3D'leri ara ve ilkini al
		var meshes = t_vfx.find_children("*", "MeshInstance3D", true, false)
		if meshes.size() > 0:
			mesh_node = meshes[0]
	
	if mesh_node:
		var mat = mesh_node.get_surface_override_material(0)
		if mat:
			var tw = create_tween()
			tw.tween_property(mat, "shader_parameter/vanish", 1.0, 0.3).set_delay(0.1)
			tw.finished.connect(t_vfx.queue_free)
		else:
			get_tree().create_timer(0.4).timeout.connect(t_vfx.queue_free)
	else:
		# Mesh yoksa bile belli bir süre sonra sil ki memory dolmasın
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
		attack_timer.wait_time = 1.0 / (lv_data.get("fire_rate", 1.0) * AugmentManager.player_stats["attack_speed"])
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
			if active_auto_weapon == "snowball": snowball_shooting_component.shoot(dir)
			else: ice_shard_shooting_component.shoot(dir)
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
	await get_tree().create_timer(t).timeout
	cooldowns.erase(s)
