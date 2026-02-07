extends MeshInstance3D
class_name VFXBlackHole

# --- AYARLAR ---
var target_radius: float = 10.0      # Görsel Yarıçap (JSON'dan gelir)
var damage_amount: float = 0.0       # Hasar (JSON'dan gelir)
var duration: float = 6.0            # Sahnede kalma süresi

# Fizik Ayarları
var pull_radius_mult: float = 2.0    # Görselden ne kadar uzaktan çekmeye başlasın? (2.5 katı)
var pull_strength: float = 15.0      # Çekim hızı (Daha güçlü yaptık)
var kill_radius: float = 3.0         # Merkeze ne kadar yaklaşınca hasar yesin? (Tam orta)
var damage_interval: float = 0.2     # Merkezdekilere ne sıklıkla vursun? (Saniyede 5 kere)

var _time_alive: float = 0.0
var _damage_timer: float = 0.0

func _ready():
	# Görsel Kurulum
	if not mesh:
		mesh = PlaneMesh.new()
		mesh.size = Vector2(1.0, 1.0)
	
	_setup_material()
	position.y += 0.2 # Z-Fighting önlemi
	
	# --- ANİMASYON: BÜYÜME ---
	scale = Vector3.ZERO
	# JSON'daki yarıçap görsel boyuttur
	var target_diameter = target_radius * 2.0 
	
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3(target_diameter, 1.0, target_diameter), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float):
	_time_alive += delta
	
	# 1. Ömür Kontrolü
	if _time_alive >= duration:
		_start_collapse()
		set_physics_process(false)
		return

	# 2. Çekim ve Hasar (Aynı döngüde halledelim, performanslı olsun)
	_handle_gravity_and_damage(delta)

func _handle_gravity_and_damage(delta: float):
	# Çekim alanı görselin 2.5 katı
	# Not: scale.x bizim çapımız. Yarıçap = scale.x / 2.0
	var visual_radius = scale.x / 2.0
	var gravity_zone = visual_radius * pull_radius_mult
	
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var hit_count = 0
	
	# Hasar zamanı geldi mi?
	var can_damage = false
	if damage_amount > 0:
		_damage_timer -= delta
		if _damage_timer <= 0.0:
			_damage_timer = damage_interval
			can_damage = true
	
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		
		var dist = global_position.distance_to(enemy.global_position)
		
		# --- 1. ÇEKİM (Dışarıdaysa içeri çek) ---
		if dist <= gravity_zone:
			# Eğer merkezde değilse çek
			if dist > 0.5:
				var direction = (global_position - enemy.global_position).normalized()
				
				# Merkeze yaklaştıkça çekim gücü artsın (Daha gerçekçi)
				var distance_factor = 1.0 - (dist / gravity_zone) # 0 (uzak) -> 1 (yakın)
				var current_pull = pull_strength * (1.0 + distance_factor * 2.0)
				
				# Enemy hareketini manipüle et
				if "velocity" in enemy:
					# Mevcut hızını iptal edip merkeze yönlendir
					enemy.velocity = enemy.velocity.lerp(direction * current_pull, delta * 8.0)
					if not enemy.has_method("move_and_slide"):
						enemy.global_position += direction * current_pull * delta
				else:
					enemy.global_position = enemy.global_position.lerp(global_position, delta * 3.0)
		
		# --- 2. HASAR (Sadece TAM ORTADAYSA) ---
		if can_damage and dist <= kill_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage_amount)
				hit_count += 1

	if hit_count > 0:
		print("⚫ [Black Hole] Merkezde %d düşman öğütülüyor! (Hasar: %.1f)" % [hit_count, damage_amount])

# --- GÖRSEL KURULUM (Aynı) ---
func _setup_material():
	if not material_override:
		var mat = ShaderMaterial.new()
		var shader_path = "res://shaders/black_hole.gdshader" 
		if ResourceLoader.exists(shader_path):
			mat.shader = load(shader_path)
			mat.set_shader_parameter("edge_color", Color(0.0, 0.418, 0.814, 1.0))
			mat.set_shader_parameter("core_color", Color.BLACK)
			
			var noise = FastNoiseLite.new()
			noise.noise_type = FastNoiseLite.TYPE_PERLIN
			noise.frequency = 0.05
			var noise_tex = NoiseTexture2D.new()
			noise_tex.noise = noise
			mat.set_shader_parameter("swirl_noise", noise_tex)
		else:
			queue_free()
			return
		material_override = mat

# --- KAPANIŞ ---
func _start_collapse():
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.2).set_ease(Tween.EASE_IN)
	tw.finished.connect(queue_free)

# --- LEVEL VERİSİ ---
func setup_from_level(level_data: Dictionary):
	if level_data.has("radius"):
		target_radius = float(level_data["radius"])
	
	if level_data.has("damage"):
		damage_amount = float(level_data["damage"])
		# Hasar vuruyorsa renk kızarır
		if damage_amount > 0:
			var mat = material_override as ShaderMaterial
			if mat: mat.set_shader_parameter("edge_color", Color(0.557, 0.0, 0.651, 1.0))
