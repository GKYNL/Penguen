extends MeshInstance3D
class_name FrostArmor

var update_timer: Timer

func _ready() -> void:
	update_timer = Timer.new()
	add_child(update_timer)
	update_timer.wait_time = 0.5 
	update_timer.timeout.connect(_update_visual_scale)
	update_timer.start()

func _update_visual_scale() -> void:
	if not visible: return
	var lv = AugmentManager.mechanic_levels.get("gold_2", 1)
	var radius = [5.0, 6.0, 7.5, 9.0][lv-1]
	scale = Vector3.ONE * radius * 2.0

# Process tamamen boşaltıldı, yük sıfır.
