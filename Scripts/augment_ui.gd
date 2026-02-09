extends CanvasLayer

@onready var card_buttons = [$Control/Container/Card1, $Control/Container/Card2, $Control/Container/Card3]
@onready var container = $Control/Container

const RARITY_GRADIENTS = {
	"silver": {"top": Color(0.25, 0.28, 0.35, 0.9), "bottom": Color(0.12, 0.13, 0.18, 0.95)},
	"gold": {"top": Color(0.8, 0.55, 0.1, 0.9), "bottom": Color(0.4, 0.25, 0.05, 0.95)},
	"prismatic": {"top": Color(0.5, 0.15, 0.8, 0.9), "bottom": Color(0.2, 0.05, 0.4, 0.95)}
}

var current_cards = []
var card_tweens = {}
var current_selection : int = 0
var prism_tweens = {} 
var original_card_y : float = 0.0

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS 
	AugmentManager.show_augment_selection.connect(_on_show_selection)
	for i in range(card_buttons.size()):
		var btn = card_buttons[i]
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.pressed.connect(_on_card_selected.bind(i))
		btn.focus_mode = Control.FOCUS_NONE
		_prepare_labels(btn)

func _input(event):
	if not visible or current_cards.is_empty(): return
	var handled = false
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_update_selection((current_selection - 1 + current_cards.size()) % current_cards.size()); handled = true
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_update_selection((current_selection + 1) % current_cards.size()); handled = true
	elif event.is_action_pressed("ui_accept"): 
		_on_card_selected(current_selection); handled = true
	if handled: get_viewport().set_input_as_handled()

func _on_show_selection(choices):
	current_cards = choices
	
	# 1. EFEKTLERİ ÖLDÜR
	for t in prism_tweens.values():
		if t is Array: 
			for sub_t in t: sub_t.kill()
		elif t: t.kill()
	prism_tweens.clear()
	
	# --- SEPARATION AYARI (25 Piksel) ---
	# Container'ın kartlar arasına nefes aldırması için
	if container is BoxContainer:
		container.add_theme_constant_override("separation", 25)
	
	# 2. TEMİZLİK VE RESET
	container.modulate.a = 0
	for i in range(card_buttons.size()):
		var btn = card_buttons[i]
		btn.modulate = Color.WHITE 
		btn.scale = Vector2.ONE
		
		# Kesin çözüm: Override'ları nesne aramadan direkt siliyoruz
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_stylebox_override("pressed")
			
		if i < choices.size():
			btn.visible = true
			_setup_card_visuals(btn, choices[i])
		else:
			btn.visible = false

	visible = true
	get_tree().paused = true
	
	await get_tree().process_frame
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	
	if card_buttons.size() > 0:
		original_card_y = card_buttons[0].position.y
	
	_update_selection(0)
	
	var entry_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entry_tw.tween_property(container, "modulate:a", 1.0, 0.3)

func _setup_card_visuals(btn: Button, card_data):
	var rarity = card_data.get("rarity", "silver")
	var colors = RARITY_GRADIENTS.get(rarity, RARITY_GRADIENTS["silver"])
	
	# FIX: Her seferinde NEW StyleBox (Daha zarif gradient)
	var style = StyleBoxFlat.new()
	style.set_border_width_all(2) 
	style.set_corner_radius_all(15)
	style.bg_color = colors.bottom
	style.border_color = colors.top
	style.border_width_top = 180 
	style.border_blend = true
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 18
	
	btn.add_theme_stylebox_override("normal", style)
	btn.pivot_offset = btn.size / 2.0
	btn.get_node("VBoxContainer/Title").text = card_data.get("name", "---").to_upper()
	btn.get_node("VBoxContainer/Description").text = card_data.get("desc", "---")
	
	if rarity == "gold": _apply_gold_shimmer(btn, style)
	elif rarity == "prismatic": _apply_prism_legendary_fx(btn, style)

func _apply_gold_shimmer(btn, style):
	var tw = create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(style, "border_color", Color(1.0, 0.9, 0.5), 0.8)
	tw.tween_property(style, "border_color", Color(0.6, 0.4, 0.1), 0.8)
	prism_tweens[btn.get_instance_id()] = tw

func _apply_prism_legendary_fx(btn, style):
	var t1 = create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var colors = [Color(1,0.4,0.4), Color(0.4,1,0.4), Color(0.4,0.4,1), Color(0.8,0.4,0.8)]
	for c in colors: t1.tween_property(style, "border_color", c, 0.8).set_trans(Tween.TRANS_SINE)
	
	var t2 = create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t2.tween_property(btn, "modulate", Color(1.2, 1.2, 1.35), 1.0).set_trans(Tween.TRANS_SINE)
	t2.tween_property(btn, "modulate", Color.WHITE, 1.5).set_trans(Tween.TRANS_SINE)
	prism_tweens[btn.get_instance_id()] = [t1, t2]

func _update_selection(index: int):
	current_selection = index
	for i in range(current_cards.size()): _animate_card_focus(card_buttons[i], i == current_selection)

func _animate_card_focus(btn: Button, is_focused: bool):
	if card_tweens.has(btn): card_tweens[btn].kill()
	var tw = create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	card_tweens[btn] = tw
	if is_focused:
		tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(btn, "position:y", original_card_y - 30.0, 0.2)
		tw.tween_property(btn, "modulate", Color(1.1, 1.1, 1.2), 0.2)
	else:
		tw.tween_property(btn, "scale", Vector2.ONE, 0.2)
		tw.tween_property(btn, "position:y", original_card_y, 0.2)
		tw.tween_property(btn, "modulate", Color.WHITE, 0.2)

func _on_card_selected(index):
	# Seçilen kart patlasın, diğer tüm prism efektlerini ÖLDÜR
	for t in prism_tweens.values():
		if t is Array: 
			for sub_t in t: sub_t.kill()
		elif t: t.kill()
	prism_tweens.clear()

	var btn = card_buttons[index]
	var sel_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	sel_tw.tween_property(btn, "modulate", Color(8, 8, 8, 0), 0.4).set_trans(Tween.TRANS_EXPO)
	sel_tw.tween_property(btn, "scale", Vector2(1.6, 1.6), 0.4)
	sel_tw.finished.connect(func():
		AugmentManager.apply_augment(current_cards[index])
		visible = false
	)

func _prepare_labels(btn):
	var title = btn.get_node("VBoxContainer/Title")
	var desc = btn.get_node("VBoxContainer/Description")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _on_mouse_hover(index: int):
	if current_selection != index: _update_selection(index)
