extends Area3D

var speed = 18.0
var damage = 10.0
var direction = Vector3.ZERO

func _ready():
	# 5 saniye sonra mermi silinsin (optimizasyon)
	get_tree().create_timer(5.0).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	global_translate(direction * speed * delta)

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
