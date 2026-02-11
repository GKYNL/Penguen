extends HBoxContainer

@export var full_texture: Texture2D # Dolu dash ikonu
@export var empty_texture: Texture2D # Boş dash ikonu

var player: Player
var indicators: Array = []

func _ready():
	# Player'ı bul
	player = get_tree().get_first_node_in_group("player")
	
	# HATA ÇÖZÜMÜ: Buradaki update_dash_count() çağrısını sildik.
	# _process fonksiyonu zaten oyun başlar başlamaz bunu halledecek.

func _process(_delta):
	if not is_instance_valid(player): return
	
	# 1. Maksimum dash sayısını hesapla
	var max_charges = AugmentManager.player_stats.get("dash_charges", 1)
	
	# Wind Walker (Gold 8) Level 3 ise +1 Dash hakkı
	if AugmentManager.mechanic_levels.get("gold_8", 0) >= 3: 
		max_charges += 1
	
	# 2. Eğer UI'daki kutu sayısı ile gerçek sayı tutmuyorsa yeniden çiz
	if indicators.size() != max_charges:
		_setup_indicators(max_charges)
	
	# 3. Doluluk oranını (ikonları) güncelle
	_update_visuals()

func _setup_indicators(count: int):
	# Eskileri temizle
	for child in get_children():
		child.queue_free()
	indicators.clear()
	
	# Yeni ikonları oluştur
	for i in range(count):
		var tex = TextureRect.new()
		# Eğer texture atanmadıysa hata vermemesi için kontrol (placeholder)
		if full_texture: tex.texture = full_texture
		
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(48, 48) # İkon boyutu (biraz büyüttüm)
		add_child(tex)
		indicators.append(tex)

func _update_visuals():
	if not player: return
	var current = player.current_dash_charges
	
	for i in range(indicators.size()):
		var icon = indicators[i]
		
		if i < current:
			# Dolu Dash Hakkı
			if full_texture: icon.texture = full_texture
			icon.modulate = Color(1, 1, 1, 1) # Tam Opak
		else:
			# Boş Dash Hakkı (Harcanmış)
			if empty_texture: icon.texture = empty_texture
			else: 
				# Eğer empty_texture yoksa full texture'ı şeffaflaştır
				if full_texture: icon.texture = full_texture
			
			icon.modulate = Color(1, 1, 1, 0.3) # Sönük/Şeffaf
