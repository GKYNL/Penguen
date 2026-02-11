extends Node3D

# --- REFERANSLAR ---
@onready var trail_particles: GPUParticles3D = get_node_or_null("TrailParticles")
@onready var sonic_mesh: MeshInstance3D = get_node_or_null("SonicBoomMesh")

var is_active: bool = false

func _ready():
	if trail_particles: trail_particles.emitting = false
	if sonic_mesh: sonic_mesh.visible = false

# --- POOL YÖNETİMİ ---
func activate_effect():
	is_active = true
	visible = true

func deactivate_effect():
	is_active = false
	visible = false
	if trail_particles: trail_particles.emitting = false
	
	if get_parent():
		reparent(get_tree().root)
	VFXPoolManager.return_to_pool(self, "godspeed")

# --- GÜVENLİK GÜNCELLEMESİ ---
func update_effect(input_dir: Vector2, speed_ratio: float, has_damage: bool):
	if not is_active: return
	
	# 1. TRAIL YÖNETİMİ
	if trail_particles:
		if speed_ratio > 0.1:
			if not trail_particles.emitting: trail_particles.emitting = true
		else:
			if trail_particles.emitting: trail_particles.emitting = false

	# 2. SONIC BOOM
	if sonic_mesh:
		var show_boom = has_damage and speed_ratio > 0.8
		sonic_mesh.visible = show_boom
		
		if show_boom:
			# --- CRASH FİX: GÜVENLİ LOOK_AT ---
			# Input vektörü yeterince büyükse dön, yoksa olduğun gibi kal.
			if input_dir.length_squared() > 0.01:
				var target_pos = global_position + Vector3(input_dir.x, 0, input_dir.y)
				
				# Hedef ile aramızdaki mesafe güvenli mi?
				if global_position.distance_squared_to(target_pos) > 0.001:
					look_at(target_pos, Vector3.UP)
