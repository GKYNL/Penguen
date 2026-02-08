extends Node3D

@export_group("Setup")
@export var enemy_scene: PackedScene # BURAYA enemy.tscn ATANMALI!
@export var spawn_radius: float = 28.0
@export var despawn_radius: float = 55.0
@export var is_active: bool = false

# --- DALGA SENARYOSU ---
var waves = [
	# 0-30.sn: Sadece zayıf, hızlı (Isınma)
	{"time": 0, "type": 0, "interval": 0.5, "amount": 1, "elite_chance": 0.0, "hp_mod": 1.0, "spd_mod": 1.2},
	# 30-60.sn: Tanklar karışır
	{"time": 30, "type": 1, "interval": 1.5, "amount": 2, "elite_chance": 0.0, "hp_mod": 2.0, "spd_mod": 0.7},
	# 60-120.sn: Okçular ve Karışık
	{"time": 60, "type": 2, "interval": 2.0, "amount": 3, "elite_chance": 0.05, "hp_mod": 1.5, "spd_mod": 1.0},
	# 2. Dakika: Kaos
	{"time": 120, "type": 0, "interval": 0.2, "amount": 4, "elite_chance": 0.1, "hp_mod": 3.0, "spd_mod": 1.3}
]

var current_wave_index: int = 0
var game_time: float = 0.0
var time_until_next_spawn: float = 0.0
var map_ready: bool = false # HATA 1 FIX: Harita kontrolü

var enemy_pool: Array[Node3D] = []
var active_enemies: Array[Node3D] = []
var player: Node3D = null

func _ready():
	add_to_group("enemy_spawner")
	player = get_tree().get_first_node_in_group("player")
	
	# HATA 1 FIX: Haritanın yüklenmesini bekle (2 fizik karesi)
	await get_tree().physics_frame
	await get_tree().physics_frame
	map_ready = true
	
	# Başlangıç ayarı
	if not AugmentManager.is_connected("mechanic_unlocked", _on_mechanic_unlocked):
		AugmentManager.mechanic_unlocked.connect(_on_mechanic_unlocked)

func _on_mechanic_unlocked(_id):
	if not is_active: 
		is_active = true
		print("⚔️ HORDE STARTED")

func _process(delta):
	# Harita hazır değilse, oyun durduysa veya player öldüyse çalışma
	if not map_ready or get_tree().paused or not is_instance_valid(player): return
	if not is_active: return
	
	# Time Stop kontrolü
	if "is_time_stopped" in player and player.is_time_stopped: return

	game_time += delta
	_check_wave_update()
	
	time_until_next_spawn -= delta
	if time_until_next_spawn <= 0.0:
		_spawn_wave_batch()
		# Sonraki spawn süresini belirle
		time_until_next_spawn = waves[current_wave_index]["interval"]
	
	# Temizlik (30 frame'de bir)
	if Engine.get_frames_drawn() % 30 == 0:
		_cleanup_distant_enemies()

func _check_wave_update():
	if current_wave_index < waves.size() - 1:
		if game_time >= waves[current_wave_index + 1]["time"]:
			current_wave_index += 1
			print("🌊 WAVE LEVEL UP: ", current_wave_index)

func _spawn_wave_batch():
	var data = waves[current_wave_index]
	var count = data["amount"]
	
	for i in range(count):
		_spawn_single_enemy(data)

func _spawn_single_enemy(data):
	# HATA 2 FIX: Sahne atanmamışsa oyunu çökertme, hata bas ve çık
	if not enemy_scene:
		push_error("HATA: Enemy Spawner'da 'Enemy Scene' boş! Inspector'dan atama yap!")
		is_active = false # Spam yapmasın diye durdur
		return

	# 1. Pozisyon
	var spawn_pos = _get_safe_spawn_pos()
	if spawn_pos == Vector3.ZERO: return

	# 2. Havuzdan Çek
	var enemy = _get_enemy_from_pool()
	if not enemy: return # Havuz/Instantiate hatası varsa çık
	
	if not enemy.is_inside_tree(): get_tree().root.add_child(enemy)
	enemy.global_position = spawn_pos
	
	if not enemy in active_enemies: active_enemies.append(enemy)
	
	# 3. Özellikleri Ayarla
	var is_elite = randf() < data["elite_chance"]
	if is_elite:
		enemy.setup_elite(data["hp_mod"], data["spd_mod"])
	else:
		enemy.setup_standard(data["type"], data["hp_mod"], data["spd_mod"])
	
	if enemy.has_method("reset_physics"): enemy.reset_physics()

# --- YARDIMCILAR ---
func _get_safe_spawn_pos() -> Vector3:
	var angle = randf() * TAU
	var dist = spawn_radius + randf_range(-2.0, 2.0)
	var raw_pos = player.global_position + Vector3(cos(angle), 0, sin(angle)) * dist
	
	var map = get_world_3d().navigation_map
	var safe_pos = NavigationServer3D.map_get_closest_point(map, raw_pos)
	
	# Oyuncuya çok yakınsa veya (0,0,0) hatasıysa reddet
	if safe_pos.distance_to(player.global_position) < 10.0: return Vector3.ZERO
	return safe_pos

func _cleanup_distant_enemies():
	var p_pos = player.global_position
	for i in range(active_enemies.size() - 1, -1, -1):
		var enemy = active_enemies[i]
		if is_instance_valid(enemy) and enemy.global_position.distance_to(p_pos) > despawn_radius:
			_return_to_pool(enemy)
			active_enemies.remove_at(i)

func _get_enemy_from_pool() -> Node3D:
	if enemy_pool.is_empty(): 
		if enemy_scene: return enemy_scene.instantiate()
		else: return null
	
	var e = enemy_pool.pop_back()
	e.process_mode = Node.PROCESS_MODE_PAUSABLE
	e.visible = true
	return e

func _return_to_pool(enemy: Node3D):
	if enemy.has_method("cleanup"): enemy.cleanup()
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.visible = false
	enemy.global_position = Vector3(0, -500, 0)
	enemy_pool.append(enemy)
