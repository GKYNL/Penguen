extends Area3D

@export var follow_speed: float = 6.0
@export var acceleration: float = 1.0 
@export var min_distance: float = 0.6 

var xp_value: int = 50 
var target_node: Node3D = null

@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready():
	# OPTİMİZASYON: Başlangıçta fizik işlemini kapatıyoruz.
	# Böylece oyuncu yanına gelene kadar bu script işlemciyi HİÇ yormaz.
	set_physics_process(false)

	# STAT BAĞLANTISI: Pickup Range
	if collision_shape.shape is SphereShape3D:
		var current_range = AugmentManager.player_stats.get("pickup_range", 10.0)
		collision_shape.shape.radius = current_range
	
	_setup_glow()
	body_entered.connect(_on_body_entered)

func _setup_glow():
	var mat = mesh_instance_3d.get_active_material(0)
	if mat is StandardMaterial3D:
		var new_mat = mat.duplicate()
		var glow_power = 3.0
		new_mat.albedo_color = new_mat.albedo_color * glow_power
		new_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance_3d.material_override = new_mat

func _physics_process(delta):
	# Buraya sadece oyuncu menzile girince geliyoruz, o yüzden target_node kesin var.
	if not target_node: return

	# Oyuncunun merkezine doğru akış
	var target_center = target_node.global_position + Vector3(0, 1.0, 0)
	var direction = (target_center - global_position).normalized()
	
	follow_speed += acceleration
	global_position += direction * follow_speed * delta
	
	if global_position.distance_to(target_center) < min_distance:
		collect()

func _on_body_entered(body):
	if body.is_in_group("player"):
		target_node = body
		# OPTİMİZASYON: Oyuncu menzile girdi, küreyi uyandır!
		set_physics_process(true)

func collect():
	AugmentManager.add_xp(xp_value)
	queue_free()
