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

# TÜM EKSİK STATLAR DAHİL EDİLMİŞ HALİ
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
	"lifesteal_flat": 0,       # Silver 5: Vampirism
	"execution_threshold": 0.0, # Gold 3: Executioner
	"luck": 0.0,               # Gold 10: Alchemist
	"gold_bonus": 0.0,         # Gold 10: Alchemist
	"armor": 0.0,              # Titan Form (Prism)
	"multishot_chance": 0.0,   # Silver 11: Triple Shot
	"waves": 1,                # Gold 6: Echoing Screams
	"dash_charges": 1,         # Gold 8: Wind Walker
	"thorns": 0.0              # Silver 9 & Gold 2
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
	print("🎮 AugmentManager: Oyun başlatılıyor, mekanikler kuruluyor...")
	_setup_initial_mechanics()
	emit_signal("level_changed", current_level)

func _setup_initial_mechanics():
	current_level = 1
	current_xp = 0
	active_gold_ids = []
	active_prism_ids = []
	mechanic_levels = {}
	
	# Statları varsayılana döndür
	player_stats = {
		"max_hp": 100.0, "speed": 12.5, "damage_mult": 1.0, "attack_speed": 1.0,
		"cooldown_reduction": 0.0, "pickup_range": 20.0, "freeze_duration": 4.0,
		"attack_range": 0.20, "dash_cooldown": 3.0, "lifesteal_flat": 0,
		"execution_threshold": 0.0, "luck": 0.0, "gold_bonus": 0.0, "armor": 0.0,
		"multishot_chance": 0.0, "waves": 1, "dash_charges": 1, "thorns": 0.0
	}
	
	emit_signal("mechanic_unlocked", "init")

func load_augment_data():
	var file_path = "res://Data/augments.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var text = file.get_as_text()
		var data = JSON.parse_string(text)
		if data:
			tier_1_pool = data.get("tier_1_pool", [])
			tier_2_pool = data.get("tier_2_pool", [])
			tier_3_pool = data.get("tier_3_pool", [])
		else:
			push_error("AugmentManager: JSON parse hatası!")
	else:
		push_error("AugmentManager: augments.json bulunamadı!")

func _force_unlock_augment(aug_id: String, level: int = 1):
	mechanic_levels[aug_id] = level
	
	if aug_id.begins_with("gold"):
		if not aug_id in active_gold_ids: active_gold_ids.append(aug_id)
	elif aug_id.begins_with("prism"):
		if not aug_id in active_prism_ids: active_prism_ids.append(aug_id)

	var found_card = null
	for pool in [tier_1_pool, tier_2_pool, tier_3_pool]:
		for card in pool:
			if card.id == aug_id:
				found_card = card
				break
		if found_card: break

	if found_card:
		apply_augment_stats_only(found_card, level)
		emit_signal.call_deferred("mechanic_unlocked", aug_id)
		print("🚀 Force Unlock: ", aug_id, " Lv.", level)

func apply_augment_stats_only(card_data, level):
	if card_data.get("id") == "gold_3":
		player_stats["execution_threshold"] = card_data["levels"][level-1].get("threshold", 0.1)

func start_game_selection():
	current_level = 1
	current_xp = 0
	emit_signal("level_changed", current_level)
	var choices = generate_choices()
	emit_signal("show_augment_selection", choices)
	get_tree().paused = true

func add_xp(amount):
	current_xp += amount
	if current_xp >= max_xp:
		level_up()
	emit_signal("xp_changed", current_xp, max_xp)

func level_up():
	current_level += 1
	current_xp -= max_xp
	
	if current_level < 5:
		max_xp = 80 + (current_level * 40)
	elif current_level < 20:
		max_xp = 300 + ((current_level - 5) * 100)
	else:
		max_xp = 1800 + ((current_level - 20) * 250) + int(pow(current_level - 20, 1.5) * 10)

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
		for i in range(min(2, weapon_pool.size())):
			final_choices.append(_prepare_card(weapon_pool[i]))
		return final_choices
	
	elif current_level == 2:
		var weapon_card = tier_1_pool.filter(func(c): return c.id == active_weapon_id)
		if not weapon_card.is_empty():
			final_choices.append(_prepare_card(weapon_card[0]))
		var stats = tier_1_pool.filter(func(c): return c.get("type") == "stat")
		stats.shuffle()
		for i in range(min(2, stats.size())):
			final_choices.append(_prepare_card(stats[i]))
		return final_choices

	var selected_ids = []
	for i in range(3):
		var card = _pick_weighted_card()
		var safe_guard = 0
		while card and (card.id in selected_ids) and safe_guard < 10:
			card = _pick_weighted_card()
			safe_guard += 1
			
		if card:
			final_choices.append(_prepare_card(card))
			selected_ids.append(card.id)
			
	return final_choices

