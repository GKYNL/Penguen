extends CharacterBody3D

# --- AYARLAR ---
var target_player: Node3D = null
var offset: Vector3 = Vector3.ZERO
var move_speed: float = 8.0
var damage_percent: float = 0.2 
var attack_range: float = 12.0
var attack_cooldown: float = 1.0

var can_attack: bool = true
@onready var attack_timer: Timer = Timer.new()

var projectile_scenes = {
	"ice_shard": preload("res://levels/projectiles/ice_shard/ice_shard.tscn"),
	"snowball": preload("res://levels/projectiles/snowball/snowball.tscn")
}

var current_projectile_key: String = "ice_shard"

func _ready():
	add_child(attack_timer)
	attack_timer.timeout.connect(func(): can_attack = true)
	collision_layer = 0 
	collision_mask = 1 

func setup_stats(level_data: Dictionary, index: int, total_count: int, projectile_type: String):
	if level_data.has("dmg"):
		damage_percent = float(level_data["dmg"])
	
	if projectile_scenes.has(projectile_type):
		current_projectile_key = projectile_type
	
	var radius = 3.5
	var angle_step = TAU / total_count
	var current_angle = index * angle_step
	offset = Vector3(cos(current_angle) * radius, 0, sin(current_angle) * radius)

func _physics_process(_delta):
	if not is_instance_valid(target_player): 
		target_player = get_tree().get_first_node_in_group("player")
		return
	
	var target_pos = target_player.global_position + offset
	target_pos.y = target_player.global_position.y
	
	var dist = global_position.distance_to(target_pos)
	var dir = global_position.direction_to(target_pos)
	
	if dist > 0.2:
		velocity = dir * move_speed * (dist * 1.2)
		move_and_slide()
		
		# --- DÜZELTME: KLON YÖNÜ ---
		if velocity.length() > 0.1:
			var look_target = global_position + velocity.normalized()
			look_at(Vector3(look_target.x, global_position.y, look_target.z), Vector3.UP)
			# Modeli 180 derece çeviriyoruz
			rotate_object_local(Vector3.UP, PI)
	
	if can_attack:
		_try_attack()

func _try_attack():
	var enemy = _find_nearest_enemy()
	if enemy:
		# Ateş ederken de düşmana doğru dönmesini istersen:
		look_at(Vector3(enemy.global_position.x, global_position.y, enemy.global_position.z), Vector3.UP)
		rotate_object_local(Vector3.UP, PI)
		_shoot_at(enemy)

func _shoot_at(target):
	var scene_to_spawn = projectile_scenes.get(current_projectile_key)
	if not scene_to_spawn: return
	
	can_attack = false
	attack_timer.start(attack_cooldown)
	
	var proj = scene_to_spawn.instantiate()
	get_tree().root.add_child(proj)
	proj.global_position = global_position + Vector3(0, 0.8, 0) # Göğüs hizası
	
	var player_dmg = AugmentManager.player_stats.get("damage", 10.0)
	proj.damage = player_dmg * damage_percent
	
	# Mermi düşmana baksın
	proj.look_at(target.global_position + Vector3(0, 0.5, 0), Vector3.UP)

func _find_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var nearest = null
	var min_dist = attack_range
	for e in enemies:
		if is_instance_valid(e) and e.current_hp > 0:
			var d = global_position.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				nearest = e
	return nearest
