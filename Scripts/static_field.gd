extends MeshInstance3D
class_name StaticField

var damage_timer: Timer

func _ready() -> void:
	damage_timer = Timer.new()
	add_child(damage_timer)
	damage_timer.wait_time = 0.2
	damage_timer.timeout.connect(_on_damage_tick)
	# Timer'ı burada başlatmıyoruz, on_spawn'da başlatacağız

# --- POOL BAŞLANGICI ---
func on_spawn():
	if damage_timer:
		damage_timer.start()
	
	# Başlangıç level ve boyut ayarı
	var lv = AugmentManager.mechanic_levels.get("gold_9", 1)
	var radius = [10.0, 12.0, 16.0, 20.0][lv-1]
	scale = Vector3.ONE * radius * 2.0
	visible = true

func _on_damage_tick() -> void:
	if not visible: return
	
	var lv = AugmentManager.mechanic_levels.get("gold_9", 1)
	var radius = [10.0, 12.0, 16.0, 20.0][lv-1]
	# hasarı scale'e göre de ayarlayabiliriz ama şimdilik veri sabit
	var dmg_per_tick = [25.0, 50.0, 90.0, 160.0][lv-1] * damage_timer.wait_time
	
	# Scale'i güncelle (eğer level arttıysa dinamik büyüsün)
	scale = scale.lerp(Vector3.ONE * radius * 2.0, 0.1)
	
	for e in get_tree().get_nodes_in_group("Enemies"):
		if is_instance_valid(e) and global_position.distance_to(e.global_position) <= radius:
			e.take_damage(dmg_per_tick)
			if lv >= 3 and randf() < 0.1:
				if e.has_method("apply_freeze"): e.apply_freeze(0.6)

func _process(delta: float) -> void:
	if visible: rotate_y(delta * 4.0)

# Static field genelde kalıcıdır, ama geri göndermek istersen:
func remove_field():
	if damage_timer: damage_timer.stop()
	VFXPoolManager.return_to_pool(self, "static_field")
