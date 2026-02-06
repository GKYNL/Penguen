extends Node3D

# --- SETTINGS ---
@export var world_seed: int = 23452 : set = _set_seed
@export var chunk_size: int = 16 
@export var tile_size: float = 4.0 
@export var render_distance: int = 3
@export var ground_index: int = 0 

# --- PERFORMANCE SETTINGS ---
@export var bake_cooldown: float = 1.5 # Bake işlemleri arasındaki minimum bekleme süresi

# --- ASSETS ---
@export var spike_scene: PackedScene # Buz dikiti sahnen (StaticBody3D + Mesh)

@onready var grid_map: GridMap = $GridMap
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

signal map_ready

var player = null
var noise = FastNoiseLite.new()
var active_chunks = {} 
var is_updating = false 
var last_player_chunk: Vector2i = Vector2i(-999, -999)

# --- NAVMESH OPTIMIZASYON DEĞİŞKENLERİ ---
var is_nav_dirty: bool = false # NavMesh'in güncellenmesi gerekiyor mu?
var bake_timer: Timer

func _ready():
	player = get_tree().get_first_node_in_group("player")
	_setup_noise()
	
	if grid_map:
		grid_map.cell_size = Vector3(tile_size, 2.0, tile_size)
		# Sadece zemin GridMap'ini "Walkable" grubuna ekliyoruz
		grid_map.add_to_group("Walkable") 
	
	if nav_region:
		nav_region.bake_finished.connect(_on_bake_finished)
		
	# BAKE TIMER KURULUMU: Sürekli bake yapmak yerine biriktirip yapmak için.
	bake_timer = Timer.new()
	bake_timer.wait_time = bake_cooldown
	bake_timer.autostart = true
	bake_timer.timeout.connect(_check_bake_queue)
	add_child(bake_timer)
	
	if player: 
		_update_chunks_logic(get_player_chunk())

func _set_seed(val):
	world_seed = val
	if noise: noise.seed = val

func _setup_noise():
	noise.seed = world_seed
	noise.frequency = 0.12 
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

func get_player_chunk() -> Vector2i:
	var p_pos = player.global_position
	return Vector2i(
		int(floor(p_pos.x / (chunk_size * tile_size))),
		int(floor(p_pos.z / (chunk_size * tile_size)))
	)

func _process(_delta):
	if player and not is_updating:
		var curr_chunk = get_player_chunk()
		if curr_chunk != last_player_chunk:
			last_player_chunk = curr_chunk
			_update_chunks_logic(curr_chunk)

func _update_chunks_logic(center_chunk: Vector2i):
	is_updating = true 
	
	var target_chunks = []
	for x in range(center_chunk.x - render_distance, center_chunk.x + render_distance + 1):
		for y in range(center_chunk.y - render_distance, center_chunk.y + render_distance + 1):
			target_chunks.append(Vector2i(x, y))
	
	# 1. Uzaktakileri Sil
	var current_keys = active_chunks.keys()
	for c in current_keys:
		if c not in target_chunks:
			_unload_chunk_internal(c)
			active_chunks.erase(c)
			is_nav_dirty = true # NavMesh kirlendi (Güncelleme lazım)
	
	# 2. Yeni Chunkları Yükle
	for c in target_chunks:
		if c not in active_chunks:
			_load_chunk_internal(c)
			is_nav_dirty = true # NavMesh kirlendi
			
	is_updating = false

# --- OPTİMİZE BAKE MANTIĞI ---
func _check_bake_queue():
	if is_nav_dirty and nav_region:
		print("🗺️ NavMesh Optimize Ediliyor... (Dikitler Pas Geçiliyor)")
		# Arka planda bake başlat
		nav_region.bake_navigation_mesh(false)
		is_nav_dirty = false

func _on_bake_finished():
	print("✅ NavMesh Bake Tamamlandı! Zemin yürünebilir.")
	map_ready.emit()

func _load_chunk_internal(coord: Vector2i):
	active_chunks[coord] = [] 
	
	for x in range(chunk_size):
		for z in range(chunk_size):
			var gx = (coord.x * chunk_size) + x
			var gz = (coord.y * chunk_size) + z
			
			# Zemini GridMap ile yerleştir
			grid_map.set_cell_item(Vector3i(gx, 0, gz), ground_index)
			
			# Buz dikiti kontrolü
			var noise_val = noise.get_noise_2d(gx, gz)
			if noise_val > 0.35 and randf() > 0.6:
				_spawn_spike(coord, gx, gz)

func _spawn_spike(coord: Vector2i, gx: int, gz: int):
	if not spike_scene: return
	
	# Deterministic Seed: Koordinata göre sabit rastgelelik
	var spike_seed = (gx * 1000) + gz + world_seed
	var rng = RandomNumberGenerator.new()
	rng.seed = spike_seed
	
	var spike = spike_scene.instantiate()
	add_child(spike) # Spike "Walkable" grubuna eklenmez, bake hızı artar!
	
	# Pozisyon Kayması
	var offset_x = rng.randf_range(-tile_size/2.5, tile_size/2.5)
	var offset_z = rng.randf_range(-tile_size/2.5, tile_size/2.5)
	spike.global_position = Vector3(gx * tile_size + offset_x, 0, gz * tile_size + offset_z)
	
	# Kaotik Rotasyon
	spike.rotation.y = rng.randf_range(0, TAU)
	spike.rotation.x = rng.randf_range(-0.3, 0.3)
	spike.rotation.z = rng.randf_range(-0.3, 0.3)
	
	# Kaotik Ölçek
	var base_scale = rng.randf_range(2.0, 5.0)
	var height_mult = rng.randf_range(3.0, 8.0)
	spike.scale = Vector3(base_scale, base_scale * height_mult, base_scale)
	
	active_chunks[coord].append(spike)

func _unload_chunk_internal(coord: Vector2i):
	# GridMap zeminini sil
	for x in range(chunk_size):
		for z in range(chunk_size):
			var gx = (coord.x * chunk_size) + x
			var gz = (coord.y * chunk_size) + z
			grid_map.set_cell_item(Vector3i(gx, 0, gz), -1)
	
	# Dikitleri sil
	if active_chunks.has(coord):
		for s in active_chunks[coord]:
			if is_instance_valid(s):
				s.queue_free()
