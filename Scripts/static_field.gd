extends MeshInstance3D
class_name StaticField

var damage_timer: Timer

func _ready() -> void:
	damage_timer = Timer.new()
	add_child(damage_timer)
	damage_timer.wait_time = 0.2 # Saniyede 5 kez tarama (Yeterli ve performanslı)
	damage_timer.timeout.connect(_on_damage_tick)
	damage_timer.start()

func _on_damage_tick() -> void:
	if not visible: return
	
	var lv = AugmentManager.mechanic_levels.get("gold_9", 1)
	var radius = [10.0, 12.0, 16.0, 20.0][lv-1]
	var dmg_per_tick = [25.0, 50.0, 90.0, 160.0][lv-1] * damage_timer.wait_time
	
	scale = Vector3.ONE * radius * 2.0
	
	for e in get_tree().get_nodes_in_group("Enemies"):
		if is_instance_valid(e) and global_position.distance_to(e.global_position) <= radius:
			e.take_damage(dmg_per_tick)
			if lv >= 3 and randf() < 0.1: # Tick başı şans (0.2sn olduğu için şansı artırdık)
				if e.has_method("apply_freeze"): e.apply_freeze(0.6)

func _process(delta: float) -> void:
	if visible: rotate_y(delta * 4.0) # Sadece görsel rotasyon
