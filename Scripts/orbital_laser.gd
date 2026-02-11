extends Node3D

enum State { SPAWNING, FIRING, RETURNING }
var current_state = State.SPAWNING

# --- STATS ---
var damage: float = 150.0
var beam_duration: float = 0.8
var beam_width: float = 2.0  
var beam_length: float = 40.0 

var state_timer: float = 0.0
var enemies_hit: Array = []
var locked_transform: Transform3D

# Referanslar
var mesh: MeshInstance3D
var area: Area3D
var shape_node: CollisionShape3D
var pivot: Node3D

func _ready():
	visible = false
	# Parçaları bul veya oluştur
	_ensure_components_exist()
	# Mesh'i oluştur
	_create_beam_mesh()

func on_spawn():
	visible = false
	enemies_hit.clear()
	_update_stats()
	
	# Parçalar hazır mı tekrar kontrol et
	_ensure_components_exist()
	
	_try_fire()

func _ensure_components_exist():
	# 1. PIVOT
	pivot = get_node_or_null("BeamPivot")
	if not pivot:
		pivot = Node3D.new()
		pivot.name = "BeamPivot"
		add_child(pivot)
	
	# 2. MESH
	mesh = pivot.get_node_or_null("MeshInstance3D")
	if not mesh:
		mesh = MeshInstance3D.new()
		mesh.name = "MeshInstance3D"
		pivot.add_child(mesh)
	
	# 3. AREA
	area = pivot.get_node_or_null("Area3D")
	if not area:
		area = Area3D.new()
		area.name = "Area3D"
		pivot.add_child(area)
		
	# 4. COLLISION
	shape_node = area.get_node_or_null("CollisionShape3D")
	if not shape_node:
		shape_node = CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		area.add_child(shape_node)

func _update_stats():
	var lvl = AugmentManager.mechanic_levels.get("prism_1", 1)
	if AugmentManager.tier_3_pool:
		for card in AugmentManager.tier_3_pool:
			if card.id == "prism_1":
				var idx = clamp(lvl - 1, 0, card["levels"].size() - 1)
				var data = card["levels"][idx]
				damage = float(data.get("damage", 150.0))
				beam_duration = float(data.get("duration", 0.8))
				break

func _try_fire():
	var target = _find_nearest_enemy()
	if target:
		_start_firing(target)
	else:
		VFXPoolManager.return_to_pool(self, "orbital_laser")

func _start_firing(target):
	current_state = State.FIRING
	state_timer = beam_duration
	
	var aim_pos = target.global_position
	aim_pos.y = global_position.y 
	
	look_at(aim_pos, Vector3.UP)
	locked_transform = global_transform
	
	visible = true
	if area: area.monitoring = true
	
	if mesh:
		mesh.scale.x = 0.0
		mesh.scale.z = 0.0
		var tw = create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tw.tween_property(mesh, "scale:x", beam_width, 0.2)
		tw.parallel().tween_property(mesh, "scale:z", beam_width, 0.2)
	
	await get_tree().process_frame
	_apply_instant_damage()

func _process(delta):
	if current_state == State.FIRING:
		global_transform = locked_transform
		state_timer -= delta
		if state_timer <= 0:
			_stop_firing()

func _stop_firing():
	if area: area.monitoring = false
	current_state = State.RETURNING
	
	if mesh:
		var tw = create_tween()
		tw.tween_property(mesh, "scale:x", 0.0, 0.15)
		tw.parallel().tween_property(mesh, "scale:z", 0.0, 0.15)
		await tw.finished
	
	VFXPoolManager.return_to_pool(self, "orbital_laser")

func _apply_instant_damage():
	if area and area.monitoring:
		for body in area.get_overlapping_bodies():
			_hit_enemy(body)
			
	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if current_state == State.FIRING:
		_hit_enemy(body)

func _hit_enemy(body):
	if body.is_in_group("Enemies") and not body in enemies_hit:
		if body.has_method("take_damage"):
			body.take_damage(damage)
			enemies_hit.append(body)
			if AugmentManager.mechanic_levels.has("gold_4"):
				VFXPoolManager.spawn_vfx("explosion", body.global_position)

func _find_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("Enemies")
	if enemies.is_empty(): return null
	var nearest = null
	var min_dist = 99999.0
	for e in enemies:
		if is_instance_valid(e):
			var my_flat = Vector3(global_position.x, 0, global_position.z)
			var e_flat = Vector3(e.global_position.x, 0, e.global_position.z)
			var d = my_flat.distance_to(e_flat)
			if d < min_dist:
				min_dist = d
				nearest = e
	return nearest

func _create_beam_mesh():
	if not mesh: return
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.8, 0.2) # Altın sarısı
	mat.emission_enabled = true
	mat.emission = Color(1, 0.5, 0)
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	st.set_material(mat)
	
	var segments = 16 
	var radius = 0.5 
	
	for i in range(segments):
		var angle1 = i * TAU / segments
		var angle2 = (i + 1) * TAU / segments
		var p1_b = Vector3(cos(angle1) * radius, -0.5, sin(angle1) * radius)
		var p2_b = Vector3(cos(angle2) * radius, -0.5, sin(angle2) * radius)
		var p1_t = Vector3(cos(angle1) * radius, 0.5, sin(angle1) * radius)
		var p2_t = Vector3(cos(angle2) * radius, 0.5, sin(angle2) * radius)
		var n1 = Vector3(cos(angle1), 0, sin(angle1))
		var n2 = Vector3(cos(angle2), 0, sin(angle2))
		var u1 = float(i) / segments
		var u2 = float(i + 1) / segments
		
		st.set_normal(n1); st.set_uv(Vector2(u1, 0)); st.add_vertex(p1_b)
		st.set_normal(n2); st.set_uv(Vector2(u2, 0)); st.add_vertex(p2_b)
		st.set_normal(n1); st.set_uv(Vector2(u1, 1)); st.add_vertex(p1_t)
		st.set_normal(n2); st.set_uv(Vector2(u2, 0)); st.add_vertex(p2_b)
		st.set_normal(n2); st.set_uv(Vector2(u2, 1)); st.add_vertex(p2_t)
		st.set_normal(n1); st.set_uv(Vector2(u1, 1)); st.add_vertex(p1_t)
		
	mesh.mesh = st.commit()
	
	# Ayarlamalar
	mesh.rotation_degrees = Vector3(90, 0, 0)
	mesh.position = Vector3(0, 0, -beam_length / 2.7) 
	mesh.scale = Vector3(0, beam_length, 0)
	
	# Collision Shape ayarı
	if shape_node:
		var new_shape = CylinderShape3D.new()
		new_shape.height = beam_length
		new_shape.radius = beam_width / 2.0 
		shape_node.shape = new_shape
		shape_node.rotation_degrees = Vector3(90, 0, 0)
		
	if area:
		area.position = Vector3(0, 0, -beam_length / 2.0)
