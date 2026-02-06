extends MeshInstance3D

func play_effect(base_damage: float):
	# 1. Verileri Çek
	var lv = AugmentManager.mechanic_levels.get("gold_4", 1)
	var radius = [3.0, 4.0, 5.0, 6.0][lv-1]
	var final_damage = base_damage * 2.0
	
	# 2. MESAFE BAZLI HASAR (Collision Yok!)
	_apply_distance_damage(radius, final_damage)
	
	# 3. Görsel Animasyon
	_animate_explosion(radius)

func _apply_distance_damage(radius: float, damage_amount: float):
	# Sahnedeki tüm düşmanları tara
	var enemies = get_tree().get_nodes_in_group("Enemies")
	
	for enemy in enemies:
		# Güvenlik kontrolü (Düşman hala oradaysa)
		if is_instance_valid(enemy):
			# Matematiksel mesafe hesabı: Düşman patlama merkezine ne kadar yakın?
			var dist = global_position.distance_to(enemy.global_position)
			
			# Eğer mesafe yarıçaptan küçükse, GÜM!
			if dist <= radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage_amount)

func _animate_explosion(radius: float):
	scale = Vector3.ZERO
	var mat = get_surface_override_material(0)
	if mat: mat.set_shader_parameter("progress", 0.0)
	
	var tw = create_tween().set_parallel(true)
	# Görsel çap (radius * 2)
	tw.tween_property(self, "scale", Vector3.ONE * radius * 2.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if mat:
		tw.tween_property(mat, "shader_parameter/progress", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tw.chain().tween_callback(queue_free)
