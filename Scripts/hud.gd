extends CanvasLayer
class_name hud

@onready var xp_bar = $XPBar
@onready var health_bar = $HealthBar
@onready var health_label = $HealthBar/HealthLabel 
@onready var level_label = $LevelLabel
@onready var weapon_manager = $"../WeaponManager"
@onready var info_panel = $InfoPanel
@onready var info_label = $InfoPanel/InfoLabel
@onready var xp_text = $XPBar/XPLabel
@onready var ability_container = $Abilities
@onready var dash_container = $DashContainer
@onready var time_label = $TimerLabel 

# --- AYARLAR ---
var last_hp: float = 0.0
var game_time: float = 0.0
var active_slots = {} # { "aug_id": slot_node }

# Kara Liste: Bu ID'ler asla yetenek slotlarına girmeyecek
const STARTER_IDS = [
	"ice_shard", "snowball", 
	"ice_shard_lvl1", "snowball_lvl1", 
	"starter_weapon", "base_attack",
	"Ice Shard", "Snowball" # Bazı yerlerde büyük harf kullanmış olabilirsin, önlem olsun.
]

# Yetenek-Cooldown Eşleştirmesi
var skill_map = {
	"gold_1": {"timer": "thunder_timer", "cd": "thunderlord_cooldown"},
	"prism_3": {"timer": "stomp_timer", "cd": "stomp_interval"},
	"prism_4": {"timer": "black_hole_timer", "cd": "black_hole_cooldown"},
	"prism_6": {"timer": "time_stop_timer", "cd": "time_stop_actual_cd"},
	"prism_7": {"timer": "dragon_timer", "cd": "dragon_cooldown"}
}

# UI Kısaltmaları
var name_shortcuts = {
	"prism_1": "LASER", "prism_2": "WEAVER", "prism_3": "TITAN", 
	"prism_4": "B.HOLE", "prism_5": "WINTER", "prism_6": "TIME", 
	"prism_7": "DRAGON", "prism_8": "MIRROR", "prism_9": "SPEED",
	"gold_1": "THUNDER", "gold_2": "FROST", "gold_3": "EXEC", 
	"gold_4": "CHAIN", "gold_5": "GIANT", "gold_6": "ECHO", 
	"gold_7": "LIFEST", "gold_8": "WIND", "gold_9": "STATIC", "gold_10": "ALCH"
}

func _ready():
	AugmentManager.xp_changed.connect(_update_xp_ui)
	AugmentManager.level_changed.connect(_update_level_info)
	AugmentManager.augment_selected.connect(_show_augment_popup)
	
	_update_xp_ui(AugmentManager.current_xp, AugmentManager.max_xp)
	_update_level_info(AugmentManager.current_level)
	
	if weapon_manager and weapon_manager.has_signal("skill_fired"):
		weapon_manager.skill_fired.connect(_on_skill_fired)

	if info_panel:
		info_panel.modulate.a = 0
		info_panel.visible = false

func _process(delta):
	# Gerçek Pause kontrolü: Oyun durmuşsa VE Time Stop aktif değilse işlem yapma.
	var p = get_tree().get_first_node_in_group("player")
	var is_in_time_stop = p.is_time_stopped if p else false
	
	if get_tree().paused and not is_in_time_stop: 
		return # Timer ve HUD güncellemeleri burada tamamen donar.
	
	game_time += delta
	_update_timer_display()
	_check_for_new_augments()
	_update_ability_slots()
	_update_dash_visuals()

func _update_timer_display():
	if time_label:
		var minutes = int(game_time / 60)
		var seconds = int(game_time) % 60
		time_label.text = "%02d:%02d" % [minutes, seconds]

func _update_xp_ui(current: float, total: float):
	if xp_bar:
		xp_bar.max_value = total
		xp_bar.value = current
	if xp_text:
		xp_text.text = str(int(current)) + " / " + str(int(total))

func _update_level_info(new_level):
	if level_label:
		level_label.text = "LEVEL: " + str(new_level)
	_update_xp_ui(0, AugmentManager.max_xp)

func _show_augment_popup(aug_name: String, aug_description: String):
	if info_panel and info_label:
		info_label.text = "[ " + aug_name.to_upper() + " ]\n" + aug_description
		info_panel.visible = true
		var tween = create_tween()
		tween.tween_property(info_panel, "modulate:a", 1.0, 0.3)
		tween.tween_interval(3.0)
		tween.tween_property(info_panel, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): info_panel.visible = false)

# --- AUGMENT SLOT MANTIĞI ---

func _check_for_new_augments():
	var levels = AugmentManager.mechanic_levels
	for id in levels.keys():
		# 1. KRİTİK KONTROL: Eğer ID starter listesindeyse direkt diğerine geç (atla)
		var is_starter = false
		for s_id in STARTER_IDS:
			if id.to_lower() == s_id.to_lower(): # Büyük/küçük harf toleransı
				is_starter = true
				break
		
		if is_starter: continue # Starter ise slot ayırma işlemini tamamen atla

		# 2. Eğer zaten slottaysa veya starter değilse devam et
		if not active_slots.has(id):
			_assign_slot_to_augment(id)

