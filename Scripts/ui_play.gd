extends Button

func _ready() -> void:
	if not pressed.is_connected(play_game):
		pressed.connect(play_game)
		
func play_game() -> void:
	get_tree().change_scene_to_file("res://levels/gameplay.tscn")
