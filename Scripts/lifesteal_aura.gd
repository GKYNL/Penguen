extends MeshInstance3D
class_name LifestealAura

var tick_timer: Timer

func _ready() -> void:
	tick_timer = Timer.new()
	add_child(tick_timer)
	tick_timer.wait_time = 0.25 # Saniyede 4 kez tarama
	tick_timer.timeout.connect(_on_tick)
	tick_timer.start()

func _on_tick() -> void:
	if not visible: return
	
	var lv = AugmentManager.mechanic_levels.get("gold_7", 1)
	var radius = [6.0, 7.5, 9.0, 11.0][lv-1]
	var dmg_per_tick = [15.0, 25.0, 40.0, 60.0][lv-1] * tick_timer.wait_time
	
	scale = Vector3.ONE * radius * 2.0
	var player = get_parent()
	
	for e in get_tree().get_nodes_in_group("Enemies"):
		if is_instance_valid(e) and global_position.distance_to(e.global_position) <= radius:
			e.take_damage(dmg_per_tick)
			if player.has_method("heal"):
				player.heal(3.0 * tick_timer.wait_time)

func _process(delta: float) -> void:
	if visible: rotate_y(delta * 2.0)
