extends Node3D

@export_group("Wave Settings")
@export var enemy_scene: PackedScene
@export var base_spawn_interval: float = 2.0
@export var min_spawn_interval: float = 0.05 # Makinalı tüfek gibi spawn
@export var spawn_radius: float = 28.0
@export var is_active: bool = false

@export_group("Difficulty")
@export var max_enemy_cap: int = 500 
@export var difficulty_scaling: float = 1.2

var player = null
var current_stage: int = 1
var director_anger: float = 1.0 # AI sinir katsayısı
var active_enemy_count: int = 0

@onready var spawn_timer: Timer = Timer.new()
@onready var brain_timer: Timer = Timer.new() # Yapay zeka döngüsü

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	# Timer Kurulumları
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_tick)
	
	add_child(brain_timer)
	brain_timer.wait_time = 0.5 # Yarım saniyede bir analiz
	brain_timer.timeout.connect(_ai_director_think)
	
	# KRİTİK DÜZELTME: Sinyali tek bir yönetici fonksiyona bağlıyoruz
	if not AugmentManager.is_connected("mechanic_unlocked", _on_mechanic_unlocked_wrapper):
		AugmentManager.mechanic_unlocked.connect(_on_mechanic_unlocked_wrapper)

# Bu fonksiyon hem oyunu başlatır hem de gücü günceller
func _on_mechanic_unlocked_wrapper(id):
	# 1. Eğer oyun aktif değilse BAŞLAT (Kontağı çevir)
	if not is_active:
		_start_horde(id)
	
	# 2. Yeni kart alındığı için gücü hemen hesapla
	_ai_director_think()

func _start_horde(_id):
	if is_active: return
	is_active = true
	spawn_timer.start(base_spawn_interval)
	brain_timer.start()
	_spawn_formation("circle", 8) # Isınma turu
	if OS.is_debug_build(): print("🔥 Horde Started! Director Active.")

# --- YAPAY ZEKA YÖNETMENİ (AI DIRECTOR) ---
func _ai_director_think():
	if not is_active or not player: return
	
	# A. SAHAYI OKU
	active_enemy_count = get_tree().get_nodes_in_group("Enemies").size()
	var current_player_dps = _calculate_real_time_dps()
	
	# B. İDEAL DÜŞMAN SAYISI HESABI
	# Senin gücün arttıkça oyunun "normal" kabul ettiği düşman sayısı artar.
	# Örn: DPS 100 ise 20 düşman, DPS 1000 ise 200 düşman normaldir.
	var ideal_enemy_count = clamp(int(current_player_dps / 40.0), 15, max_enemy_cap)
	
	# C. KARAR MEKANİZMASI
	
	# Durum 1: "Bu adam çok rahat" (Ekranda az düşman var)
	if active_enemy_count < (ideal_enemy_count * 0.4): # %40'ın altındaysa
		director_anger += 0.5 # Sinirlen
		var missing_count = ideal_enemy_count - active_enemy_count
		_force_emergency_wave(missing_count) # ACİL DURUM DALGASI!
		
	# Durum 2: "Harita doldu" (Sınıra dayandı)
	elif active_enemy_count > (max_enemy_cap * 0.9):
		director_anger = max(1.0, director_anger - 0.2) # Sakinleş
	
	# D. ZORLUK VE HIZ AYARI
	# Director sinirliyse stage (can/hasar) artar ve spawn hızlanır
	var speed_mult = clamp(director_anger / 10.0, 0.0, 0.9)
	spawn_timer.wait_time = lerp(base_spawn_interval, min_spawn_interval, speed_mult)
	
	# Stage artık senin gücüne ve AI'ın sinirine bağlı
	current_stage = int(current_player_dps / 200.0) + int(director_anger)
	if current_stage < 1: current_stage = 1

