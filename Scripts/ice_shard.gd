extends Area3D

@export var speed: float = 45.0
var damage: float = 5.0
var pierce: int = 1
var hit_count: int = 0
var is_exploding: bool = false

func _ready():
	# ESKİ KOD (SİLİNDİ): get_tree().create_timer(2.0).timeout.connect(queue_free)
	
	# YENİ KOD: Timer Node Kullanımı
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)

func _physics_process(delta):
	if is_exploding: return
	global_position += -global_transform.basis.z * speed * delta

func _on_body_entered(body):
	if body.is_in_group("player") or is_exploding: return
	
	var enemy = _find_enemy(body)
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(damage * AugmentManager.player_stats["damage_mult"])
		hit_count += 1
		if hit_count >= pierce:
			explode()
	elif not body.is_in_group("player"):
		explode()

func _find_enemy(node):
	if node == null or node.is_in_group("Enemies"): return node
	return _find_enemy(node.get_parent())

func explode():
	is_exploding = true
	queue_free()
