extends Node3D

# --- AYARLAR ---
var damage_per_tick: float = 0.0
var cone_angle: float = 45.0 
var range_dist: float = 7.0 # Menzil biraz uzun olsun
var duration: float = 2.5
var tick_rate: float = 0.2 # Saniyede 5 vuruş

var active_timer: float = 0.0
var tick_timer: float = 0.0
var is_active: bool = false

# Node Referansları
@onready var particles: GPUParticles3D = $"."

func _ready():
	# Başlangıçta kapalı olsun
	if particles: particles.emitting = false
	set_process(false) # İşlemciyi yorma

# --- POOL BAŞLATMA ---
func start_breath(stats: Dictionary):
	damage_per_tick = stats.get("damage", 60.0) * tick_rate
	cone_angle = stats.get("angle", 45.0)
	duration = stats.get("duration", 2.5)
	
	# PARTİKÜL AÇISINI GÜNCELLE
	if particles and particles.process_material:
		# Spread, koninin yarıçap açısıdır. O yüzden 2'ye bölüyoruz.
		particles.process_material.spread = cone_angle / 1.5 
	
	active_timer = duration
	tick_timer = 0.0
	is_active = true
	
	if particles:
		particles.restart()
		particles.emitting = true
	
	
	set_process(true)

func _process(delta):
	# Oyuncu ile beraber dönmesi için (Eğer Local Coords: False yaptıysan)
	# Partiküllerin emitter'ı takip etmesi gerekmez, sadece spawn noktası önemlidir.
	
	# 1. Süre Kontrolü
	active_timer -= delta
	if active_timer <= 0:
		_stop_breath()
		return
		
	# 2. Hasar Döngüsü
	tick_timer -= delta
	if tick_timer <= 0:
		tick_timer = tick_rate
		_apply_cone_damage()

func _apply_cone_damage():
	var enemies = get_tree().get_nodes_in_group("Enemies")
	# Emitter'ın (oyuncunun) baktığı yön (-Z)
	var forward = -global_transform.basis.z.normalized()
	var my_pos = global_position
	
	# Cosinus hesabı (Açı kontrolü için)
	var cone_dot_threshold = cos(deg_to_rad(cone_angle / 2.0))
	
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		
		# 1. Mesafe Kontrolü
		var dist = my_pos.distance_to(enemy.global_position)
		if dist > range_dist: continue
		
		# 2. Açı Kontrolü (Dot Product)
		var dir_to_enemy = (enemy.global_position - my_pos).normalized()
		var dot = forward.dot(dir_to_enemy)
		
		# Eğer düşman koninin içindeyse
		if dot > cone_dot_threshold:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage_per_tick)
				# İstersen düşmanı biraz da itebilirsin (Knockback)
				if "velocity" in enemy:
					enemy.velocity += dir_to_enemy * 2.0

func _stop_breath():
	is_active = false
	if particles: particles.emitting = false
	
	set_process(false)
	
	# Partiküllerin sönmesini bekle ve havuza dön
	await get_tree().create_timer(1.5).timeout
	VFXPoolManager.return_to_pool(self, "dragon_breath")
