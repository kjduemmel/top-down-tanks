# Light2_5D.gd
extends Node2D
class_name Light2_5D

enum LightType { DIRECTIONAL = 0, POINT = 1, SPOT = 2 }

@export var enabled: bool = true
@export var light_color: Color = Color(1, 1, 1, 1)
@export_range(0.0, 50.0, 0.01) var intensity: float = 1.0

@export_range(0, 255, 1) var zpx: int = 0

@export var casts_shadows: bool = true
@export_range(0.0, 1.0, 0.01) var shadow_strength: float = 0.7

# Useful to group-locate lights quickly
@export var light_group_name: StringName = &"rd_lights"

func _enter_tree() -> void:
	add_to_group(light_group_name)

func _exit_tree() -> void:
	if is_in_group(light_group_name):
		remove_from_group(light_group_name)

func get_type() -> int:
	return -1 # overridden

# Returns a Dictionary that your renderer can pack into a SSBO/texture.
# Renderer will convert world XY -> internal XY, so this stays in world space.
func get_gpu_data_world() -> Dictionary:
	return {
		"type": get_type(),
		"pos_xy": global_position, # Vector2 in world space
		"z": zpx/255.0,
		"color": Vector3(light_color.r, light_color.g, light_color.b),
		"intensity": intensity,
		"casts_shadows": casts_shadows,
		"shadow_strength": shadow_strength,
	}
