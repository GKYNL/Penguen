extends Node3D

enum State { IDLE, FIRING, COOLDOWN }
var current_state = State.IDLE

# --- STATS ---
var damage: float = 150.0
var fire_cooldown: float = 5.0
var beam_duration: float = 0.8
var beam_width: float = 2.0  # Lazer kalınlığı (Çap)
var beam_length: float = 40.0 # Lazer uzunluğu

var state_timer: float = 0.0
var is_active: bool = false
var enemies_hit: Array = []
var locked_transform: Transform3D

# Hiyerarşi ne olursa olsun node'ları bul
@onready var mesh: MeshInstance3D = $BeamPivot/MeshInstance3D
@onready var area: Area3D = $BeamPivot/Area3D
@onready var shape_node: CollisionShape3D = $BeamPivot/Area3D/CollisionShape3D
func _ready():
	visible = false
	# LAZERİ GÖVDE HİZASINA KALDIR (Player'ın ayaklarından değil karnından çıksın)
	position = Vector3(0, 1.0, 0)
	
	# Editör ayarlarını çöpe at, matematiksel olarak yeniden yarat
	_create_perfect_beam_assets()
	
	if AugmentManager.has_signal("mechanic_unlocked"):
		AugmentManager.mechanic_unlocked.connect(_on_mechanic_unlocked)
	if AugmentManager.mechanic_levels.has("prism_1"):
		_on_mechanic_unlocked("prism_1")

func _create_perfect_beam_assets():
	# 1. KAPAKSIZ ÖZEL SİLİNDİR OLUŞTUR
	if mesh:
		var stored_material = mesh.material_override
		if stored_material == null and mesh.mesh:
			stored_material = mesh.mesh.surface_get_material(0)
		
		# --- BURASI DEĞİŞTİ: Custom Mesh Oluşturma ---
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		# Eğer materyal varsa ata
		if stored_material:
			st.set_material(stored_material)
		
		# Silindirin yan yüzeylerini oluştur (Kapak yok)
		var segments = 16 # Yuvarlaklık kalitesi
		var height = 1.0 # Baz yükseklik
		var radius = 0.5 # Baz yarıçap
		
		for i in range(segments):
			var angle1 = i * TAU / segments
			var angle2 = (i + 1) * TAU / segments
			
			# Alt çember noktaları (Y = -height/2)
			var p1_b = Vector3(cos(angle1) * radius, -height/2, sin(angle1) * radius)
			var p2_b = Vector3(cos(angle2) * radius, -height/2, sin(angle2) * radius)
			
			# Üst çember noktaları (Y = height/2)
			var p1_t = Vector3(cos(angle1) * radius, height/2, sin(angle1) * radius)
			var p2_t = Vector3(cos(angle2) * radius, height/2, sin(angle2) * radius)
			
			# Normaller (Dışa doğru)
			var n1 = Vector3(cos(angle1), 0, sin(angle1))
			var n2 = Vector3(cos(angle2), 0, sin(angle2))
			
			# UV Koordinatları (Doku kaplama için)
			var u1 = float(i) / segments
			var u2 = float(i + 1) / segments
			
			# İlk Üçgen (p1_b -> p2_b -> p1_t)
			st.set_normal(n1); st.set_uv(Vector2(u1, 0)); st.add_vertex(p1_b)
			st.set_normal(n2); st.set_uv(Vector2(u2, 0)); st.add_vertex(p2_b)
			st.set_normal(n1); st.set_uv(Vector2(u1, 1)); st.add_vertex(p1_t)
			
			# İkinci Üçgen (p2_b -> p2_t -> p1_t)
			st.set_normal(n2); st.set_uv(Vector2(u2, 0)); st.add_vertex(p2_b)
			st.set_normal(n2); st.set_uv(Vector2(u2, 1)); st.add_vertex(p2_t)
			st.set_normal(n1); st.set_uv(Vector2(u1, 1)); st.add_vertex(p1_t)
			
		mesh.mesh = st.commit()
		# ----------------------------------------------
		
		# Mesh'i Z eksenine (İleri) yatır
		mesh.rotation_degrees = Vector3(90, 0, 0)
		mesh.position = Vector3(0, 0, -beam_length / 2.7) # Senin ayarın korundu
		mesh.scale = Vector3(0, beam_length, 0)

	# 2. COLLISION (Aynı kalıyor)
	if area and shape_node:
		area.monitoring = false
		area.position = Vector3(0, 0, -beam_length / 2.0)
		
		var new_shape = CylinderShape3D.new()
		new_shape.height = beam_length
		new_shape.radius = beam_width / 2.0 
		shape_node.shape = new_shape
		shape_node.rotation_degrees = Vector3(90, 0, 0)
		
		if not area.body_entered.is_connected(_on_body_entered):
			area.body_entered.connect(_on_body_entered)

