extends Node3D

@export var lightning_vfx_scene: PackedScene
@export var damage: int = 100
@export var aoe_radius: float = 4.0
@export var search_radius: float = 25.0 # Oyuncunun ne kadar uzağını görebildiği
@export var lightning_duration: float = 0.2
@export var min_damage_percent: float = 0.2 

func execute_skill() -> bool:
	# Artık sadece yakındaki en güçlüyü buluyor
	var target = find_strongest_enemy_in_range()
	
	if target:
		apply_aoe_damage(target.global_position)
		
		if lightning_vfx_scene:
			var vfx = lightning_vfx_scene.instantiate()
			get_tree().root.add_child(vfx)
			
			var camera = get_viewport().get_camera_3d()
			var to_cam = (camera.global_position - target.global_position).normalized()
			vfx.global_position = target.global_position + (to_cam * 0.5)
			
			vfx.scale = Vector3(aoe_radius, 1.0, aoe_radius) 
			
			await get_tree().create_timer(lightning_duration).timeout
			if is_instance_valid(vfx):
				vfx.queue_free()
		return true
	
	print("Menzilde düşman yok!")
	return false

# --- AOE HASAR MANTIĞI AYNI KALIYOR ---
func apply_aoe_damage(center_pos: Vector3):
	var enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		var distance = center_pos.distance_to(enemy.global_position)
		if distance <= aoe_radius:
			if enemy.has_method("take_damage"):
				var falloff = 1.0 - (distance / aoe_radius)
				falloff = max(falloff, min_damage_percent) 
				var final_damage = int(damage * falloff)
				enemy.take_damage(final_damage)

# --- YENİ OPTİMİZE HEDEFLEME ---
func find_strongest_enemy_in_range() -> Node3D:
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var best_target = null
	var max_hp = -1.0
	
	# Oyuncu referansını al (Skill genelde oyuncunun altındadır veya pozisyonu bellidir)
	var player_pos = global_position 
	
	for enemy in enemies:
		# 1. Kontrol: Menzil içinde mi?
		var dist_to_player = player_pos.distance_to(enemy.global_position)
		
		if dist_to_player <= search_radius:
			# 2. Kontrol: En güçlüsü bu mu?
			if enemy.get("current_hp") != null and enemy.current_hp > max_hp:
				max_hp = enemy.current_hp
				best_target = enemy
				
	return best_target
