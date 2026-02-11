extends CanvasLayer

const SETTINGS_SCENE = preload("res://levels/settings_menu.tscn")
const BORDER_COLOR = Color("4fe3ff")
const BG_COLOR = Color("0a1a2f")

@onready var resume_btn = $MarginContainer/MenuButtons/ResumeButton
@onready var settings_btn = $MarginContainer/MenuButtons/SettingsButton
@onready var main_menu_btn = $MarginContainer/MenuButtons/MainMenuButton
@onready var menu_container = $MarginContainer/MenuButtons

@onready var confirm_panel = $ConfirmPanel
# PanelBG bir 'Panel' node'u olmalı!
@onready var panel_bg = $ConfirmPanel/PanelBG 
@onready var yes_button = $ConfirmPanel/VBoxContainer/HBoxContainer/YesButton
@onready var no_button = $ConfirmPanel/VBoxContainer/HBoxContainer/NoButton

func _ready():
	self.visible = false
	confirm_panel.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# TASARIMLARI UYGULA
	_setup_modern_style(panel_bg)
	
	var all_btns = [resume_btn, settings_btn, main_menu_btn, yes_button, no_button]
	
	for btn in all_btns:
		_setup_modern_style(btn)
		
		if btn == yes_button:
			if not btn.pressed.is_connected(_on_confirm_yes_pressed):
				btn.pressed.connect(_on_confirm_yes_pressed)
		elif btn == no_button:
			if not btn.pressed.is_connected(_on_confirm_no_pressed):
				btn.pressed.connect(_on_confirm_no_pressed)
		else:
			# Ana menü butonları için basma sinyali
			if not btn.pressed.is_connected(_on_btn_pressed):
				btn.pressed.connect(_on_btn_pressed.bind(btn))
		
		btn.mouse_entered.connect(_on_btn_hover.bind(btn))
		btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
		
		btn.pivot_offset = btn.size / 2

# --- ESC KONTROLÜ ---
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func _toggle_pause():
	var new_state = !get_tree().paused
	get_tree().paused = new_state
	self.visible = new_state
	confirm_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if new_state:
		_on_settings_closed()

func _on_btn_pressed(btn: Button):
	if btn == resume_btn:
		_toggle_pause()
	elif btn == settings_btn:
		_all_buttons_exit()
		var inst = SETTINGS_SCENE.instantiate()
		add_child(inst)
		inst.closed.connect(_on_settings_closed)
	elif btn == main_menu_btn:
		_all_buttons_exit()
		await get_tree().create_timer(0.4).timeout
		confirm_panel.visible = true
		_pop_up_anim(panel_bg)

func _on_confirm_yes_pressed():
	get_tree().paused = false
	SaveSystem.save_game()
	get_tree().change_scene_to_file("res://levels/main_menu.tscn")

func _on_confirm_no_pressed():
	confirm_panel.visible = false
	_on_settings_closed()

# --- TASARIM VE ANİMASYON ---
func _setup_modern_style(obj: Control):
	var style = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.bg_color.a = 0.92
	style.border_width_left = 6
	style.border_width_bottom = 6
	style.border_color = BORDER_COLOR
	style.border_blend = true
	style.corner_radius_bottom_right = 20
	style.shadow_size = 15
	style.shadow_color = Color(0, 0, 0, 0.5)
	
	# Butonlar için yazı boşluğu (Taşmayı önler)
	style.content_margin_left = 25
	style.content_margin_right = 25
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	if obj is Button:
		obj.add_theme_stylebox_override("normal", style)
		obj.add_theme_stylebox_override("hover", style)
		obj.add_theme_stylebox_override("pressed", style)
		obj.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	elif obj is Panel:
		obj.add_theme_stylebox_override("panel", style)

func _pop_up_anim(node):
	node.pivot_offset = node.size / 2
	node.scale = Vector2.ZERO
	var tw = create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _all_buttons_exit():
	var btns = menu_container.get_children()
	for i in range(btns.size()):
		var tw = create_tween().set_parallel(true)
		tw.tween_property(btns[i], "position:x", -1500, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(i * 0.05)
		tw.tween_property(btns[i], "modulate:a", 0.0, 0.3).set_delay(i * 0.05)

func _on_settings_closed():
	var btns = menu_container.get_children()
	for i in range(btns.size()):
		var b = btns[i]
		b.visible = true
		b.modulate.a = 0
		var tw = create_tween().set_parallel(true)
		tw.tween_property(b, "position:x", 0, 0.5).from(1200).set_delay(i * 0.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(i * 0.1)

func _on_btn_hover(btn):
	# Butonun pivotunu her ihtimale karşı hover anında tekrar check edelim (Dinamik boyutlar için)
	btn.pivot_offset = btn.size / 2
	var tw = create_tween().set_parallel(true)
	tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK)
	tw.tween_property(btn, "modulate", Color(1.3, 1.3, 1.8), 0.2) # Buz parlaması ekledim

func _on_btn_unhover(btn):
	var tw = create_tween().set_parallel(true)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
	tw.tween_property(btn, "modulate", Color.WHITE, 0.2)