func _on_mechanic_unlocked(id):
	if id == "prism_1":
		_update_stats()
		is_active = true
		current_state = State.COOLDOWN
		state_timer = 2.0 

func _update_stats():
	var lvl = AugmentManager.mechanic_levels.get("prism_1", 1)
	for card in AugmentManager.tier_3_pool:
		if card.id == "prism_1":
			var data = card["levels"][lvl-1]
			damage = data.get("damage", 150.0)
			fire_cooldown = data.get("cooldown", 5.0)
			beam_duration = data.get("duration", 0.8)
			break

func _process(delta):
	if not is_active: return

	match current_state:
		State.COOLDOWN:
			# Pasifken sürekli karakterin gövdesinde durmaya zorla
			if transform.origin.y != 1.0: position.y = 1.0
			state_timer -= delta
			if state_timer <= 0:
				_try_fire()
		
		State.FIRING:
			# Ateş ederken dünyada kilitli kal
			global_transform = locked_transform
			state_timer -= delta
			if state_timer <= 0:
				_stop_firing()

func _try_fire():
	var target = _find_nearest_enemy()
	if target:
		_start_firing(target)
	else:
		state_timer = 0.5 

func _start_firing(target):
	current_state = State.FIRING
	state_timer = beam_duration
	enemies_hit.clear()
	
	# HEDEFLEME: Aşağı/Yukarı bakmayı engelle
	# Hedefin pozisyonunu al ama Y'sini bizim Y'mize (1.0) eşitle
	var aim_pos = target.global_position
	aim_pos.y = global_position.y 
	
	look_at(aim_pos, Vector3.UP)
	
	# POZİSYONU KİLİTLE
	locked_transform = global_transform
	
	visible = true
	if area: area.monitoring = true
	
	# GÖRSEL ANİMASYON
	if mesh:
		var tw = create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		# Mesh yatık olduğu için X ve Z eksenleri genişliği temsil eder
		tw.tween_property(mesh, "scale:x", beam_width, 0.2).from(0.0)
		tw.parallel().tween_property(mesh, "scale:z", beam_width, 0.2).from(0.0)
	
	# Hasar kontrolü için 1 frame bekle (Physics update)
	await get_tree().process_frame
	_apply_instant_damage()

func _stop_firing():
	if area: area.monitoring = false
	
	if mesh:
		var tw = create_tween()
		tw.tween_property(mesh, "scale:x", 0.0, 0.15)
		tw.parallel().tween_property(mesh, "scale:z", 0.0, 0.15)
		await tw.finished
	
	visible = false
	current_state = State.COOLDOWN
	state_timer = fire_cooldown
	
	# SIFIRLAMA: Karaktere geri dön ve gövde yüksekliğine ayarla
	transform = Transform3D.IDENTITY
	position.y = 1.0 

func _apply_instant_damage():
	if area and area.monitoring:
		for body in area.get_overlapping_bodies():
			_hit_enemy(body)

func _on_body_entered(body):
	if current_state == State.FIRING:
		_hit_enemy(body)

func _hit_enemy(body):
	if body.is_in_group("Enemies") and not body in enemies_hit:
		if body.has_method("take_damage"):
			body.take_damage(damage)
			enemies_hit.append(body)

func _find_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("Enemies")
	if enemies.is_empty(): return null
	var nearest = null
	var min_dist = 99999.0
	for e in enemies:
		if is_instance_valid(e):
			var d = global_position.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				nearest = e
	return nearest
