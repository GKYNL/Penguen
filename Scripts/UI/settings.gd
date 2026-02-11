extends Control

signal closed

const SAVE_PATH = "user://settings.cfg"
const BORDER_COLOR = Color("4fe3ff")
const BG_COLOR = Color("0a1a2f")

@onready var music_slider = $SettingsPanel/MarginContainer/VBoxContainer/ScrollContainer/OptionsList/MusicRow/MusicSlider
@onready var sfx_slider = $SettingsPanel/MarginContainer/VBoxContainer/ScrollContainer/OptionsList/SFXRow/SFXSlider
@onready var res_option = $SettingsPanel/MarginContainer/VBoxContainer/ScrollContainer/OptionsList/ResolutionRow/ResOption
@onready var fullscreen_check = $SettingsPanel/MarginContainer/VBoxContainer/ScrollContainer/OptionsList/FullscreenRow/FullscreenCheck
@onready var back_button = $SettingsPanel/MarginContainer/VBoxContainer/BackButton
@onready var title_label = $SettingsPanel/MarginContainer/VBoxContainer/SettingsTitle

var config = ConfigFile.new()

func _ready():
	await get_tree().process_frame
	_apply_aaa_design() # TASARIM GERİ GELDİ
	_load_settings_from_file()
	_connect_logic()
	_play_entrance_animation()

func _apply_aaa_design():
	# ANA PANEL STİLİ
	var style = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.bg_color.a = 0.95
	style.border_width_left = 8
	style.border_width_bottom = 8
	style.border_color = BORDER_COLOR
	style.border_blend = true 
	style.corner_radius_bottom_right = 30
	style.shadow_size = 25
	style.shadow_color = Color(0, 0, 0, 0.8)
	style.content_margin_left = 30
	style.content_margin_top = 15
	style.content_margin_bottom = 15

	# Başlık Stili (Butondan Farklılaştırdık)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.1)
	title_style.border_width_left = 4
	title_style.border_width_bottom = 4
	title_style.border_color = BORDER_COLOR
	title_style.border_blend = true
	title_style.content_margin_left = 40
	title_style.content_margin_right = 40

	title_label.add_theme_stylebox_override("normal", title_style)
	for s in ["normal", "hover", "pressed", "focus"]:
		back_button.add_theme_stylebox_override(s, style)
	back_button.pivot_offset = back_button.size / 2

	# Satır Stilleri (Slider, Checkbox, Option)
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(1, 1, 1, 0.03)
	row_style.border_width_bottom = 2
	row_style.border_color = BORDER_COLOR
	row_style.border_blend = true

	for node in [res_option, fullscreen_check]:
		for s in ["normal", "hover", "pressed", "focus"]:
			node.add_theme_stylebox_override(s, row_style)

	# Sliderlar
	var rail = StyleBoxLine.new()
	rail.color = Color(1, 1, 1, 0.1)
	rail.thickness = 12
	var fill = StyleBoxLine.new()
	fill.color = BORDER_COLOR
	fill.thickness = 12

	for s in [music_slider, sfx_slider]:
		s.add_theme_stylebox_override("slider", rail)
		s.add_theme_stylebox_override("grabber_area", fill)
		s.add_theme_stylebox_override("grabber_area_highlight", fill)

func _load_settings_from_file():
	res_option.clear()
	res_option.add_item("1920x1080")
	res_option.add_item("1280x720")
	res_option.add_item("1600x900")

	var err = config.load(SAVE_PATH)
	if err == OK:
		music_slider.value = config.get_value("audio", "music", 50)
		sfx_slider.value = config.get_value("audio", "sfx", 50)
		fullscreen_check.button_pressed = config.get_value("video", "fullscreen", false)
		res_option.selected = config.get_value("video", "res_idx", 0)
		_apply_system_settings()
	else:
		music_slider.value = 50
		sfx_slider.value = 50

func _apply_system_settings():
	_on_music_changed(music_slider.value)
	_on_sfx_changed(sfx_slider.value)
	_on_fullscreen_toggled(fullscreen_check.button_pressed)
	_on_res_selected(res_option.selected)

func _on_music_changed(v):
	var idx = AudioServer.get_bus_index("Music")
	if idx != -1: AudioServer.set_bus_volume_db(idx, linear_to_db(v / 100.0))
	config.set_value("audio", "music", v)
	config.save(SAVE_PATH)

func _on_sfx_changed(v):
	var idx = AudioServer.get_bus_index("SFX")
	if idx != -1: AudioServer.set_bus_volume_db(idx, linear_to_db(v / 100.0))
	config.set_value("audio", "sfx", v)
	config.save(SAVE_PATH)

func _on_res_selected(idx):
	var txt = res_option.get_item_text(idx).split("x")
	get_window().size = Vector2i(int(txt[0]), int(txt[1]))
	config.set_value("video", "res_idx", idx)
	config.save(SAVE_PATH)

func _on_fullscreen_toggled(v):
	get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if v else Window.MODE_WINDOWED
	config.set_value("video", "fullscreen", v)
	config.save(SAVE_PATH)

func _on_back_pressed():
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	closed.emit()
	queue_free()

func _play_entrance_animation():
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "position:x", 0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.5)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)

func _connect_logic():
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	res_option.item_selected.connect(_on_res_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(func(): _tween_btn(back_button, 1.1, Color(1.5, 1.5, 2.5)))
	back_button.mouse_exited.connect(func(): _tween_btn(back_button, 1.0, Color.WHITE))

func _tween_btn(btn, sc, mod):
	var tw = create_tween().set_parallel(true)
	tw.tween_property(btn, "scale", Vector2(sc, sc), 0.2)
	tw.tween_property(btn, "modulate", mod, 0.2)
