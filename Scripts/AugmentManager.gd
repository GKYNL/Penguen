extends Node

signal level_changed(new_level)
signal xp_changed(current_xp, max_xp)
signal show_augment_selection(cards)
signal mechanic_unlocked(mechanic_id)
signal augment_selected(aug_name, aug_description)

var current_level = 1
var current_xp = 0
var max_xp = 100
var active_weapon_id = ""
var max_gold_slots: int = 5
var max_prism_slots: int = 2

# YENİ: Kart seçimi sırasında Player'ı dondurmak için bayrak
var is_selection_active: bool = false

# OYUNCU STATLARI
var player_stats = {
	"max_hp": 100.0,
	"speed": 12.5,
	"damage_mult": 1.0,
	"attack_speed": 1.0,
	"cooldown_reduction": 0.0,
	"pickup_range": 20.0,
	"freeze_duration": 4.0,
	"attack_range": 0.20,
	"dash_cooldown": 3.0,
	"lifesteal_flat": 0,
	"execution_threshold": 0.0,
	"luck": 0.0,
	"gold_bonus": 0.0,
	"armor": 0.0,
	"multishot_chance": 0.0,
	"waves": 1,
	"dash_charges": 1,
	"thorns": 0.0,
	"stomp_damage": 0.0,
	"winter_damage": 0.0,
	"winter_radius": 0.0,
	"winter_slow": 0.0,
	"time_stop_duration": 0.0,
	"time_stop_cooldown_mult": 1.0
}

var active_gold_ids = []  
var active_prism_ids = [] 
var mechanic_levels = {}   

var tier_1_pool = []
var tier_2_pool = []
var tier_3_pool = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_augment_data()

func initialize_game_start():
	print("AugmentManager: Oyun baslatiliyor...")
	_setup_initial_mechanics()
	emit_signal("level_changed", current_level)
	#await get_tree().create_timer(3).timeout
	#_force_unlock_augment("prism_6", 4) 

func _setup_initial_mechanics():
	current_level = 1
	current_xp = 0
	active_gold_ids = []
	active_prism_ids = []
	mechanic_levels = {}
	is_selection_active = false
	
	player_stats = {
		"max_hp": 100.0, "speed": 12.5, "damage_mult": 1.0, "attack_speed": 1.0,
		"cooldown_reduction": 0.0, "pickup_range": 20.0, "freeze_duration": 4.0,
		"attack_range": 0.20, "dash_cooldown": 3.0, "lifesteal_flat": 0,
		"execution_threshold": 0.0, "luck": 0.0, "gold_bonus": 0.0, "armor": 0.0,
		"multishot_chance": 0.0, "waves": 1, "dash_charges": 1, "thorns": 0.0,
		"stomp_damage": 0.0, "winter_damage": 0.0, "winter_radius": 0.0, "winter_slow": 0.0,
		"time_stop_duration": 0.0, "time_stop_cooldown_mult": 1.0
	}
	
	emit_signal("mechanic_unlocked", "init")

func _force_unlock_augment(aug_id: String, level: int = 1):
	mechanic_levels[aug_id] = level
	
	if aug_id.begins_with("gold"):
		if not aug_id in active_gold_ids: active_gold_ids.append(aug_id)
	elif aug_id.begins_with("prism"):
		if not aug_id in active_prism_ids: active_prism_ids.append(aug_id)

	var found_card = null
	for pool in [tier_1_pool, tier_2_pool, tier_3_pool]:
		if pool is Dictionary and pool.has("augments"):
			for card in pool["augments"]:
				if card.id == aug_id: found_card = card; break
		elif pool is Array:
			for card in pool:
				if card.id == aug_id: found_card = card; break
		if found_card: break

	if found_card:
		print("Force Unlock: ", aug_id, " Lv.", level)
		_update_special_mechanic_stats(found_card, level)
		emit_signal.call_deferred("mechanic_unlocked", aug_id)

func load_augment_data():
	var file_path = "res://Data/augments.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data:
			tier_1_pool = data.get("tier_1_pool", [])
			tier_2_pool = data.get("tier_2_pool", [])
			tier_3_pool = data.get("tier_3_pool", [])
			print("JSON Verisi Yuklendi.")

