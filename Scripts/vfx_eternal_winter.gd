extends MeshInstance3D
class_name VFXEternalWinter

var target_radius: float = 8.0 # Varsayılan yarıçap

func _ready():
	if not mesh:
		mesh = PlaneMesh.new()
		mesh.size = Vector2(1.0, 1.0)
	
	# Başlangıç animasyonu (Büyüme)
	scale = Vector3.ZERO
	_update_visuals()

func set_radius(val: float):
	target_radius = val
	_update_visuals()

func _update_visuals():
	# Çap = Yarıçap * 2
	var diameter = target_radius * 2.0
	
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3(diameter, 1.0, diameter), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
