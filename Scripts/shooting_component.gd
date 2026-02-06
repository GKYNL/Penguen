extends Node3D

@export var projectile_scene: PackedScene 
@export var shoot_origin_path: NodePath 

@onready var shoot_origin = get_node_or_null(shoot_origin_path)

# --- WEAPON MANAGER'IN ARADIĞI ORİJİNAL DEĞİŞKENLER (KORUNDU) ---
var current_damage: float = 10.0
var current_projectile_scale: float = 1.0
var current_pierce: int = 1
var current_count: int = 1 

# --- TEK BİR FONKSİYONDA TÜM MEKANİKLER ---
func shoot(target_direction: Vector3):
	if not projectile_scene: return
	
	var spawn_pos = shoot_origin.global_position if shoot_origin else global_position
	
	# 1. ECHOING SCREAMS (Gold 6): Dalga (Wave) Mantığı
	# Statlardan dalga sayısını çekiyoruz, yoksa 1 kabul et.
	var waves = AugmentManager.player_stats.get("waves", 1)
	
	for w in range(waves):
		_perform_single_volley(spawn_pos, target_direction)
		
		# Dalgalar arası minik bekleme (Makinalı tüfek hissi)
		if waves > 1:
			await get_tree().create_timer(0.15).timeout

# Yardımcı Fonksiyon: Tek bir salvo ateşler
func _perform_single_volley(origin: Vector3, dir: Vector3):
	# 2. TRIPLE SHOT (Silver 11): Şanslı Atış
	var final_count = current_count
	if randf() < AugmentManager.player_stats.get("multishot_chance", 0.0):
		final_count += 2 # Şans tutarsa +2 mermi ekle
	
	for i in range(final_count):
		var projectile = projectile_scene.instantiate()
		get_tree().root.add_child(projectile)
		
		# Mermileri yan yana (spread) veya açılı dizme
		# Eğer çoklu atışsa hafif sağa sola açarak atalım
		var spread_angle = 0.0
		if final_count > 1:
			# -15 ile +15 derece arasında dağıt
			if i % 2 == 1: spread_angle = deg_to_rad(15 * (i + 1) / 2.0)
			else: spread_angle = deg_to_rad(-15 * (i + 1) / 2.0)
			if i == 0: spread_angle = 0.0 # İlk mermi düz gitsin
		
		var final_dir = dir.rotated(Vector3.UP, spread_angle).normalized()
		
		projectile.global_position = origin
		
		# --- STATLARI MERMİYE AKTAR ---
		# Hasar, Damage Multiplier ile çarpılır
		if "damage" in projectile: 
			projectile.damage = current_damage * AugmentManager.player_stats.get("damage_mult", 1.0)
		
		if "pierce" in projectile: 
			projectile.pierce = current_pierce
			
		projectile.scale = Vector3.ONE * current_projectile_scale
		
		# Mermiye yön ver
		if projectile.get("direction"):
			projectile.direction = final_dir
		else:
			# Alternatif: Fiziksel look_at
			projectile.look_at(projectile.global_position + final_dir, Vector3.UP)
