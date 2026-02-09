extends CanvasLayer

@onready var card_buttons = [$Control/Container/Card1, $Control/Container/Card2, $Control/Container/Card3]
@onready var container = $Control/Container

const RARITY_COLORS = {
	"silver": Color(0.2, 0.2, 0.25, 1.0),    # Modern Koyu Füme
	"gold": Color(1.0, 0.65, 0.0, 1.0),      # Derin Altın
	"prismatic": Color(0.6, 0.0, 1.0, 1.0)   # Neon Mor
}

var current_cards = []
var card_tweens = {}
var current_selection : int = 0 # Klavyeyle navigasyon için

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	AugmentManager.show_augment_selection.connect(_on_show_selection)
	
	for i in range(card_buttons.size()):
		var btn = card_buttons[i]
		btn.pressed.connect(_on_card_selected.bind(i))
		btn.mouse_entered.connect(_on_mouse_hover.bind(i))
		btn.pivot_offset = btn.size / 2.0
		# Focus modunu kapatıyoruz ki kendi yazdığımız navigasyonla çakışmasın
		btn.focus_mode = Control.FOCUS_NONE

func _input(event):
	if not visible: return
	
	var handled = false
	
	if event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_update_selection((current_selection + 1) % current_cards.size())
		handled = true
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_update_selection((current_selection - 1 + current_cards.size()) % current_cards.size())
		handled = true
	elif event.is_action_pressed("ui_accept"):
		_on_card_selected(current_selection)
		handled = true
		
	if handled:
		# KRİTİK: Inputun düşmanlara veya karaktere gitmesini durdurur
		get_viewport().set_input_as_handled()

func _on_show_selection(choices):
	current_cards = choices
	current_selection = 0
	
	# Konteyner Giriş Efekti
	container.modulate.a = 0
	container.scale = Vector2(0.9, 0.9)
	var entry_tw = create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entry_tw.tween_property(container, "modulate:a", 1.0, 0.3)
	entry_tw.tween_property(container, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)

	for i in range(card_buttons.size()):
		var btn = card_buttons[i]
		if i < choices.size():
			btn.visible = true
			_setup_card_visuals(btn, choices[i], i)
		else:
			btn.visible = false

	visible = true
	get_tree().paused = true
	_update_selection(0) # İlk kartı otomatik seçili başlat

func _setup_card_visuals(btn: Button, card_data, index):
	var rarity = card_data.get("rarity", "silver")
	var base_color = RARITY_COLORS.get(rarity, Color.WHITE)
	
	# Stil Hazırlığı
	var style = StyleBoxFlat.new()
	style.bg_color = base_color
	style.corner_radius_top_left = 15
	style.corner_radius_bottom_right = 15
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_color = base_color.lightened(0.3)
	style.shadow_size = 10
	style.shadow_color = Color(0, 0, 0, 0.3)
	
	btn.add_theme_stylebox_override("normal", style)
	
	# Metinler
	btn.get_node("VBoxContainer/Title").text = card_data.get("name", "---")
	btn.get_node("VBoxContainer/Description").text = card_data.get("desc", "---")
	
	# Kart Giriş Animasyonu
	btn.scale = Vector2.ZERO
	var tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.4).set_delay(index * 0.1).set_trans(Tween.TRANS_BACK)

func _update_selection(index: int):
	current_selection = index
	for i in range(current_cards.size()):
		_animate_card_focus(card_buttons[i], i == current_selection)

func _animate_card_focus(btn: Button, is_focused: bool):
	if card_tweens.has(btn): card_tweens[btn].kill()
	var tw = create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	card_tweens[btn] = tw
	
	if is_focused:
		tw.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.15).set_trans(Tween.TRANS_SINE)
		tw.tween_property(btn, "modulate", Color(1.3, 1.3, 1.3), 0.15)
		# HATA BURADAYDI: set_relative() -> as_relative() yapıldı.
		tw.tween_property(btn, "position:y", -20.0, 0.15).as_relative()
	else:
		tw.tween_property(btn, "scale", Vector2.ONE, 0.15)
		tw.tween_property(btn, "modulate", Color.WHITE, 0.15)
		# Normal pozisyona dönmesi için relative yapmıyoruz, 0'a çekiyoruz.
		tw.tween_property(btn, "position:y", 0.0, 0.15)

func _on_mouse_hover(index: int):
	if current_selection != index:
		_update_selection(index)

func _on_card_selected(index):
	var btn = card_buttons[index]
	# Seçim Efekti (Flash)
	var sel_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	sel_tw.tween_property(btn, "modulate", Color(5, 5, 5, 1), 0.1) # Beyaz parlama
	sel_tw.tween_property(btn, "scale", Vector2(1.4, 1.4), 0.1)
	sel_tw.parallel().tween_property(btn, "modulate:a", 0.0, 0.2)
	
	sel_tw.finished.connect(func():
		AugmentManager.apply_augment(current_cards[index])
		visible = false
		get_tree().paused = false
	)
