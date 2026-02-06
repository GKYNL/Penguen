extends Node3D

var is_active = false
var damage_interval = 0.2
var timer = 0.0
var damage = 50.0

@onready var area = $Area3D # Sahneye bir Area3D eklemeyi unutma!

func _ready():
	visible = false
	# Başlangıçta pasif
	set_process(false)
	
	# AugmentManager'a bağlan
	AugmentManager.mechanic_unlocked.connect(_on_mechanic_unlocked)

func _on_mechanic_unlocked(id):
	if id == "prism_1": # Orbital Laser
		activate()

func activate():
	is_active = true
	visible = true
	set_process(true)
	scale = Vector3(1, 1, 1)

func _process(delta):
	if not is_active: return

	# Lazerin dönmesi
	rotate_y(delta * 1.5)
	
	# Hasar vurma (Saniyede 5 kez)
	timer += delta
	if timer >= damage_interval:
		timer = 0.0
		if area:
			for body in area.get_overlapping_bodies():
				if body.is_in_group("Enemies") and body.has_method("take_damage"):
					body.take_damage(damage)
