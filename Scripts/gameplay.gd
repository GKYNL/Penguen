extends Node3D


func _ready():
	# Sahne tamamen yüklendikten sonra ilk seçim ekranını getir
	get_tree().process_frame.connect(func():
		AugmentManager.start_game_selection()
	, CONNECT_ONE_SHOT)
	AugmentManager.initialize_game_start()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
