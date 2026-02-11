extends Node

const SAVE_PATH = "user://savegame.json"

func save_game(): # Parantez içi BOŞ olmalı
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("Hata: Player grubu bulunamadı!")
		return

	# Mimariyi sadeleştirdik: Player = Pozisyon, AugmentManager = Her şey
	var data = {
		"level_path": get_tree().current_scene.scene_file_path,
		"player_pos": {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"z": player.global_position.z
		},
		"game_stats": {
			"hp": player.current_hp, # Can fiziksel bir durum olduğu için player'da kalsın
			"xp": AugmentManager.current_xp,
			"level": AugmentManager.current_level,
			"mechanic_levels": AugmentManager.mechanic_levels, # Tüm augmentler ve levelleri burada
			"player_stats": AugmentManager.player_stats # Bonus statlar (hız, hasar vb.)
		}
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	print("SİSTEM: AugmentManager ve Pozisyon başarıyla senkronize kaydedildi.")

func load_save_data():
	if not FileAccess.file_exists(SAVE_PATH): return null
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	return content

# Augment Seviyelerini AugmentManager'dan jilet gibi çeken yardımcı fonksiyon
func _get_detailed_augments():
	var detailed_list = []
	# AugmentManager'daki mechanic_levels senin gerçek listen
	for aug_id in AugmentManager.mechanic_levels:
		detailed_list.append({
			"id": aug_id,
			"level": AugmentManager.mechanic_levels[aug_id]
		})
	return detailed_list
