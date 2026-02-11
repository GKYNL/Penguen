extends Node

const SAVE_PATH = "user://savegame.json"

func save_game():
	var player = get_tree().get_first_node_in_group("player")
	if not player: 
		print("Hata: Player bulunamadı!")
		return

	var data = {
		"level": get_tree().current_scene.scene_file_path,
		"player": {
			"pos_x": player.global_position.x,
			"pos_y": player.global_position.y,
			"pos_z": player.global_position.z,
			"health": player.get("health"),
			"mana": player.get("mana"),
			# XP SİSTEMİ
			"current_xp": player.get("current_xp"),
			"player_level": player.get("player_level"),
			# STATLAR
			"stats": player.get("stats"),
			# AUGMENTLER (İsim ve Level olarak detaylı)
			"augments": _get_augment_data(player),
			"cooldowns": _get_player_cds(player)
		},
		"enemies": _get_enemy_data()
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("XP ve Augment seviyeleri başarıyla kaydedildi!")

# Augmentlerin sadece adını değil, içindeki levelleri de alalım
func _get_augment_data(player):
	var aug_list = []
	# player.augments'in içinde [{"name": "IceDash", "level": 2}, ...] şeklinde tuttuğunu varsayıyorum
	if player.get("augments") is Array:
		for aug in player.augments:
			aug_list.append(aug) 
	return aug_list

func _get_player_cds(player):
	var cds = {}
	if player.has_node("SkillTimers"):
		for timer in player.get_node("SkillTimers").get_children():
			cds[timer.name] = timer.time_left
	return cds

func _get_enemy_data():
	var enemies = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var e_data = {
			"type": enemy.scene_file_path,
			"pos_x": enemy.global_position.x,
			"pos_y": enemy.global_position.y,
			"pos_z": enemy.global_position.z, # Düşmanlar da 3D, Z ekseni şart!
			"hp": enemy.get("health")
		}
		enemies.append(e_data)
	return enemies

func load_save_data():
	if not FileAccess.file_exists(SAVE_PATH): return null
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	return JSON.parse_string(content)
