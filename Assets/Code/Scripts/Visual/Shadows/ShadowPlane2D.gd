extends Node2D
class_name ShadowPlane2D

@export var local_center_3d: Vector3 = Vector3.ZERO
@export var local_axis_u: Vector3 = Vector3(1, 0, 0)
@export var local_axis_v: Vector3 = Vector3(0, 0, 1)
@export var half_size: Vector2 = Vector2(16, 16)
@export var two_sided: bool = true
@export var enabled: bool = true

func _ready() -> void:
	add_to_group("rd_shadow_planes")

func _rot_xy(v: Vector3, c: float, s: float) -> Vector3:
	return Vector3(
		v.x * c - v.y * s,
		v.x * s + v.y * c,
		v.z
	)

func get_shadow_plane_gpu_data() -> Dictionary:
	var owner_2d := get_parent() as Node2D
	if owner_2d == null:
		return {
			"enabled": false
		}

	var rot := owner_2d.global_rotation
	var base_pos := owner_2d.global_position

	# Rotate local XY offsets with the parent
	var center_xy_local := Vector2(local_center_3d.x, local_center_3d.y).rotated(rot)
	var center_world := Vector3(
		base_pos.x + center_xy_local.x,
		base_pos.y + center_xy_local.y,
		local_center_3d.z
	)

	# Rotate local plane axes with the parent in XY
	var u_xy := Vector2(local_axis_u.x, local_axis_u.y).rotated(rot)
	var v_xy := Vector2(local_axis_v.x, local_axis_v.y).rotated(rot)

	var axis_u_world := Vector3(u_xy.x, u_xy.y, local_axis_u.z).normalized()
	var axis_v_world := Vector3(v_xy.x, v_xy.y, local_axis_v.z).normalized()

	return {
		"enabled": enabled,
		"center": center_world,
		"axis_u": axis_u_world,
		"axis_v": axis_v_world,
		"half_size": half_size,
		"two_sided": two_sided
	}