func _assign_slot_to_augment(aug_id: String):
	# Burada da bir kez daha kontrol edelim, işimizi sağlama alalım
	if active_slots.has(aug_id): return 

	var slots = ability_container.get_children()
	for s in slots:
		if not s.has_meta("occupied"):
			s.set_meta("occupied", true)
			active_slots[aug_id] = s
			
			# İkon yükleme mantığı aynı kalabilir
			_update_slot_visuals(s, aug_id)
			return

func _update_slot_visuals(slot_node, aug_id):
	# 1. İKONU YÜKLE
	var icon_rect = slot_node.get_node_or_null("Icon") # TextureRect node'unun adı
	if icon_rect:
		var path = "res://Assets/Icons/" + aug_id + ".png"
		if FileAccess.file_exists(path):
			icon_rect.texture = load(path)
			icon_rect.visible = true
		else:
			print("UYARI: İkon bulunamadı -> ", path)

	# 2. ETİKETİ GÜNCELLE (Mevcut kodun)
	var name_label = slot_node.get_node_or_null("NameLabel")
	var level = AugmentManager.mechanic_levels.get(aug_id, 1)
	if name_label:
		var short_name = name_shortcuts.get(aug_id, aug_id.split("_")[-1].to_upper())
		name_label.text = short_name + " L" + str(level)
		name_label.visible = true

func _update_ability_slots():
	var p = get_tree().get_first_node_in_group("player")
	if not p: return
	
	for id in active_slots.keys():
		var slot = active_slots[id]
		_update_slot_visuals(slot, id)

		if skill_map.has(id):
			var data = skill_map[id]
			var current_timer = p.get(data.timer)
			var max_cd = p.get(data.cd)
			
			var progress = slot.get_node_or_null("Progress")
			var time_text = slot.get_node_or_null("TimeLabel")
			
			if current_timer != null and current_timer > 0:
				if progress and max_cd:
					progress.visible = true
					progress.value = (current_timer / max_cd) * 100
				if time_text:
					time_text.text = "%.1f" % current_timer
					time_text.visible = true
			else:
				if progress: progress.visible = false
				if time_text: time_text.visible = false

# --- DASH HUD MANTIĞI ---

func _update_dash_visuals():
	var p = get_tree().get_first_node_in_group("player")
	if not p: return
	
	# 1. Şarj Simgeleri (HBoxContainer/Charges altındaki TextureRect'ler)
	var charges_node = dash_container.get_node_or_null("Charges")
	if charges_node:
		var charge_list = charges_node.get_children()
		for i in range(charge_list.size()):
			# Oyuncunun max dash sayısı kadar slotu göster (opsiyonel)
			var max_d = p.get("max_dash_charges") if p.get("max_dash_charges") != null else 1
			charge_list[i].visible = (i < max_d)
			
			if i < p.current_dash_charges:
				charge_list[i].modulate = Color.WHITE
			else:
				charge_list[i].modulate = Color(0.2, 0.2, 0.2, 0.7)

	# 2. Cooldown Barı (DashContainer/Progress)
	var dash_bar = dash_container.get_node_or_null("Progress")
	if dash_bar:
		var d_timer = p.get("dash_timer")
		var f_cd = p.get("final_cd")
		
		if d_timer != null and d_timer > 0:
			dash_bar.visible = true
			var base_cd_val = f_cd if f_cd != null else 3.0
			var ratio = d_timer / base_cd_val
			dash_bar.value = (1.0 - ratio) * 100
		else:
			dash_bar.value = 100
			dash_bar.visible = false

# --- DİĞER UI FONKSİYONLARI ---

func _on_skill_fired(skill_name: String, cooldown_time: float):
	var icon_node = get_node_or_null("Abilities/" + skill_name + "_Icon")
	if icon_node: animate_cooldown(icon_node, cooldown_time)

func animate_cooldown(icon_node: TextureRect, time: float):
	icon_node.pivot_offset = icon_node.size / 2
	icon_node.modulate = Color(0.2, 0.2, 0.2, 1.0) 
	var tween = create_tween()
	tween.tween_property(icon_node, "modulate", Color(1, 1, 1, 1), time)

func _on_player_health_changed(current_hp, max_hp):
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	if health_label: health_label.text = str(int(current_hp)) + " / " + str(int(max_hp))
	if current_hp < last_hp: _shake_node(health_bar)
	last_hp = current_hp 
	health_bar.modulate = Color.RED if current_hp < max_hp * 0.3 else Color.WHITE

func _shake_node(node: Control):
	var original_pos = node.position
	var tween = create_tween()
	for i in range(4):
		var rand_pos = original_pos + Vector2(randf_range(-5, 5), randf_range(-3, 3))
		tween.tween_property(node, "position", rand_pos, 0.04)
	tween.tween_property(node, "position", original_pos, 0.04)
