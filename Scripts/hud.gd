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


# YENİ: Zamanlayıcı Label'ı (Senin eklediğin Label'ın adı buraya gelecek)
@onready var time_label = $TimerLabel 

var last_hp: float = 0.0
var game_time: float = 0.0 # Oyun süresini tutacak değişken
# Takip listesi: { "prism_4": slot_node }
var active_slots = {} 

# Takip edilecek aktif skillerin Player scriptindeki isimleri (Map)
var skill_map = {
	"gold_1": {"timer": "thunder_timer", "cd": "thunderlord_cooldown"},
	"prism_3": {"timer": "stomp_timer", "cd": "stomp_interval"},
	"prism_4": {"timer": "black_hole_timer", "cd": "black_hole_cooldown"},
	"prism_6": {"timer": "time_stop_timer", "cd": "time_stop_actual_cd"}, # Actual CD'yi bağladık
	"prism_7": {"timer": "dragon_timer", "cd": "dragon_cooldown"}
}

func _ready():
	# XP Sinyallerini bağlarken doğru fonksiyona yönlendirdik
	AugmentManager.xp_changed.connect(_update_xp_ui)
	AugmentManager.level_changed.connect(_update_level_info)
	
	# Manager'dan gelen popup sinyalini bağla
	AugmentManager.augment_selected.connect(_show_augment_popup)
	
	# Başlangıç değerlerini set et
	_update_xp_ui(AugmentManager.current_xp, AugmentManager.max_xp)
	_update_level_info(AugmentManager.current_level)
	
	# WeaponManager sinyal kontrolü
	if weapon_manager:
		if weapon_manager.has_signal("skill_fired"):
			weapon_manager.skill_fired.connect(_on_skill_fired)
		else:
			print("UYARI: WeaponManager üzerinde 'skill_fired' sinyali bulunamadı!")
	
	if info_panel:
		info_panel.modulate.a = 0
		info_panel.visible = false


func _process(delta):
	game_time += delta
	_update_timer_display()
	_update_ability_slots()
	_update_dash_visuals()
	_check_for_new_augments()
	
func _update_timer_display():
	if time_label:
		var minutes = int(game_time / 60)
		var seconds = int(game_time) % 60
		# %02d demek: Sayı tek haneli olsa bile başına 0 koy (Örn: 05:09)
		time_label.text = "%02d:%02d" % [minutes, seconds]

func _update_xp_ui(current: float, total: float):
	if xp_bar:
		xp_bar.max_value = total
		xp_bar.value = current
	
	if xp_text:
		xp_text.text = str(int(current)) + " / " + str(int(total))

func _show_augment_popup(aug_name: String, aug_description: String):
	if info_panel and info_label:
		info_label.text = "[ " + aug_name.to_upper() + " ]\n" + aug_description
		info_panel.visible = true
		
		var tween = create_tween()
		tween.tween_property(info_panel, "modulate:a", 1.0, 0.3)
		tween.tween_interval(3.0)
		tween.tween_property(info_panel, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): info_panel.visible = false)

func _on_skill_fired(skill_name: String, cooldown_time: float):
	var node_path = "Abilities/" + skill_name + "_Icon"
	var icon_node = get_node_or_null(node_path)
	
	if icon_node:
		animate_cooldown(icon_node, cooldown_time)

func _on_xp_changed(current, total):
	_update_xp_ui(current, total)

func _update_xp_bar(current, max_val):
	_update_xp_ui(current, max_val)

func _update_level_info(new_level):
	if level_label:
		level_label.text = "LEVEL: " + str(new_level)
	_update_xp_ui(0, AugmentManager.max_xp)

func _on_player_health_changed(current_hp, max_hp):
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	
	if health_label:
		health_label.text = str(int(current_hp)) + " / " + str(int(max_hp))
	
	if current_hp < last_hp:
		_shake_node(health_bar)
		if health_label: _shake_node(health_label)
	
	last_hp = current_hp 
	
	if current_hp < max_hp * 0.3:
		health_bar.modulate = Color.RED
	else:
		health_bar.modulate = Color.WHITE


