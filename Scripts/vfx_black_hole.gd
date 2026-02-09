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
	var visual_radius = scale.x / 2.0
	var gravity_zone = visual_radius * pull_radius_mult
	
	var enemies = get_tree().get_nodes_in_group("Enemies")
	
	# Hasar zamanlayıcısını güncelle
	_damage_timer -= delta
	var can_damage = false
	if _damage_timer <= 0.0:
		_damage_timer = damage_interval
		can_damage = true

	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		
		# Mesafe Hesabı (Yüksekliği görmezden gelmek için Vector2 kullanıyoruz)
		var hole_pos_2d = Vector2(global_position.x, global_position.z)
		var enemy_pos_2d = Vector2(enemy.global_position.x, enemy.global_position.z)
		var dist = hole_pos_2d.distance_to(enemy_pos_2d)
		
		# --- 1. ÇEKİM (Vakum Etkisi) ---
		if dist <= gravity_zone:
			if dist > 0.4: # Tam merkezde titremeyi önlemek için eşik
				var direction = (global_position - enemy.global_position).normalized()
				
				# Merkeze yaklaştıkça artan çekim gücü
				var distance_factor = 1.0 - (dist / gravity_zone)
				var current_pull = pull_strength * (1.0 + distance_factor * 3.0)
				
				if "velocity" in enemy:
					enemy.velocity = enemy.velocity.lerp(direction * current_pull, delta * 8.0)
					if not enemy.has_method("move_and_slide"):
						enemy.global_position += direction * current_pull * delta
				else:
					enemy.global_position = enemy.global_position.lerp(global_position, delta * 4.0)
		
		# --- 2. HASAR ---
		if dist <= kill_radius and can_damage and damage_amount > 0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage_amount)




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
