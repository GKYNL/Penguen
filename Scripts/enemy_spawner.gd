extends Node3D

@export var enemy_scene: PackedScene
@export var pool_size: int = 80

# RING (HALKA) AYARLARI
@export var base_ring_count: int = 10          # minimum halka düşmanı
@export var max_ring_count: int = 40           # maksimum halka düşmanı (pool'a göre de sınır)
@export var base_ring_radius: float = 18.0     # DAHA GENİŞ ÇAP (önceki 10'du)
@export var radius_per_power: float = 0.25     # güç arttıkça halka biraz daha dışarı
@export var ring_jitter: float = 1.2           # geniş çapa uygun biraz daha jitter
@export var ring_interval: float = 2.0

# GÜÇE ORANLA SPAWN
@export var base_power: float = 10.0           # 10 güce kadar minimum say
@export var count_per_power: float = 0.7       # her +1 güç için kaç düşman artsın (0.7 => +10 güç = +7 enemy)
@export var power_smoothing: float = 0.25      # ani sıçramaları yumuşatır (0..1)

@export var is_active: bool = false

var enemy_pool: Array[Node3D] = []
var game_time: float = 0.0
var spawn_timer: Timer

# gücü yumuşatmak için
var _smoothed_power: float = 0.0


func _ready():
	add_to_group("enemy_spawner")

	# POOL OLUŞTUR
	for i in range(pool_size):
		_create_to_pool()

	spawn_timer = Timer.new()
	spawn_timer.wait_time = ring_interval
	spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(spawn_timer)

	if not AugmentManager.is_connected("mechanic_unlocked", _on_start_game):
		AugmentManager.mechanic_unlocked.connect(_on_start_game)


func _create_to_pool():
	var e = enemy_scene.instantiate()

	# SAHNEYE GİRMEDEN ÖNCE
	e.visible = false
	e.process_mode = Node.PROCESS_MODE_DISABLED
	e.scale = Vector3(0.1, 0.1, 0.1) # Jolt fix

	if e.has_signal("returned_to_pool"):
		e.returned_to_pool.connect(_on_enemy_returned)

	get_tree().root.call_deferred("add_child", e)
	e.set_deferred("global_position", Vector3(0, -50, 0))

	enemy_pool.append(e)


func _on_enemy_returned(enemy):
	if is_instance_valid(enemy):
		enemy.visible = false
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.global_position = Vector3(0, -50, 0)
		enemy_pool.append(enemy)


func _on_start_game(_id):
	if is_active: return
	is_active = true
	spawn_timer.start()


func _process(delta):
	if not is_active: return

	game_time += delta

	# İstersen zorlukla birlikte biraz hızlansın (çok agresif olmasın)
	var new_wait = ring_interval - (game_time / 60.0) * 0.2
	spawn_timer.wait_time = clamp(new_wait, 0.6, ring_interval)

	# güç değerini yumuşat (ani item pickup'larda patlamasın)
	var p = _get_player_power()
	_smoothed_power = lerp(_smoothed_power, p, clamp(power_smoothing, 0.0, 1.0))


func _on_spawn_tick():
	if enemy_pool.is_empty(): return

	# Aktif enemy sayısı (sahne düzenine göre grup adı)
	var active_count = get_tree().get_nodes_in_group("Enemies").filter(
		func(e): return e.visible
	).size()

	# LEVEL 1 KORUMASI (ilk 60 saniye ekrana abanma)
	var desired = _calc_ring_count_from_power()
	if game_time < 60.0 and active_count >= desired:
		return

	_spawn_ring_from_pool(desired, _calc_ring_radius_from_power())


# --- GÜÇ HESABI --- #
func _get_player_power() -> float:
	var player = get_tree().get_first_node_in_group("player")
	if !player:
		return 0.0

	# 1) Eğer player scriptinde "power" property varsa
	if "power" in player:
		return float(player.power)

	# 2) Eğer method varsa (ör. get_power)
	if player.has_method("get_power"):
		return float(player.get_power())

	# 3) Yoksa şimdilik 0
	return 0.0


func _calc_ring_count_from_power() -> int:
	# güç 10 ise base_ring_count
	# güç arttıkça count artar
	var p = max(_smoothed_power, 0.0)
	var extra = max(p - base_power, 0.0) * count_per_power
	var desired = int(round(float(base_ring_count) + extra))
	desired = clamp(desired, base_ring_count, max_ring_count)

	# pool sınırı
	desired = min(desired, enemy_pool.size())
	return desired


func _calc_ring_radius_from_power() -> float:
	var p = max(_smoothed_power, 0.0)
	return base_ring_radius + p * radius_per_power


# --- HALKA SPAWN --- #
func _spawn_ring_from_pool(count: int, radius: float):
	var player = get_tree().get_first_node_in_group("player")
	if !player: return

	var n = min(count, enemy_pool.size())
	if n <= 0: return

	var start_angle = randf() * TAU
	var step = TAU / float(n)

	for i in range(n):
		if enemy_pool.is_empty(): break

		var enemy = enemy_pool.pop_back()
		if !is_instance_valid(enemy): continue

		var angle = start_angle + step * float(i)

		# geniş radius + jitter
		var r = radius + randf_range(-ring_jitter, ring_jitter)

		var target_pos = player.global_position + Vector3(
			cos(angle),
			0,
			sin(angle)
		) * r

		var safe_pos = NavigationServer3D.map_get_closest_point(
			get_world_3d().navigation_map,
			target_pos
		)

		enemy.global_position = safe_pos
		enemy.stage = int(game_time / 60.0) + 1
		enemy.reset_for_spawn()
