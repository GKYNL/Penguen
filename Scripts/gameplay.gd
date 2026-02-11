extends Node3D
@onready var player: Player = $Player



func _ready():
	# Sahne tamamen yüklendikten sonra ilk seçim ekranını getir
	get_tree().process_frame.connect(func():
		AugmentManager.start_game_selection()
	, CONNECT_ONE_SHOT)
	AugmentManager.initialize_game_start()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.get_node("HUD").visible = true
	
	var saved_data = SaveSystem.load_save_data()
	if saved_data and saved_data.has("enemies"):
		# Sahnedeki mevcut (varsayılan) canavarları temizle
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		
		# Kayıtlı canavarları yarat
		for e_data in saved_data.enemies:
			var enemy_scene = load(e_data.type)
			var enemy_inst = enemy_scene.instantiate()
			add_child(enemy_inst)
			enemy_inst.global_position = Vector2(e_data.pos_x, e_data.pos_y)
			enemy_inst.health = e_data.hp
