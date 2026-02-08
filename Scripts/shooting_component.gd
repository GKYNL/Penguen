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
	var waves = AugmentManager.player_stats.get("waves", 1)
	
	for w in range(waves):
		_perform_single_volley(spawn_pos, target_direction)
		if waves > 1:
			await get_tree().create_timer(0.15).timeout

func _perform_single_volley(origin: Vector3, dir: Vector3):
	var final_count = current_count
	if randf() < AugmentManager.player_stats.get("multishot_chance", 0.0):
		final_count += 2
	
	for i in range(final_count):
		var projectile = projectile_scene.instantiate()
		get_tree().root.add_child(projectile)
		
		# --- KRİTİK DÜZELTME ---
		# Mermiyi PAUSABLE yapıyoruz. Oyun durunca (Time Stop) bu da donacak.
		projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
		# -----------------------
		
		var spread_angle = 0.0
		if final_count > 1:
			if i % 2 == 1: spread_angle = deg_to_rad(15 * (i + 1) / 2.0)
			else: spread_angle = deg_to_rad(-15 * (i + 1) / 2.0)
			if i == 0: spread_angle = 0.0
		
		var final_dir = dir.rotated(Vector3.UP, spread_angle).normalized()
		projectile.global_position = origin
		
		if "damage" in projectile: 
			projectile.damage = current_damage * AugmentManager.player_stats.get("damage_mult", 1.0)
		
		if "pierce" in projectile: 
			projectile.pierce = current_pierce
			
		projectile.scale = Vector3.ONE * current_projectile_scale
		
		if projectile.get("direction"):
			projectile.direction = final_dir
		else:
			projectile.look_at(projectile.global_position + final_dir, Vector3.UP)