func apply_augment(card_data):
	var a_id = card_data.get("id", "")
	var a_name = card_data.get("name", "Gelistirme")
	var a_desc = card_data.get("desc", "")
	var type = card_data.get("type", "stat")
	var player = get_tree().get_first_node_in_group("player")
	
	emit_signal("augment_selected", a_name, a_desc)

	if type == "weapon_unlock":
		if active_weapon_id == "":
			active_weapon_id = a_id
			mechanic_levels[a_id] = 1
		else:
			mechanic_levels[a_id] = mechanic_levels.get(a_id, 0) + 1
		emit_signal("mechanic_unlocked", a_id)

	elif type == "mechanic":
		var new_lvl = mechanic_levels.get(a_id, 0) + 1
		mechanic_levels[a_id] = new_lvl
		
		var rarity = card_data.get("rarity", "")
		if rarity == "gold" and not a_id in active_gold_ids: 
			active_gold_ids.append(a_id)
		elif rarity == "prismatic" and not a_id in active_prism_ids: 
			active_prism_ids.append(a_id)
		
		_update_special_mechanic_stats(card_data, new_lvl)
		emit_signal("mechanic_unlocked", a_id)

	elif type == "stat":
		var s_name = card_data.get("stat", "")
		if player_stats.has(s_name):
			var val = card_data.get("val", 0.0)
			if s_name == "multishot_chance" and val > 1.0: val = val / 100.0
			player_stats[s_name] += val
			
			if s_name == "max_hp":
				if player and player.has_method("heal"): player.heal(val)
	
	# --- KART SEÇİMİ BİTTİ ---
	is_selection_active = false
	
	# KRİTİK KONTROL:
	# Eğer Player şu an "Time Stop" (Zaman Durdurma) modundaysa, oyunu UNPAUSE YAPMA!
	# Time Stop devam etmeli. Sadece Player'ın hareket kilidini (is_selection_active) kaldırdık.
	if player and player.get("is_time_stopped") == true:
		print("Kart secildi ama Time Stop aktif. Oyun PAUSE kalmaya devam ediyor.")
	else:
		get_tree().paused = false

func _update_special_mechanic_stats(card_data, level):
	var a_id = card_data.get("id", "")
	if not card_data.has("levels"): return
	
	var player = get_tree().get_first_node_in_group("player")
	
	match a_id:
		"gold_3": 
			var lv_data = card_data["levels"][level-1]
			player_stats["execution_threshold"] = lv_data.get("threshold", 0.1)
		"prism_2": 
			var lv_data = card_data["levels"][level-1]
			player_stats["cooldown_reduction"] = lv_data.get("val", 0.0)
			if player and player.has_method("update_prism_visuals"):
				player.update_prism_visuals("prism_2", level)
		"prism_3": # TITAN FORM
			var total_hp_bonus = 0.0
			var total_armor = 0.0
			var total_dmg_mult = 0.0
			var current_stomp = 0.0
			for i in range(level):
				var d = card_data["levels"][i]
				if d.has("hp_bonus"): total_hp_bonus += float(d["hp_bonus"])
				if d.has("armor"): total_armor += float(d["armor"])
				if d.has("dmg_bonus"): total_dmg_mult += float(d["dmg_bonus"])
				if d.has("stomp_dmg"): current_stomp = float(d["stomp_dmg"])
			
			player_stats["max_hp"] = 100.0 + total_hp_bonus
			player_stats["armor"] = total_armor
			player_stats["damage_mult"] = 1.0 + total_dmg_mult
			player_stats["stomp_damage"] = current_stomp
			
		"prism_5": # ETERNAL WINTER
			var total_dmg = 0.0
			var max_radius = 8.0
			var total_slow = 0.0
			for i in range(level):
				var d = card_data["levels"][i]
				if d.has("damage"): total_dmg += float(d["damage"])
				if d.has("radius"): max_radius = float(d["radius"])
				if d.has("freeze"): total_slow = float(d["freeze"])
			player_stats["winter_damage"] = total_dmg
			player_stats["winter_radius"] = max_radius
			player_stats["winter_slow"] = total_slow
			
		"prism_6": # TIME STOP
			var dur = 0.0
			var cd_mult = 1.0
			var d = card_data["levels"][level-1]
			if d.has("duration"): dur = float(d["duration"])
			if d.has("cd"): cd_mult = float(d["cd"])
			player_stats["time_stop_duration"] = dur
			player_stats["time_stop_cooldown_mult"] = cd_mult

	if player and player.has_method("sync_stats_from_manager"):
		player.sync_stats_from_manager()

func _prepare_card(card):
	var prepared = card.duplicate(true)
	var cur_lvl = mechanic_levels.get(prepared.id, 0)
	if prepared.has("levels") and prepared["levels"] is Array:
		var levels_array = prepared["levels"]
		if cur_lvl < levels_array.size():
			var next_level_data = levels_array[cur_lvl]
			if next_level_data.has("desc"): prepared["desc"] = next_level_data["desc"]
			prepared["name"] = prepared["name"] + " Lv." + str(cur_lvl + 1)
		else:
			prepared["desc"] = "MAX LEVEL"
			prepared["name"] = prepared["name"] + " (MAX)"
	return prepared

# ... (Kalan standart fonksiyonlar aynen duruyor) ...
func can_unlock_mechanic(id: String) -> bool:
	if mechanic_levels.has(id): return true
	var rarity = _get_rarity_from_json(id)
	if rarity == "gold": return _get_active_mechanic_count("gold") < max_gold_slots
	if rarity == "prismatic": return _get_active_mechanic_count("prismatic") < max_prism_slots
	return true

