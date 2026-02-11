extends Node3D

func start_effect():
	# Partikülleri çalıştır
	for child in find_children("*", "GPUParticles3D"):
		child.restart()
		child.emitting = true
	
	# Efekt süresi kadar bekle (Örneğin 1 saniye)
	await get_tree().create_timer(0.5).timeout
	
	# Havuza dön
	VFXPoolManager.return_to_pool(self, "wind_dash")

# Eğer pool'dan spawn edilince otomatik başlamasını istersen:
func on_spawn():
	start_effect()
