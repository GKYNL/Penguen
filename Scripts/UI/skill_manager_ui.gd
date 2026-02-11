extends HBoxContainer

# Skill Slot Sahnesi (Yukarıda anlattığım sahne)
var slot_scene = preload("res://Scenes/UI/skill_slot.tscn")

# Takip edilecek yetenekler ve Player scriptindeki timer değişken isimleri
# Örn: "prism_4" (Black Hole) -> Player scriptindeki değişken: "black_hole_timer"
# cooldown değişkeni: "black_hole_cooldown"
var tracked_skills = {
	"prism_3": {"name": "Titan Stomp", "timer": "stomp_timer", "cd": "stomp_interval", "icon": "res://Assets/Icons/stomp.png"},
	"prism_4": {"name": "Black Hole", "timer": "black_hole_timer", "cd": "black_hole_cooldown", "icon": "res://Assets/Icons/black_hole.png"},
	"prism_6": {"name": "Time Stop", "timer": "time_stop_timer", "cd": "base_time_stop_cd", "icon": "res://Assets/Icons/time_stop.png"},
	"prism_7": {"name": "Dragon Breath", "timer": "dragon_timer", "cd": "dragon_cooldown", "icon": "res://Assets/Icons/dragon.png"},
	# prism_9 (Godspeed) ve prism_8 (Mirror) genelde pasif veya sürekli olduğu için CD göstermeye gerek olmayabilir
	# Ama Godspeed hasar veriyorsa ve bir bekleme süresi varsa (0.15s gibi) onu gösterme, çok hızlı yanıp söner.
}

var active_slots = {} # { "prism_4": slot_node }
var player: Player

func _ready():
	player = get_tree().get_first_node_in_group("player")
	# Her saniye augmentleri kontrol et (Performans için timer kullanabilirsin veya sinyal)
	var t = Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(_check_new_skills)
	add_child(t)

func _process(_delta):
	if not is_instance_valid(player): return
	
	for id in active_slots:
		var slot = active_slots[id]
		var data = tracked_skills[id]
		
		# Player'dan timer ve cooldown değerlerini al
		# get() fonksiyonu ile değişkene string adıyla erişiyoruz
		var current_timer = player.get(data["timer"])
		var max_cd = player.get(data["cd"])
		
		# Time Stop gibi özel durumlar için (Player'da base_time_stop_cd var ama hesaplanıyor)
		if id == "prism_6":
			 # Player kodunda hesaplanan son CD'yi almamız lazım ama basitlik için base alıyoruz
			 # Veya player scriptine "get_current_cooldown(id)" gibi bir fonk ekleyebilirsin.
			pass

		if current_timer != null and max_cd != null:
			update_slot_visual(slot, current_timer, max_cd)

func _check_new_skills():
	# AugmentManager'daki yeteneklere bak
	var levels = AugmentManager.mechanic_levels
	
	for id in tracked_skills:
		if levels.has(id) and not active_slots.has(id):
			add_skill_slot(id)

func add_skill_slot(id):
	var data = tracked_skills[id]
	var new_slot = slot_scene.instantiate()
	add_child(new_slot)
	active_slots[id] = new_slot
	
	# İkonu ayarla
	var icon_node = new_slot.get_node("Icon") # İsimlendirmene göre değişir
	if icon_node:
		# load() yerine preload kullanmak daha iyi ama dinamik yapıda load şart
		icon_node.texture = load(data["icon"])

func update_slot_visual(slot, current_timer, max_cd):
	var progress = slot.get_node("TextureProgressBar")
	var label = slot.get_node("Label")
	
	if max_cd <= 0: return
	
	# Timer 0'dan büyükse skill CD'de demektir
	if current_timer > 0:
		var percent = (current_timer / max_cd) * 100
		progress.value = percent
		progress.visible = true
		label.text = "%.1f" % current_timer
		label.visible = true
		slot.modulate = Color(0.5, 0.5, 0.5, 1.0) # Sönük yap
	else:
		progress.visible = false
		label.visible = false
		slot.modulate = Color(1, 1, 1, 1.0) # Parlak yap
