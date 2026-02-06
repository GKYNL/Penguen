extends CanvasLayer
class_name hud

@onready var xp_bar = $XPBar
@onready var health_bar = $HealthBar
@onready var health_label = $HealthBar/HealthLabel 
@onready var mana_bar = $ManaBar
@onready var mana_label = $ManaBar/ManaLabel      
@onready var level_label = $LevelLabel
@onready var weapon_manager = $"../WeaponManager"
@onready var info_panel = $InfoPanel
@onready var info_label = $InfoPanel/InfoLabel
@onready var xp_text = $XPBar/XPLabel

var last_hp: float = 0.0

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

# ASIL FIX BURASI: Yazıyı ve barı aynı anda güncelleyen ana fonksiyon
func _update_xp_ui(current: float, total: float):
	if xp_bar:
		xp_bar.max_value = total
		xp_bar.value = current
	
	if xp_text:
		# "125 / 450" formatında yazdırır
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

# Sinyallerin kafası karışmasın diye bu iki fonksiyonu ana fonksiyona bağladım
func _on_xp_changed(current, total):
	_update_xp_ui(current, total)

func _update_xp_bar(current, max_val):
	_update_xp_ui(current, max_val)

func _update_level_info(new_level):
	if level_label:
		level_label.text = "LEVEL: " + str(new_level)
	# Level atlayınca barı ve metni sıfırla (Yeni max_xp ile)
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

func update_mana(current, max_m):
	if mana_bar:
		mana_bar.max_value = max_m
		mana_bar.value = current
	if mana_label:
		mana_label.text = str(int(current)) + " / " + str(int(max_m))

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
