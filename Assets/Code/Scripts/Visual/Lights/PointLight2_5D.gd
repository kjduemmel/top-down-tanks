# PointLight2_5D.gd
extends Light2_5D
class_name PointLight2_5D

@export_range(0.0, 4096.0, 1.0) var range_px_world: float = 256.0
@export_range(0.0, 4.0, 0.01) var falloff: float = 2.0
@export var shadows_steps: int = 0 # 0 = no shadows (recommend at first)

func get_type() -> int:
	return LightType.POINT

func get_gpu_data_world() -> Dictionary:
	var d := super.get_gpu_data_world()
	d["range"] = range_px_world
	d["falloff"] = falloff
	d["shadow_steps"] = shadows_steps
	return d
