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
	"execution_threshold": 0.0 
}

var active_gold_ids = []  
var active_prism_ids = [] 
var mechanic_levels = {}   

var tier_1_pool = []
var tier_2_pool = []
var tier_3_pool = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 1. Önce veriyi yükle
	load_augment_data()
	# 2. Veri yüklendikten sonra başlangıç yeteneğini kur
	_setup_initial_mechanics()
	emit_signal("level_changed", current_level)

func load_augment_data():
	var file_path = "res://data/augments.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data:
			tier_1_pool = data.get("tier_1_pool", [])
			tier_2_pool = data.get("tier_2_pool", [])
			tier_3_pool = data.get("tier_3_pool", [])

func _setup_initial_mechanics():
	mechanic_levels["gold_9"] = 4
	if not "gold_9" in active_gold_ids:
		active_gold_ids.append("gold_9")
	
	# Havuzdan gold_3 verisini bul ve JSON'daki 'threshold' değerini çek
	var found = false
	for card in tier_2_pool:
		if card.id == "gold_3":
			# FIX: JSON'daki anahtar ismin "threshold" olduğu için onu çekiyoruz
			player_stats["execution_threshold"] = card["levels"][0].get("threshold", 0.1)
			found = true
			break
	
	if not found:
		player_stats["execution_threshold"] = 0.1
	
	emit_signal("mechanic_unlocked", "gold_3")
	print("\n=== DEBUG: JSON'DAN ÇEKİLEN THRESHOLD: ", player_stats["execution_threshold"], " ===")

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
	
	# YENİ PACE FORMÜLÜ:
	# İlk 5 level çok hızlı geçsin (80 + 40*level)
	# Sonrasında kavisli artsın ama duvara toslamasın
	if current_level < 5:
		max_xp = 80 + (current_level * 40) 
	else:
		# Level 5'ten sonra biraz daha zorlaşsın
		max_xp = 250 + ((current_level - 5) * 80)
	
	emit_signal("level_changed", current_level)
	# Dinamik karesel artış
	max_xp = 100 + (current_level * current_level * 15) + (current_level * 50)
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
		if card and not card.id in selected_ids:
			final_choices.append(_prepare_card(card))
			selected_ids.append(card.id)
		else:
			var fallback = _pick_weighted_card()
			if fallback: final_choices.append(_prepare_card(fallback))
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
			if c.id == active_weapon_id: return mechanic_levels.get(c.id, 0) < 4
			return false
		)

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
	return target_pool[0] if not target_pool.is_empty() else null

func _prepare_card(card):
	var prepared = card.duplicate()
	if prepared.has("levels"):
		var cur_lvl = mechanic_levels.get(prepared.id, 0)
		prepared["desc"] = prepared["levels"][cur_lvl]["desc"]
		prepared["name"] = prepared["name"] + " Lv." + str(cur_lvl + 1)
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
			mechanic_levels[a_id] += 1
		emit_signal("mechanic_unlocked", a_id)

	elif type == "mechanic":
		if not mechanic_levels.has(a_id):
			mechanic_levels[a_id] = 1
			if card_data.get("rarity") == "gold": active_gold_ids.append(a_id)
			elif card_data.get("rarity") == "prismatic": active_prism_ids.append(a_id)
		else:
			mechanic_levels[a_id] += 1
		
		# Seviye atladığında JSON'daki 'threshold' değerini güncelle
		if a_id == "gold_3":
			var cur_lvl = mechanic_levels[a_id]
			player_stats["execution_threshold"] = card_data["levels"][cur_lvl-1].get("threshold", 0.1)
			
		emit_signal("mechanic_unlocked", a_id)

	elif type == "stat":
		var s_name = card_data.get("stat", "")
		if player_stats.has(s_name):
			player_stats[s_name] += card_data["val"]
			
	get_tree().paused = false

func _remove_from_pools(id):
	var filter_func = func(c): return c.id != id
	tier_1_pool = tier_1_pool.filter(filter_func)
	tier_2_pool = tier_2_pool.filter(filter_func)
	tier_3_pool = tier_3_pool.filter(filter_func)
