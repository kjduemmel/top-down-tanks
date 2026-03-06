@tool
extends Light2_5D
class_name SpotLight2_5D

@export_range(0.0, 4096.0, 1.0) var range_px_world: float = 320.0
@export_range(0.0, 179.0, 0.1) var inner_angle_deg: float = 18.0
@export_range(0.0, 179.0, 0.1) var outer_angle_deg: float = 30.0
@export_range(0.0, 4.0, 0.01) var falloff: float = 2.0

@export var direction_from_rotation: bool = true
@export var direction_override: Vector2 = Vector2.RIGHT

# Shadows are expensive for spot; keep low steps if enabled
@export var shadow_steps: int = 0

func get_type() -> int:
	return LightType.SPOT

func _dir2_world() -> Vector2:
	if direction_from_rotation:
		return Vector2.RIGHT.rotated(global_rotation).normalized()
	return direction_override.normalized()

func get_gpu_data_world() -> Dictionary:
	var d := super.get_gpu_data_world()
	var dir2 := _dir2_world()
	d["dir"] = Vector3(dir2.x, dir2.y, 0.0)
	d["range"] = range_px_world
	d["falloff"] = falloff
	d["inner_cos"] = cos(deg_to_rad(inner_angle_deg))
	d["outer_cos"] = cos(deg_to_rad(outer_angle_deg))
	d["shadow_steps"] = shadow_steps
	return d