func _pick_weighted_card():
	var roll = randf()
	var target_pool = []
	
	if current_level >= 10 and roll <= 0.10:
		target_pool = tier_3_pool.filter(func(c): 
			return (mechanic_levels.has(c.id) and mechanic_levels[c.id] < 4) or (not mechanic_levels.has(c.id) and active_prism_ids.size() < 3)
		)
	elif current_level >= 5 and roll <= 0.35:
		target_pool = tier_2_pool.filter(func(c):
			return (mechanic_levels.has(c.id) and mechanic_levels[c.id] < 4) or (not mechanic_levels.has(c.id) and active_gold_ids.size() < 4)
		)
	
	if target_pool.is_empty():
		target_pool = tier_1_pool.filter(func(c):
			if c.type == "stat": return true
			if c.id == active_weapon_id or c.id == "start_snowball" or c.id == "start_iceshard": 
				return mechanic_levels.get(c.id, 0) < 4 and mechanic_levels.get(c.id, 0) > 0
			return false
		)
		if target_pool.is_empty():
			target_pool = tier_1_pool.filter(func(c): return c.type == "stat")

	var total_weight = 0
	var pool_with_weights = []
	for card in target_pool:
		var weight = 10 
		var cur_lvl = mechanic_levels.get(card.id, 0)
		if cur_lvl > 0:
			match cur_lvl:
				1: weight = 6 
				2: weight = 2 
				3: weight = 1 
		total_weight += weight
		pool_with_weights.append({"card": card, "cumulative_weight": total_weight})

	var random_weight = randi() % total_weight if total_weight > 0 else 0
	for item in pool_with_weights:
		if random_weight < item.cumulative_weight:
			return item.card
	return target_pool.pick_random() if not target_pool.is_empty() else null

func _prepare_card(card):
	var prepared = card.duplicate(true)
	if prepared.has("levels"):
		var cur_lvl = mechanic_levels.get(prepared.id, 0)
		if cur_lvl < prepared["levels"].size():
			prepared["desc"] = prepared["levels"][cur_lvl]["desc"]
			prepared["name"] = prepared["name"] + " Lv." + str(cur_lvl + 1)
		else:
			prepared["desc"] = "MAX LEVEL"
			prepared["name"] = prepared["name"] + " (MAX)"
	return prepared

func apply_augment(card_data):
	var a_id = card_data.get("id", "")
	var a_name = card_data.get("name", "Geliştirme")
	var a_desc = card_data.get("desc", "")
	var type = card_data.get("type", "stat")
	
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
		
		if card_data.get("rarity") == "gold" and not a_id in active_gold_ids: 
			active_gold_ids.append(a_id)
		elif card_data.get("rarity") == "prismatic" and not a_id in active_prism_ids: 
			active_prism_ids.append(a_id)
		
		if a_id == "gold_3" and card_data.has("levels"):
			player_stats["execution_threshold"] = card_data["levels"][new_lvl-1].get("threshold", 0.1)
			
		emit_signal("mechanic_unlocked", a_id)

	elif type == "stat":
		var s_name = card_data.get("stat", "")
		if player_stats.has(s_name):
			# Triple Shot Şans Fix (%10 -> 0.1)
			var val = card_data["val"]
			if s_name == "multishot_chance" and val > 1.0: val = val / 100.0
			
			player_stats[s_name] += val
			
			if s_name == "max_hp":
				var player = get_tree().get_first_node_in_group("player")
				if player and player.has_method("heal"):
					player.heal(card_data["val"])
			
	get_tree().paused = false
