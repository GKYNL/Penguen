extends Node3D

@export_group("Wave Settings")
@export var enemy_scene: PackedScene
@export var base_spawn_interval: float = 3.0
@export var min_spawn_interval: float = 0.15 # Max güçte mermi gibi spawn
@export var spawn_radius: float = 28.0
@export var is_active: bool = false

@export_group("Difficulty")
@export var max_enemy_cap: int = 350 # Kaosu hissetmek için sınırı yukarı çektik

var player = null
var current_stage: int = 1
var scouter_power_level: float = 0.0

@onready var spawn_timer: Timer = Timer.new()
@onready var analysis_timer: Timer = Timer.new()

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	# Spawn Timer
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	# Scouter Analysis Timer (Saniyede 2 kez analiz yeterli)
	add_child(analysis_timer)
	analysis_timer.wait_time = 0.5
	analysis_timer.timeout.connect(_scouter_analysis)
	
	if not AugmentManager.is_connected("mechanic_unlocked", _start_horde):
		AugmentManager.mechanic_unlocked.connect(_start_horde)

func _start_horde(_id):
	if is_active: return
	is_active = true
	spawn_timer.start(base_spawn_interval)
	analysis_timer.start()
	_spawn_batch(5) # Başlangıçta ufak bir karşılama komitesi

# --- DRAGON BALL SCOUTER GÜÇ ANALİZİ ---
func _scouter_analysis():
	if not is_active: return
	
	# 1. GERÇEK GÜÇ HESABI (Her şey birbiriyle çarpılıyor)
	scouter_power_level = _calculate_over_9000()
	
	# 2. ADAPTİF ZORLUK (Stage Artışı)
	# Düşman canı (Stage) senin gücüne yetişemiyorsa stage'i fırlat
	var target_stage = int(scouter_power_level / 120.0) + 1
	if target_stage > current_stage:
		current_stage = target_stage
		if OS.is_debug_build():
			print("[SCOUTER] Power Level: %.2f | Stage Up: %d" % [scouter_power_level, current_stage])

	# 3. SPAWN HIZI (Logaritmik Ölçeklendirme)
	var speed_factor = clamp(scouter_power_level / 1500.0, 0.0, 1.0)
	spawn_timer.wait_time = lerp(base_spawn_interval, min_spawn_interval, speed_factor)

func _calculate_over_9000() -> float:
	var stats = AugmentManager.player_stats
	var base_p = 10.0 # Temel varlık puanı
	
	# A) Aktif Silah ve JSON Verileri
	if AugmentManager.active_weapon_id != "":
		var lv = AugmentManager.mechanic_levels.get(AugmentManager.active_weapon_id, 1)
		var w_data = _find_augment_data(AugmentManager.active_weapon_id, lv)
		if w_data:
			var d = float(w_data.get("damage", 10.0))
			var fr = float(w_data.get("fire_rate", 1.0))
			var c = float(w_data.get("count", 1.0))
			# Hasar * Ateş Hızı * Mermi Sayısı * Stat Çarpanları
			base_p += (d * fr * c) * stats.get("damage_mult", 1.0) * stats.get("attack_speed", 1.0)

	# B) Augment Sinerjisi (Her Augment bir çarpan ekler)
	var synergy_mult = 1.0
	for m_id in AugmentManager.mechanic_levels:
		var lv = AugmentManager.mechanic_levels[m_id]
		# Her bir mekanik seviyesi genel gücü %20 artırır (Üstel büyüme hissi)
		synergy_mult *= (1.0 + (lv * 0.2))
		
		# Özel Güç Sıçramaları (Gold Kartlar)
		if m_id == "gold_4": synergy_mult *= 1.3 # Chain Reaction
		if m_id == "gold_1": synergy_mult *= 1.25 # Thunderlord
		if m_id == "gold_2": synergy_mult *= 1.15 # Frost Armor

	# C) Kritik ve Multishot (Şansı güce çevir)
	var crit_bonus = 1.0 + (stats.get("crit_chance", 0.0) * (stats.get("crit_damage", 1.5) - 1.0))
	var ms_bonus = 1.0 + (stats.get("multishot_chance", 0.0) * 2.0)
	
	return base_p * synergy_mult * crit_bonus * ms_bonus

func _find_augment_data(id: String, level: int):
	var pools = [AugmentManager.tier_1_pool, AugmentManager.tier_2_pool, AugmentManager.tier_3_pool]
	for pool in pools:
		for aug in pool:
			if aug.id == id:
				var idx = clamp(level - 1, 0, aug.levels.size() - 1)
				return aug.levels[idx]
	return null

func _on_spawn_timer_timeout():
	if not is_active or not player: return
	
	var enemies_in_scene = get_tree().get_nodes_in_group("Enemies").size()
	if enemies_in_scene >= max_enemy_cap: return

	# BATCH SIZE (Gerçek lejyon mantığı)
	# Güç seviyen arttıkça tek seferde doğan düşman sayısı 15'e kadar çıkar
	var batch_size = 1
	if scouter_power_level > 100:
		batch_size = clamp(int(scouter_power_level / 75.0), 1, 15)
	
	_spawn_batch(batch_size)

func _spawn_batch(amount: int):
	for i in range(amount):
		var angle = randf() * TAU
		# Düşmanlar üst üste binmesin diye ufak bir halka sapması
		var dist = spawn_radius + randf_range(-4.0, 4.0)
		var offset = Vector3(cos(angle), 0, sin(angle)) * dist
		
		var enemy = enemy_scene.instantiate()
		get_tree().root.add_child(enemy)
		enemy.global_position = player.global_position + offset
		enemy.stage = current_stage
		
		# Düşman tipini belirle
		var power_ratio = scouter_power_level / (25.0 * current_stage)
		if power_ratio > 4.0 and randf() < 0.25:
			enemy.make_elite()
		elif power_ratio > 2.5 and randf() < 0.2:
			enemy.make_archer()