func _shake_node(node: Control):
	var original_pos = node.position
	var tween = create_tween()
	for i in range(4):
		var rand_pos = original_pos + Vector2(randf_range(-5, 5), randf_range(-3, 3))
		tween.tween_property(node, "position", rand_pos, 0.04)
	tween.tween_property(node, "position", original_pos, 0.04)

func animate_cooldown(icon_node: TextureRect, time: float):
	icon_node.pivot_offset = icon_node.size / 2
	icon_node.modulate = Color(0.2, 0.2, 0.2, 1.0) 
	
	var tween = create_tween()
	tween.tween_property(icon_node, "modulate", Color(1, 1, 1, 1), time)
	tween.tween_callback(func(): 
		var flash = create_tween()
		flash.tween_property(icon_node, "scale", Vector2(1.2, 1.2), 0.1)
		flash.tween_property(icon_node, "scale", Vector2(1.0, 1.0), 0.1)
	)




# Yeni bir augment alınmış mı kontrol et ve slota ata
func _check_for_new_augments():
	var levels = AugmentManager.mechanic_levels
	for id in levels.keys():
		if not active_slots.has(id):
			_assign_slot_to_augment(id)

# Boş slot bul ve augmenti oraya yerleştir
func _assign_slot_to_augment(aug_id: String):
	if active_slots.has(aug_id): return 

	var slots = ability_container.get_children()
	
	for s in slots:
		if not s.has_meta("occupied"):
			s.set_meta("occupied", true)
			active_slots[aug_id] = s
			
			# İkon Atama
			var icon_node = s.get_node_or_null("Icon")
			if icon_node:
				var path = "res://Assets/Icons/" + aug_id + ".png"
				if FileAccess.file_exists(path):
					icon_node.texture = load(path)
				icon_node.visible = true
			
			# AD VE LEVEL ETİKETİ (İLK ATAMA)
			var name_label = s.get_node_or_null("NameLabel")
			if name_label:
				# ID'yi daha okunaklı yapalım: "prism_4" -> "BLACK HOLE"
				# Bunun için JSON'dan veri çekmek en iyisi ama şimdilik ID'yi temizleyelim
				var readable_name = aug_id.replace("prism_", "").replace("gold_", "").replace("_", " ").to_upper()
				var level = AugmentManager.mechanic_levels.get(aug_id, 1)
				name_label.text = readable_name + " LV." + str(level)
				name_label.visible = true
			
			return

# Cooldown Barını ve Yazısını Güncelle
func _update_ability_slots():
	var p = get_tree().get_first_node_in_group("player")
	if not p: return
	
	var levels = AugmentManager.mechanic_levels
	
	for id in active_slots.keys():
		var slot = active_slots[id]
		
		# 1. Level Bilgisini Güncelle (Her zaman çalışır)
		var name_label = slot.get_node_or_null("NameLabel")
		if name_label:
			var readable_name = id.replace("prism_", "").replace("gold_", "").replace("_", " ").to_upper()
			var current_lvl = levels.get(id, 1)
			name_label.text = readable_name + " LV." + str(current_lvl)

		# 2. Cooldown Kontrolü (Sadece Aktif Skiller İçin)
		if skill_map.has(id):
			var data = skill_map[id]
			var current_timer = p.get(data.timer)
			var max_cd = p.get(data.cd)
			
			var progress = slot.get_node("Progress")
			var time_text = slot.get_node("TimeLabel")
			
			if current_timer != null and current_timer > 0:
				progress.visible = true
				progress.value = (current_timer / max_cd) * 100
				time_text.text = "%.1f" % current_timer
				time_text.visible = true
			else:
				progress.visible = false
				time_text.visible = false

# Dash Yüklerini Güncelle (Hibrit)
func _update_dash_visuals():
	var p = get_tree().get_first_node_in_group("player")
	if not p: return
	
	var dashes = dash_container.get_children()
	var current_dash = p.current_dash_charges
	
	for i in range(dashes.size()):
		if i < current_dash:
			dashes[i].modulate = Color.WHITE # Dolu
		else:
			dashes[i].modulate = Color(0.2, 0.2, 0.2, 0.5) # Boş/Beklemede
