extends MeshInstance3D

var is_exploding: bool = false
var explosion_radius: float = 0.0
var explosion_damage: float = 0.0
var damaged_enemies: Array = []

func play_effect(base_damage: float):
	# 1. VERİ ANALİZİ
	var id = "gold_4"
	var current_lv = AugmentManager.mechanic_levels.get(id, 1)
	var level_data = _get_json_level_data(id, current_lv)
	
	explosion_radius = float(level_data.get("radius", 4.0)) if level_data else 4.0
	explosion_damage = base_damage * 2.0
	
	# 2. GÖRSEL ÖLÇEKLENDİRME
	scale = Vector3.ONE * explosion_radius
	
	# 3. AKTİVASYON
	is_exploding = true
	damaged_enemies.clear()
	
	# 4. SHADER VE SİLİNME
	_animate_shader()

func _process(_delta):
	if is_exploding:
		_check_for_enemies_in_area()

func _check_for_enemies_in_area():
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var my_pos = global_position
	my_pos.y = 0 

	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dying"):
			if enemy in damaged_enemies: continue
			
			var enemy_pos = enemy.global_position
			enemy_pos.y = 0
			
			if my_pos.distance_to(enemy_pos) <= (explosion_radius + 0.2):
				if enemy.has_method("take_damage"):
					enemy.take_damage(explosion_damage)
					damaged_enemies.append(enemy)

func _animate_shader():
	var mat = mesh.material as ShaderMaterial
	if mat:
		var local_mat = mat.duplicate()
		mesh.material = local_mat
		local_mat.set_shader_parameter("progress", 0.0)
		
		var tw = create_tween()
		tw.tween_property(local_mat, "shader_parameter/progress", 1.0, 0.4)
		tw.finished.connect(func():
			is_exploding = false
			queue_free()
		)
	else:
		queue_free()

func _get_json_level_data(aug_id: String, lv: int):
	for aug in AugmentManager.tier_2_pool:
		if aug.id == aug_id:
			var idx = clamp(lv - 1, 0, aug.levels.size() - 1)
			return aug.levels[idx]
	return null
