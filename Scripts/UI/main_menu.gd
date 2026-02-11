extends Control

# --- AYARLAR VE SAHNELER ---
# Settings sahnesinin yolunu buraya yaz (Dosya ismini kontrol et!)
const SETTINGS_SCENE = preload("res://levels/settings_menu.tscn")

# --- RENK PALETİ (3D Alanla Uyumlu) ---
const BORDER_COLOR = Color("4fe3ff") # Parlak Buz Mavisi
const BG_COLOR = Color("0a1a2f")     # Çok Koyu Gece Mavisi (Şeffaf kullanılacak)

@onready var play_button = $MarginContainer/MenuButtons/PlayButton
@onready var settings_button = $MarginContainer/MenuButtons/SettingsButton
@onready var quit_button = $MarginContainer/MenuButtons/QuitButton
@onready var menu_container = $MarginContainer/MenuButtons

var tween_speed: float = 0.25

func _ready():
	_apply_settings_on_startup()
	for btn in [play_button, settings_button, quit_button]:
		_setup_modern_border_style(btn)
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.mouse_exited.connect(_on_button_unhover.bind(btn))
		btn.pressed.connect(_on_button_pressed.bind(btn))
		
		# Pivotu merkeze al ki küçülürken kendi içine kapansın
		btn.pivot_offset = btn.size / 2

func _apply_settings_on_startup():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		# SESLERİ UYGULA
		var m_vol = config.get_value("audio", "music", 50)
		var s_vol = config.get_value("audio", "sfx", 50)
		var m_idx = AudioServer.get_bus_index("Music")
		var s_idx = AudioServer.get_bus_index("SFX")
		
		if m_idx != -1: AudioServer.set_bus_volume_db(m_idx, linear_to_db(m_vol / 100.0))
		if s_idx != -1: AudioServer.set_bus_volume_db(s_idx, linear_to_db(s_vol / 100.0))
		
		# EKRAN AYARLARINI UYGULA
		var fs = config.get_value("video", "fullscreen", false)
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if fs else Window.MODE_WINDOWED
		
		var res_idx = config.get_value("video", "res_idx", 0)
		var res_list = ["1920x1080", "1280x720", "1600x900"]
		var res_parts = res_list[res_idx].split("x")
		get_window().size = Vector2i(int(res_parts[0]), int(res_parts[1]))

# --- MODERN BORDER TASARIMI ---
func _setup_modern_border_style(btn: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.bg_color.a = 0.6
	style.border_width_left = 6
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 6
	style.border_color = BORDER_COLOR
	style.border_blend = true
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 12
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

# --- HOVER ANİMASYONLARI ---
func _on_button_hover(btn: Button):
	var tw = create_tween().set_parallel(true)
	tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK)
	tw.tween_property(btn, "modulate", Color(1.3, 1.3, 1.8), 0.2) # Parlama efekti

func _on_button_unhover(btn: Button):
	var tw = create_tween().set_parallel(true)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
	tw.tween_property(btn, "modulate", Color.WHITE, 0.2)

# --- ÇİZGİ FİLM EFECTİ (Sola Fırlama) ---
func _on_button_pressed(btn: Button):
	# TÜM BUTONLARI SIRAYLA FIRLAT (Hangi butona basıldığı önemli değil)
	var buttons = menu_container.get_children()
	for i in range(buttons.size()):
		var b = buttons[i]
		# Sıralı fırlama hissi için i * 0.1 saniye gecikme
		get_tree().create_timer(i * 0.1).timeout.connect(func(): _exit_animation(b))
	
	# BUTON ÖZEL AKSİYONLARI
	if btn == play_button:
		await get_tree().create_timer(0.8).timeout
		get_tree().change_scene_to_file("res://levels/gameplay.tscn")
		
	elif btn == settings_button:
		await get_tree().create_timer(0.6).timeout
		_open_settings_overlay()
		
	elif btn == quit_button:
		await get_tree().create_timer(0.6).timeout
		get_tree().quit()

func _exit_animation(btn: Button):
	var tw = create_tween()
	# 1. SAĞA ATILIM
	tw.tween_property(btn, "position:x", btn.position.x + 40, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 2. SOLA FIRLAMA VE KÜÇÜLME
	tw.parallel().tween_property(btn, "position:x", -1500, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(btn, "scale", Vector2(0.1, 0.1), 0.4)
	tw.parallel().tween_property(btn, "modulate:a", 0.0, 0.3) # EKLE: Butonu tamamen şeffaf yap
	
	await tw.finished
	btn.visible = false # EKLE: Animasyon bitince tamamen devre dışı bırak

# --- SETTINGS INSTANTIATE (Yeni Scene Ekleme) ---
func _open_settings_overlay():
	var settings_inst = SETTINGS_SCENE.instantiate()
	
	# KRİTİK: Daha add_child yapmadan önce görünmez ve sağda yapıyoruz!
	settings_inst.modulate.a = 0     # Tamamen şeffaf yap
	settings_inst.position.x = 1200  # Ekranın dışına at
	settings_inst.scale = Vector2(0.1, 0.1)
	
	add_child(settings_inst) # Şimdi sahneye ekle (artık o "çirkin" haliyle görünemez)
	
	# Sinyali bağla
	if settings_inst.has_signal("closed"):
		settings_inst.closed.connect(_on_settings_closed)
	

func _on_settings_closed():
	var buttons = menu_container.get_children()
	
	for i in range(buttons.size()):
		var b = buttons[i]
		
		# 1. ÖNCE HAZIRLA (Ama hala şeffaf kalsın)
		b.modulate.a = 0.0      # Tamamen şeffaf
		b.visible = true        # Teknik olarak görünür ama gözle görülmez
		b.rotation_degrees = 0
		b.scale = Vector2.ONE
		
		# 2. ANİMASYONU KUR
		var tw = create_tween().set_parallel(true)
		
		# Sağdan gelme efekti (1500 yerine senin ekran genişliğine göre ayarla)
		tw.tween_property(b, "position:x", 0.0, 0.5)\
			.from(1500)\
			.set_delay(i * 0.1)\
			.set_trans(Tween.TRANS_QUART)\
			.set_ease(Tween.EASE_OUT)
		
		# Şeffaflığı aç (Bu o bir saliselik görüntüyü engeller)
		tw.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(i * 0.1)
