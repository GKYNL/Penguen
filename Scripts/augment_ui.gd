extends CanvasLayer

@onready var card_buttons = [$Control/Container/Card1, $Control/Container/Card2, $Control/Container/Card3]
@onready var container = $Control/Container

# Renkleri daha doygun ve net yaptım
const RARITY_COLORS = {
	"silver": Color(0.4, 0.4, 0.45, 1.0),    # Saf Metalik Gri
	"gold": Color(1.0, 0.75, 0.0, 1.0),      # Parlak Altın Sarısı
	"prismatic": Color(0.8, 0.0, 1.0, 1.0)   # Derin Mor/Eflatun
}

var current_cards = []

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	AugmentManager.show_augment_selection.connect(_on_show_selection)
	for i in range(card_buttons.size()):
		card_buttons[i].pressed.connect(_on_card_selected.bind(i))

func _on_show_selection(choices):
	current_cards = choices
	for btn in card_buttons: 
		btn.visible = false
		# Önceki seçimden kalan animasyonları ve renkleri sıfırla
		_reset_button_style(btn)
	
	for i in range(choices.size()):
		var btn = card_buttons[i]
		btn.visible = true
		
		var rarity = choices[i].get("rarity", "silver")
		var target_color = RARITY_COLORS.get(rarity, Color.WHITE)
		
		# --- STYLEBOX MÜDAHALESİ ---
		# Butonun 'Normal' stilini alıp rengini değiştiriyoruz
		var new_style = btn.get_theme_stylebox("normal").duplicate()
		if new_style is StyleBoxFlat:
			new_style.bg_color = target_color
			# Kenarlık (border) ekleyerek daha belirgin yapalım
			new_style.border_width_left = 4
			new_style.border_width_top = 4
			new_style.border_width_right = 4
			new_style.border_width_bottom = 4
			new_style.border_color = target_color.lightened(0.3)
			
			btn.add_theme_stylebox_override("normal", new_style)
			btn.add_theme_stylebox_override("hover", new_style) # Üzerine gelince de bozmasın
		
		var title = btn.get_node_or_null("VBoxContainer/Title")
		var desc = btn.get_node_or_null("VBoxContainer/Description")
		if title: title.text = choices[i].get("name", "---")
		if desc: desc.text = choices[i].get("desc", "---")
		
		# Sadece prismatic ise o özel parlamayı ekle
		if rarity == "prismatic": 
			_apply_prism_fx(btn, target_color)

	visible = true
	get_tree().paused = true

func _reset_button_style(node):
	# Butonun üzerindeki tüm override'ları ve tween'leri temizler
	node.remove_theme_stylebox_override("normal")
	node.remove_theme_stylebox_override("hover")
	var tw = create_tween() # Aktif tweenleri durdurmak için
	tw.kill() 

func _apply_prism_fx(node, base_color):
	var style = node.get_theme_stylebox("normal")
	var tween = create_tween().set_loops()
	# Mor ve Turkuaz arası giden o efsane efekt
	tween.tween_property(style, "bg_color", Color(0.2, 0.8, 1.0), 0.8) # Turkuaz
	tween.tween_property(style, "bg_color", base_color, 0.8) # Geri Mor

func _on_card_selected(index):
	AugmentManager.apply_augment(current_cards[index])
	visible = false
	get_tree().paused = false
