# DirectionalLight2_5D.gd
extends Light2_5D
class_name DirectionalLight2_5D

@export var direction_from_rotation: bool = true
@export var direction: Vector3 = Vector3(0.3, 0.6, 0.74).normalized() # fallback

# For sun: typically you want a little Z component so normals matter
@export_range(-1.0, 1.0, 0.01) var z_dir: float = 0.7

func get_type() -> int:
	return LightType.DIRECTIONAL
	
func _process(delta: float) -> void:
	rotate(0.2*delta)

func _dir_world() -> Vector3:
	if direction_from_rotation:
		# 2D rotation gives XY direction; we add Z component
		var d2 := Vector2.RIGHT.rotated(global_rotation).normalized()
		return Vector3(d2.x, d2.y, z_dir).normalized()
	return direction.normalized()

func get_gpu_data_world() -> Dictionary:
	var d := super.get_gpu_data_world()
	d["dir"] = _dir_world()
	return d
