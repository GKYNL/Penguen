extends Camera3D

# --- SETTINGS ---
@export var target_node_path: NodePath
@export var camera_offset: Vector3 = Vector3(0, 18, 15)
@export var follow_speed: float = 10.0 # Sabit takipte daha hızlı olması iyidir

@export_group("Dynamic Effects")
@export var base_fov: float = 75.0

var target: Node3D = null

func _ready():
	if target_node_path:
		target = get_node(target_node_path)
	else:
		target = get_tree().get_first_node_in_group("player")
	
	if not target:
		return
		
	top_level = true 
	
	# Başlangıçta kamerayı hedefe göre konumlandır ve BİR KEZ bak
	global_position = target.global_position + camera_offset
	look_at(target.global_position, Vector3.UP)
	
	fov = base_fov

func _physics_process(delta):
	if not target: return
	
	# Sadece pozisyon takibi yapıyoruz
	# Rotasyon (Quaternion veya Euler) asla değişmiyor
	var target_pos = target.global_position + camera_offset
	
	# Yumuşak takip (Lerp), istersen bunu direkt global_position = target_pos da yapabilirsin
	global_position = global_position.lerp(target_pos, delta * follow_speed)