# --- DETAYLI GÜÇ ANALİZİ ---
func _calculate_real_time_dps() -> float:
	var stats = AugmentManager.player_stats
	var dps = 20.0 # Taban güç
	
	if AugmentManager.active_weapon_id != "":
		var w_id = AugmentManager.active_weapon_id
		var lv = AugmentManager.mechanic_levels.get(w_id, 1)
		var w_data = _find_augment_data(w_id, lv)
		if w_data:
			var d = float(w_data.get("damage", 10))
			var fr = float(w_data.get("fire_rate", 1.0))
			var c = float(w_data.get("count", 1))
			var p = float(w_data.get("pierce", 1)) + 1.0 
			dps += (d * fr * c * p) * 2.0
	
	# Çarpanlar
	dps *= stats.get("damage_mult", 1.0)
	dps *= stats.get("attack_speed", 1.0)
	
	# Kritik ve Cooldown çok büyük güçtür
	var crit_val = 1.0 + (stats.get("crit_chance", 0.0) * (stats.get("crit_damage", 1.5) - 1.0))
	var cdr_val = 1.0 / (1.0 - min(0.9, stats.get("cooldown_reduction", 0.0)))
	
	return dps * crit_val * cdr_val

# --- SPAWN İŞLEMLERİ ---
func _on_spawn_tick():
	if not is_active or active_enemy_count >= max_enemy_cap: return
	
	# Director ne kadar sinirliyse o kadar kalabalık gruplar gelir
	var batch_size = int(max(1.0, director_anger * 2.0))
	
	if randf() < 0.3: # %30 ihtimalle formasyon
		var formations = ["circle", "line", "cluster"]
		_spawn_formation(formations.pick_random(), batch_size)
	else:
		_spawn_batch(batch_size)

func _force_emergency_wave(count: int):
	# Anında haritayı doldurmak için çağrılır
	var wave_size = min(count, 40) # Tek seferde oyunu dondurmasın diye limit
	_spawn_formation("circle", wave_size)
	if OS.is_debug_build(): print("🚨 EMERGENCY WAVE: ", wave_size, " Enemies!")

func _spawn_batch(amount: int):
	for i in range(amount):
		var angle = randf() * TAU
		var dist = spawn_radius + randf_range(-4.0, 4.0)
		var pos = player.global_position + Vector3(cos(angle), 0, sin(angle)) * dist
		_instantiate_enemy(pos)

func _spawn_formation(type: String, count: int):
	var center_angle = randf() * TAU
	var center_pos = player.global_position + Vector3(cos(center_angle), 0, sin(center_angle)) * spawn_radius
	
	for i in range(count):
		var spawn_pos = Vector3.ZERO
		match type:
			"circle": 
				var angle = (TAU / count) * i
				spawn_pos = player.global_position + Vector3(cos(angle), 0, sin(angle)) * (spawn_radius * 0.9)
			"line":
				var dir = center_pos.direction_to(player.global_position).rotated(Vector3.UP, PI/2)
				spawn_pos = center_pos + (dir * i * 2.0)
			"cluster":
				spawn_pos = center_pos + Vector3(randf_range(-5,5), 0, randf_range(-5,5))
		
		_instantiate_enemy(spawn_pos)

func _instantiate_enemy(pos: Vector3):
	var enemy = enemy_scene.instantiate()
	get_tree().root.add_child(enemy)
	enemy.global_position = pos
	
	# Dinamik Güçlendirme (Enemy scriptinde bu değişkenler olmalı)
	enemy.stage = current_stage 
	
	# AI çok sinirliyse düşmanları güçlendir
	if director_anger > 4.0:
		enemy.set("speed_multiplier", 1.4) 
		enemy.set("hp_multiplier", 1.5)
	
	# Elit Şansı
	if randf() < (0.05 * director_anger):
		enemy.make_elite()
	elif randf() < (0.1 * director_anger):
		enemy.make_archer()

# --- YARDIMCI ---
func _find_augment_data(id: String, level: int):
	for pool in [AugmentManager.tier_1_pool, AugmentManager.tier_2_pool, AugmentManager.tier_3_pool]:
		if pool.has("augments"):
			for aug in pool["augments"]:
				if aug.id == id:
					var levels = aug.get("levels", [])
					return levels[clamp(level - 1, 0, levels.size() - 1)]
	return null