func _get_rarity_from_json(target_id: String) -> String:
	for pool in [tier_1_pool, tier_2_pool, tier_3_pool]:
		if pool is Dictionary and pool.has("augments"):
			for item in pool["augments"]:
				if item.id == target_id: return item.get("rarity", "silver")
		elif pool is Array:
			for item in pool:
				if item.id == target_id: return item.get("rarity", "silver")
	return "silver"

func _get_active_mechanic_count(target_rarity: String) -> int:
	var count = 0
	for m_id in mechanic_levels.keys():
		if _get_rarity_from_json(m_id) == target_rarity: count += 1
	return count

func start_game_selection():
	# UI AÇILDI: Player'ı ve her şeyi dondur
	is_selection_active = true
	
	current_level = 1; current_xp = 0
	emit_signal("level_changed", current_level)
	var choices = generate_choices()
	emit_signal("show_augment_selection", choices)
	get_tree().paused = true

func add_xp(amount):
	current_xp += amount
	if current_xp >= max_xp: level_up()
	emit_signal("xp_changed", current_xp, max_xp)

func level_up():
	# UI ACILDI: Player'i ve her seyi dondur
	is_selection_active = true
	
	current_level += 1
	current_xp -= max_xp
	
	# --- AKILLI XP HESAPLAMA MEKANIZMASI ---
	# Temel mantik: max_xp = Taban_XP * (Katsayi ^ level) + (Ekstra_Ivme)
	
	if current_level < 10:
		# Ilk 10 seviye: Hizli baslangic, tatmin edici ilerleme
		max_xp = 100 + (current_level * 50)
	elif current_level < 25:
		# Orta safha: %15 lineer artis + %5 exponential artis
		max_xp = int(max_xp * 1.15) + (current_level * 20)
	elif current_level < 50:
		# Gec safha: Artik guclendin, her level icin ciddi efor lazim
		max_xp = int(max_xp * 1.25) + int(pow(current_level, 1.8))
	else:
		# Endgame (50+): Seviye atlamak artik bir basari
		max_xp = int(max_xp * 1.35) + int(pow(current_level, 2.2))
	
	# Sinirlayici: XP ihtiyacinin bellegi zorlayacak kadar sacma rakamlara cikmasini engelle (Opsiyonel)
	max_xp = clamp(max_xp, 100, 500000)
	
	print("[SYSTEM] Level Up! Yeni Level: %d, Gereken XP: %d" % [current_level, max_xp])
	
	emit_signal("level_changed", current_level)
	emit_signal("xp_changed", current_xp, max_xp)
	
	var choices = generate_choices()
	emit_signal("show_augment_selection", choices)
	get_tree().paused = true

func generate_choices():
	var final_choices = []
	if current_level == 1:
		var weapon_pool = tier_1_pool.filter(func(c): return c.get("type") == "weapon_unlock")
		weapon_pool.shuffle()
		for i in range(min(2, weapon_pool.size())): final_choices.append(_prepare_card(weapon_pool[i]))
		return final_choices
	elif current_level == 2:
		var weapon_card = tier_1_pool.filter(func(c): return c.id == active_weapon_id)
		if not weapon_card.is_empty(): final_choices.append(_prepare_card(weapon_card[0]))
		var stats = tier_1_pool.filter(func(c): return c.get("type") == "stat")
		stats.shuffle()
		for i in range(min(2, stats.size())): final_choices.append(_prepare_card(stats[i]))
		return final_choices

	var selected_ids = []
	for i in range(3):
		var card = _pick_weighted_card()
		var safe = 0
		while card and (card.id in selected_ids) and safe < 10: card = _pick_weighted_card(); safe += 1
		if card: final_choices.append(_prepare_card(card)); selected_ids.append(card.id)
	return final_choices

func _pick_weighted_card():
	var roll = randf()
	var target_pool = []
	if current_level >= 10 and roll <= 0.15:
		target_pool = tier_3_pool.filter(func(c): return (mechanic_levels.has(c.id) and mechanic_levels[c.id] < 4) or (not mechanic_levels.has(c.id) and active_prism_ids.size() < max_prism_slots))
	elif current_level >= 5 and roll <= 0.40:
		target_pool = tier_2_pool.filter(func(c): return (mechanic_levels.has(c.id) and mechanic_levels[c.id] < 4) or (not mechanic_levels.has(c.id) and active_gold_ids.size() < max_gold_slots))
	
	if target_pool.is_empty():
		target_pool = tier_1_pool.filter(func(c):
			if c.type == "stat": return true
			if c.id == active_weapon_id: return mechanic_levels.get(c.id, 0) < 4
			return false
		)
	
	var total_w = 0.0
	for c in target_pool: total_w += float(c.get("weight", 1.0))
	var r_weight = randf() * total_w; var current_w = 0.0
	for card in target_pool:
		current_w += float(card.get("weight", 1.0))
		if r_weight <= current_w: return card
	return target_pool.pick_random() if not target_pool.is_empty() else null
