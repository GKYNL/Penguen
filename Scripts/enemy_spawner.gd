extends Node3D

@export_group("Wave Settings")
@export var enemy_scene: PackedScene
@export var base_spawn_interval: float = 2.5 
@export var final_spawn_interval: float = 0.5 
@export var max_enemies_per_spawn: int = 8    
@export var spawn_radius: float = 22.0        
@export var is_active: bool = false 

@export_group("Difficulty")
@export var max_enemy_cap: int = 120 
@export var stage_duration: float = 60.0 

var player = null
var current_stage: int = 1
var start_time: float = 0.0

@onready var spawn_timer: Timer = Timer.new()
@onready var difficulty_timer: Timer = Timer.new() # Yeni zorluk hesaplayıcı

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	# Spawn Timer ayarları
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	# Difficulty Timer ayarları (Saniyede 2 kez çalışması yeterli)
	add_child(difficulty_timer)
	difficulty_timer.wait_time = 0.5 
	difficulty_timer.timeout.connect(_update_difficulty_settings)
	
	if not AugmentManager.is_connected("mechanic_unlocked", _start_horde):
		AugmentManager.mechanic_unlocked.connect(_start_horde)

func _start_horde(_id):
	if is_active: return 
	is_active = true
	start_time = Time.get_ticks_msec() / 1000.0
	
	spawn_timer.wait_time = base_spawn_interval
	spawn_timer.start()
	
	difficulty_timer.start() # Zorluk takibi başlasın
	_spawn_batch(1)

# ESKİ _PROCESS YERİNE BURASI ÇALIŞACAK (Saniyede sadece 2 kez!)
func _update_difficulty_settings():
	if not is_active: return
	
	var player_power = _calculate_player_power()
	
	# Spawn hızını güncelle
	var power_factor = clamp(player_power / 400.0, 0.0, 1.0) 
	spawn_timer.wait_time = lerp(base_spawn_interval, final_spawn_interval, power_factor)
	
	# Stage/Zorluk seviyesini güncelle
	current_stage = clamp(1 + int(player_power / 80.0), 1, 10)

func _calculate_player_power() -> float:
	var stats = AugmentManager.player_stats
	var power = 0.0
	
	power += (stats["max_hp"] - 100.0) * 0.3
	power += (stats["speed"] - 12.5) * 3.0
	power += (stats["damage_mult"] - 1.0) * 60.0 
	power += (stats["attack_speed"] - 1.0) * 40.0
	power += (stats["lifesteal_flat"]) * 10.0
	
	if AugmentManager.active_weapon_id != "":
		var weapon_lvl = AugmentManager.mechanic_levels.get(AugmentManager.active_weapon_id, 0)
		power += weapon_lvl * 15.0 
		if weapon_lvl >= 3: power += 25.0 
		if weapon_lvl >= 4: power += 50.0 

	for m_id in AugmentManager.mechanic_levels:
		if m_id != AugmentManager.active_weapon_id:
			var m_lvl = AugmentManager.mechanic_levels[m_id]
			power += m_lvl * 15.0 

	return power

func _on_spawn_timer_timeout():
	if not is_active or not player or not enemy_scene: return
	var enemies_in_scene = get_tree().get_nodes_in_group("Enemies").size()
	if enemies_in_scene >= max_enemy_cap: return

	var player_power = _calculate_player_power()
	
	var count = 1
	if player_power > 50.0:
		count = int(lerp(1.5, float(max_enemies_per_spawn), (player_power - 50.0) / 300.0))
	
	var min_spawn = 1
	if player_power > 150.0: min_spawn = 2
	if player_power > 300.0: min_spawn = 3 
	
	_spawn_batch(clamp(count, min_spawn, max_enemies_per_spawn))

func _spawn_batch(amount: int):
	for i in range(amount):
		var angle = randf() * TAU
		var offset = Vector3(cos(angle), 0, sin(angle)) * spawn_radius
		var spawn_pos = player.global_position + offset
		spawn_pos.y = 2.0
		
		var enemy = enemy_scene.instantiate()
		get_tree().root.add_child(enemy)
		enemy.global_position = spawn_pos
		enemy.stage = current_stage
		
		var player_power = _calculate_player_power()
		
		var elite_chance = 0.0
		if player_power > 200.0: 
			elite_chance = min(0.01 * ((player_power - 200.0) / 20.0), 0.25)
		
		var archer_chance = 0.0
		if player_power > 100.0: 
			archer_chance = min(0.02 * ((player_power - 100.0) / 20.0), 0.4)
			
		if randf() < elite_chance: enemy.make_elite()
		if randf() < archer_chance: enemy.make_archer()
