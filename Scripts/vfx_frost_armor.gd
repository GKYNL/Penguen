extends MeshInstance3D
class_name FrostArmor

var update_timer: Timer

func _ready() -> void:
	update_timer = Timer.new()
	add_child(update_timer)
	update_timer.wait_time = 0.25 # Saniyede 4 kez kontrol
	update_timer.timeout.connect(_on_tick)
	update_timer.start()

func _on_tick() -> void:
	if not visible: return
	
	# 1. VERİLERİ ÇEK
	var lv = AugmentManager.mechanic_levels.get("gold_2", 1)
	var radius = [9.0, 12.0, 15.5, 20.0][lv-1]
	var slow_amount = [0.2, 0.4, 0.5, 0.7][lv-1]
	
	# JSON: 3. seviyeden itibaren thorns hasarı başlar
	var thorns_damage = 0.0
	if lv == 3: thorns_damage = 20.0
	elif lv >= 4: thorns_damage = 50.0
	
	# Hasarı saniyeye bölüyoruz (Tick hızıyla orantılı vurması için)
	var dmg_per_tick = thorns_damage * update_timer.wait_time
	
	# 2. GÖRSEL ÖLÇEKLENDİRME
	scale = Vector3.ONE * radius * 1.0
	
	# 3. MESAFE BAZLI ETKİLEŞİM (Slow + Thorns)
	var enemies = get_tree().get_nodes_in_group("Enemies")
	for e in enemies:
		if is_instance_valid(e) and not e.get("is_dying"):
			var dist = global_position.distance_to(e.global_position)
			
			if dist <= radius:
				# Yavaşlatma Uygula
				if e.has_method("apply_slow"):
					e.apply_slow(slow_amount, update_timer.wait_time + 0.1)
				
				# Diken Hasarı Uygula (3. Level ve sonrası)
				if thorns_damage > 0:
					if e.has_method("take_damage"):
						e.take_damage(dmg_per_tick)

func _process(delta: float) -> void:
	if visible:
		rotate_y(delta * 0.5)
