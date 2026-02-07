extends CanvasLayer

@onready var card_buttons = [$Control/Container/Card1, $Control/Container/Card2, $Control/Container/Card3]
@onready var container = $Control/Container

const RARITY_COLORS = {
	"silver": Color(0.35, 0.35, 0.4, 1.0),    # Metalik Koyu Gri
	"gold": Color(1.0, 0.7, 0.0, 1.0),        # Saf Altın
	"prismatic": Color(0.7, 0.0, 1.0, 1.0)     # Efsanevi Mor
}

var current_cards = []
var card_tweens = {} # Her kartın büyüme animasyonunu takip etmek için

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	AugmentManager.show_augment_selection.connect(_on_show_selection)
	
	for i in range(card_buttons.size()):
		var btn = card_buttons[i]
		btn.pressed.connect(_on_card_selected.bind(i))
		# GAME FEEL: Hover efektleri için mouse sinyallerini bağla
		btn.mouse_entered.connect(_on_card_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_card_hover.bind(btn, false))
		# Kartların merkezden büyümesi için pivot noktasını ortaya çek
		btn.pivot_offset = btn.size / 2.0

func _on_show_selection(choices):
	current_cards = choices
	# Giriş Animasyonu: Konteyner biraz aşağıdan yukarı süzülsün
	container.modulate.a = 0
	container.position.y += 50
	var entry_tw = create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entry_tw.tween_property(container, "modulate:a", 1.0, 0.4)
	entry_tw.tween_property(container, "position:y", container.position.y - 50, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for btn in card_buttons: 
		btn.visible = false
		_reset_button_style(btn)
	
	for i in range(choices.size()):
		var btn = card_buttons[i]
		btn.visible = true
		btn.scale = Vector2.ZERO # Kartlar teker teker büyüyerek gelsin
		
		var card = choices[i]
		var rarity = card.get("rarity", "silver")
		var target_color = RARITY_COLORS.get(rarity, Color.WHITE)
		
		# Stil Ayarları
		var new_style = btn.get_theme_stylebox("normal").duplicate()
		if new_style is StyleBoxFlat:
			new_style.bg_color = target_color
			new_style.border_width_left = 6
			new_style.border_width_top = 6
			new_style.border_color = target_color.lightened(0.4)
			btn.add_theme_stylebox_override("normal", new_style)
			btn.add_theme_stylebox_override("hover", new_style)

		# Metinler
		btn.get_node("VBoxContainer/Title").text = card.get("name", "---")
		btn.get_node("VBoxContainer/Description").text = card.get("desc", "---")
		
		# Kart Giriş Animasyonu (Staggered)
		var btn_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		btn_tw.tween_property(btn, "scale", Vector2.ONE, 0.3).set_delay(i * 0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		# Prismatic Parlama
		if rarity == "prismatic": 
			_apply_prism_fx(btn, target_color)

	visible = true
	get_tree().paused = true

# --- GAME FEEL: DİNAMİK HOVER BÜYÜME ---
func _on_card_hover(btn: Button, is_hover: bool):
	if card_tweens.has(btn): card_tweens[btn].kill()
	
	var tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	card_tweens[btn] = tw
	
	if is_hover:
		# Büyü ve öne çık (Z-Index hissi için scale yeterli)
		tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.15).set_trans(Tween.TRANS_SINE)
		# Hafif parlat
		tw.parallel().tween_property(btn, "modulate", Color(1.2, 1.2, 1.2), 0.15)
	else:
		tw.tween_property(btn, "scale", Vector2.ONE, 0.15)
		tw.parallel().tween_property(btn, "modulate", Color.WHITE, 0.15)

func _on_card_selected(index):
	# GAME FEEL: Seçilen kartı "patlat" (Sarsıntı ve büyüme)
	var btn = card_buttons[index]
	var select_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	select_tw.tween_property(btn, "scale", Vector2(1.3, 1.3), 0.1)
	select_tw.tween_property(btn, "modulate:a", 0.0, 0.1)
	
	select_tw.finished.connect(func():
		AugmentManager.apply_augment(current_cards[index])
		visible = false
		get_tree().paused = false
	)

func _apply_prism_fx(node, base_color):
	var style = node.get_theme_stylebox("normal")
	var tween = create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Turkuaz ve Mor arası efsanevi geçiş
	tween.tween_property(style, "bg_color", Color(0.0, 1.0, 0.8), 1.0) # Turkuaz Parlama
	tween.tween_property(style, "bg_color", base_color, 1.0)

func _reset_button_style(node):
	node.scale = Vector2.ONE
	node.modulate = Color.WHITE
	node.remove_theme_stylebox_override("normal")
	node.remove_theme_stylebox_override("hover")
