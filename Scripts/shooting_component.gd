extends Node3D

@export var projectile_scene: PackedScene 
@export var shoot_origin_path: NodePath 

@onready var shoot_origin = get_node_or_null(shoot_origin_path)

var current_damage: float = 10.0
var current_projectile_scale: float = 1.0
var current_pierce: int = 1
var current_count: int = 1 

func shoot(target_direction: Vector3):
	if not projectile_scene: return
	
	var spawn_pos = shoot_origin.global_position if shoot_origin else global_position
	
	# STAT BAĞLANTISI: Multishot Chance
	var final_count = current_count
	if randf() < AugmentManager.player_stats.get("multishot_chance", 0.0):
		final_count += 2 # Triple shot bonus
	
	for i in range(final_count):
		var projectile = projectile_scene.instantiate()
		get_tree().root.add_child(projectile)
		
		var offset_dist = i * 0.6 
		projectile.global_position = spawn_pos - (target_direction * offset_dist)
		
		# STAT BAĞLANTISI: Damage Mult
		if "damage" in projectile: 
			projectile.damage = current_damage * AugmentManager.player_stats["damage_mult"]
		
		if "pierce" in projectile: projectile.pierce = current_pierce
		projectile.scale = Vector3.ONE * current_projectile_scale
		
		var spread_val = 0.1 if final_count > 1 else 0.0
		var spread_vec = Vector3(randf_range(-spread_val, spread_val), 0, randf_range(-spread_val, spread_val))
		var final_dir = (target_direction + spread_vec).normalized()
		
		if final_dir.length() > 0.01:
			projectile.look_at(projectile.global_position + final_dir, Vector3.UP)
