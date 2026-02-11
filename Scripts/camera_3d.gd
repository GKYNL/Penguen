extends Camera3D

# --- SETTINGS ---
@export var target_node_path: NodePath
@export var camera_offset: Vector3 = Vector3(0, 18, 15)
@export var follow_speed: float = 10.0 # Sabit takipte daha hızlı olması iyidir

@export_group("Dynamic Effects")
@export var base_fov: float = 75.0

# --- YENİ EKLENEN: TRAUMA AYARLARI ---
@export_group("Trauma Shake")
@export var trauma_decay: float = 0.8  # Travmanın sönme hızı
@export var max_offset: Vector2 = Vector2(1.0, 1.0) # Sağa/Sola ve Yukarı/Aşağı max kayma
@export var max_roll: float = 0.1 # Z ekseninde dönme açısı
@export var noise_speed: float = 4.0 # Titreşim hızı

var target: Node3D = null

# --- YENİ EKLENEN: TRAUMA DEĞİŞKENLERİ ---
var trauma: float = 0.0
var trauma_power: int = 2 # Sarsıntı şiddet üssü (2 veya 3 ideal)
var noise: FastNoiseLite
var noise_y: float = 0.0

func _ready():
	if target_node_path:
		target = get_node(target_node_path)
	else:
		target = get_tree().get_first_node_in_group("player")
	
	# --- YENİ EKLENEN: NOISE OLUŞTURMA ---
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 2.0
	
	if not target:
		return
		
	top_level = true 
	
	# Başlangıçta kamerayı hedefe göre konumlandır ve BİR KEZ bak
	global_position = target.global_position + camera_offset
	look_at(target.global_position, Vector3.UP)
	
	fov = base_fov

func _physics_process(delta):
	# --- YENİ EKLENEN: SARSINTI MANTIĞI ---
	if trauma > 0:
		trauma = max(trauma - trauma_decay * delta, 0.0)
		_apply_shake(delta)
	else:
		# Sarsıntı bittiğinde ofsetleri yumuşakça sıfırla
		if h_offset != 0 or v_offset != 0 or rotation.z != 0:
			h_offset = lerpf(h_offset, 0.0, delta * 5.0)
			v_offset = lerpf(v_offset, 0.0, delta * 5.0)
			rotation.z = lerpf(rotation.z, 0.0, delta * 5.0)
	# --------------------------------------

	if not target: return
	
	# Sadece pozisyon takibi yapıyoruz
	# Rotasyon (Quaternion veya Euler) asla değişmiyor
	var target_pos = target.global_position + camera_offset
	
	# Yumuşak takip (Lerp), istersen bunu direkt global_position = target_pos da yapabilirsin
	global_position = global_position.lerp(target_pos, delta * follow_speed)

# --- YENİ EKLENEN FONKSİYONLAR ---
func add_trauma(amount: float):
	trauma = min(trauma + amount, 1.0)

func _apply_shake(delta):
	# Trauma'nın karesini alarak şiddeti ayarla (Küçük darbeler az, büyükler çok hissettirir)
	var amount = pow(trauma, trauma_power)
	
	noise_y += noise_speed * delta
	
	# Kamera'nın dahili offset özelliklerini kullanıyoruz (Pozisyonu bozmaz)
	h_offset = max_offset.x * amount * noise.get_noise_2d(noise.seed, noise_y)
	v_offset = max_offset.y * amount * noise.get_noise_2d(noise.seed + 1, noise_y)
	rotation.z = max_roll * amount * noise.get_noise_2d(noise.seed + 2, noise_y)
