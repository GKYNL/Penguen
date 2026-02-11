extends CanvasLayer

const BORDER_COLOR = Color("4fe3ff")
const BG_COLOR = Color("0a1a2f")

@onready var title = $VBoxContainer/DeathTitle
@onready var stat_label = $VBoxContainer/StatLabel
@onready var restart_btn = $VBoxContainer/RestartButton
@onready var menu_btn = $VBoxContainer/MainMenuButton
@onready var container = $VBoxContainer

func _ready():
	self.visible = false
	_setup_styles()

func setup_and_show(level: int, time_str: String):
	stat_label.text = "LEVEL: %d  |  SURVIVED: %s" % [level, time_str]
	self.visible = true
	
	# Giriş Animasyonu
	container.modulate.a = 0
	container.scale = Vector2(0.8, 0.8)
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(container, "modulate:a", 1.0, 0.5)
	tw.tween_property(container, "scale", Vector2.ONE, 0.5)
	
	# Fareyi göster
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _setup_styles():
	var style = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.bg_color.a = 0.85
	style.border_width_left = 6
	style.border_width_bottom = 6
	style.border_color = BORDER_COLOR
	style.border_blend = true
	style.corner_radius_bottom_right = 20
	style.content_margin_left = 30
	style.content_margin_right = 30

	for btn in [restart_btn, menu_btn]:
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.pressed.connect(_on_btn_pressed.bind(btn))
		btn.pivot_offset = btn.size / 2

func _on_btn_pressed(btn):
	if btn == restart_btn:
		get_tree().paused = false
		get_tree().reload_current_scene()
	elif btn == menu_btn:
		get_tree().paused = false
		get_tree().quit()
