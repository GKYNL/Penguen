extends Node3D

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 28.0
@export var is_active: bool = false
@export var pool_size: int = 50 # Aynı anda haritada olabilecek max sayı

var enemy_pool: Array[Node3D] = []
var game_time: float = 0.0
var spawn_timer: Timer

func _ready():
	add_to_group("enemy_spawner")
	
	# HAVUZU DOLDUR
	for i in range(pool_size):
		_create_to_pool()
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 2.0
	spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(spawn_timer)
	
	if not AugmentManager.is_connected("mechanic_unlocked", _on_start_game):
		AugmentManager.mechanic_unlocked.connect(_on_start_game)

func _create_to_pool():
	var e = enemy_scene.instantiate()
	# Önce sahneye ekle
	add_child(e)
	
	# Ayarları yap
	e.visible = false
	e.process_mode = Node.PROCESS_MODE_DISABLED
	
	# HATA FIX: is_inside_tree hatası için global_position yerine position kullanıyoruz
	# Ve objenin ağaca girmesi için bir kare beklemeye gerek kalmadan yerel koordinat veriyoruz
	e.position = Vector3(0, -50.0, 0)
	
	if e.has_signal("returned_to_pool"):
		e.returned_to_pool.connect(_on_enemy_returned)
	
	enemy_pool.append(e)

func _on_enemy_returned(enemy):
	# Düşman havuza döndüğünde de position kullanmak daha güvenlidir
	enemy.position = Vector3(0, -50.0, 0)
	enemy_pool.append(enemy)

func _on_start_game(_id):
	if not is_active:
		is_active = true
		spawn_timer.start()

func _process(delta):
	if not is_active: return
	game_time += delta
	# Zorluk Artışı
	var new_wait = 2.0 - (game_time / 60.0) * 0.2
	spawn_timer.wait_time = clamp(new_wait, 0.3, 2.0)

func _on_spawn_tick():
	if enemy_pool.is_empty(): return # Havuz boşsa spawn etme
	
	# LEVEL 1 KORUMASI
	var active_count = get_tree().get_nodes_in_group("Enemies").filter(func(e): return e.visible).size()
	if game_time < 60.0 and active_count >= 12: return

	_spawn_from_pool()

func _spawn_from_pool():
	var enemy = enemy_pool.pop_back()
	var player = get_tree().get_first_node_in_group("player")
	if !player: return
	
	# Pozisyon Ayarla
	var angle = randf() * TAU
	var pos = player.global_position + Vector3(cos(angle), 0, sin(angle)) * spawn_radius
	var safe_pos = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, pos)
	
	enemy.global_position = safe_pos
	enemy.stage = int(game_time / 60.0) + 1
	enemy.reset_for_spawn() # Objeyi dirilt
