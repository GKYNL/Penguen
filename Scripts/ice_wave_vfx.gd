extends Area3D

@export var max_radius: float = 10.0
@export var expansion_speed: float = 12.0 
@export var freeze_duration: float = 4.0 

func _ready():
	scale = Vector3.ZERO 
	body_entered.connect(_on_body_entered)

	
	# MATERYALİ UNIQUE YAP:
	# Bu satır, bu VFX'in materyalini diğerlerinden ayırır.
	# Böylece birinin alpha'sı azalınca diğerleri etkilenmez.
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh:
		var mat = mesh.get_active_material(0)
		if mat:
			mesh.set_surface_override_material(0, mat.duplicate())
func _physics_process(delta):
	scale += Vector3.ONE * expansion_speed * delta
	
	if scale.x >= max_radius:
		fade_out()

func _on_body_entered(body):
	var enemy_node = find_enemy_parent(body)
	
	if enemy_node:
		print("Düşman tespit edildi: ", enemy_node.name)
		if enemy_node.has_method("apply_freeze"):
			enemy_node.apply_freeze(freeze_duration)
			print("Dondurma uygulandı!")
	else:
		print("Temas edilen objede veya üstünde 'Enemies' grubu yok: ", body.name)

func find_enemy_parent(node):
	if node == null:
		return null
	if node.is_in_group("Enemies"):
		return node
	return find_enemy_parent(node.get_parent())

func fade_out():
	var mesh = get_node_or_null("MeshInstance3D")
	if not mesh: 
		queue_free()
		return
		
	var mat = mesh.get_surface_override_material(0)
	
	if mat is StandardMaterial3D:
		# Her ihtimale karşı alpha'yı 1.0'dan başlatalım (Görünür yapalım)
		mat.albedo_color.a = 1.0
		
		var tween = create_tween()
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
	else:
		# Eğer materyal yoksa veya tip uyumsuzsa direkt sil
		queue_free()
