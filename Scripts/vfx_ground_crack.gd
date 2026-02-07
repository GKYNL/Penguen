extends MeshInstance3D
class_name VFXGroundCrack

func _ready():
	# 1. Görünürlük Ayarı
	# Eğer sahne tasarımı 0,0,0 ise hafif yukarı kaldır.
	# Zaten 0.87 yaptıysan ve görünmüyorsa sorun shaderdaydı.
	# Şimdi 0.1 yapalım, havada uçmasın.
	position.y += 0.1 
	
	rotation.y = randf() * TAU
	
	# Mesh yoksa oluştur (Editörden atadıysan burası çalışmaz, güvenlidir)
	if not mesh:
		mesh = PlaneMesh.new()
		mesh.size = Vector2(6.0, 6.0)
		
	start_crack_animation()

func start_crack_animation():
	var mat = material_override as ShaderMaterial
	if not mat:
		# Override yoksa mesh surface'den al
		mat = get_active_material(0) as ShaderMaterial
	
	if not mat:
		queue_free()
		return
	
	# Materyali kopyala (Her efekt bağımsız olsun)
	mat = mat.duplicate()
	material_override = mat
	
	# Başlangıç Değerleri
	mat.set_shader_parameter("expansion", 0.0) # Kapalı başla
	mat.set_shader_parameter("fade", 0.0)      # Tam opak başla
	
	var tw = create_tween()
	
	# 1. PATLAMA: expansion 0.0 -> 1.0 (0.2 saniyede)
	# Bu, çatlakların merkezden dışa doğru hızla çizilmesini sağlar
	tw.tween_method(func(v): mat.set_shader_parameter("expansion", v), 0.0, 1.0, 0.2).set_ease(Tween.EASE_OUT)
	
	# 2. BEKLEME: 0.5 saniye çatlak yerde kalsın
	tw.tween_interval(0.5)
	
	# 3. SİLİNME: fade 0.0 -> 1.0 (0.5 saniyede)
	tw.tween_method(func(v): mat.set_shader_parameter("fade", v), 0.0, 1.0, 0.5)
	
	# Bittiğinde sil
	tw.finished.connect(queue_free)
