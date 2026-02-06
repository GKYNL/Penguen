extends Area3D

@export var speed: float = 25.0 # Daha yavaş
var damage: float = 10.0 # WeaponManager'dan gelir
var pierce: int = 1      # Genelde 1 kalır
var is_exploding: bool = false

@onready var csg_sphere: CSGSphere3D = $CSGSphere3D

func _ready():
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _physics_process(delta):
	if is_exploding: return
	global_position += -global_transform.basis.z * speed * delta

func _on_body_entered(body):
	if body.is_in_group("player") or is_exploding: return
	
	var enemy = _find_enemy(body)
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(damage * AugmentManager.player_stats["damage_mult"])
		explode()
	elif not body.is_in_group("player"):
		explode()

func _find_enemy(node):
	if node == null or node.is_in_group("Enemies"): return node
	return _find_enemy(node.get_parent())

func explode():
	is_exploding = true
	# Patlama VFX buraya...
	queue_free()
