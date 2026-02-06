extends Node3D


func execute_skill():
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var radius = 40.0 
	
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) <= radius:
			if enemy.has_method("apply_freeze"):
				enemy.apply_freeze(5.0) 
	return true
	
	
	
