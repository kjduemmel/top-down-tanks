extends Node2D
class_name ShadowPlane2D

@export var local_center_3d: Vector3 = Vector3.ZERO
@export var local_axis_u: Vector3 = Vector3(1, 0, 0)
@export var local_axis_v: Vector3 = Vector3(0, 0, 1)
@export var half_size: Vector2 = Vector2(16, 16)
@export var two_sided: bool = true
@export var enabled: bool = true
@export var shadow_texture: Texture2D
@export_range(0.0, 1.0) var shadow_strength := 1.0

func _ready() -> void:
	add_to_group("rd_shadow_planes")

func _rot_xy(v: Vector3, c: float, s: float) -> Vector3:
	return Vector3(
		v.x * c - v.y * s,
		v.x * s + v.y * c,
		v.z
	)

func get_shadow_plane_gpu_data() -> Dictionary:
	if not enabled:
		return { "enabled": false }

	# Use THIS ShadowPlane2D node's full global transform.
	# This includes the RotateShadows parent, snapped rotation, and this node's local position.
	var t := global_transform

	var center_xy := t * Vector2(local_center_3d.x, local_center_3d.y)

	var center_world := Vector3(
		center_xy.x,
		center_xy.y,
		local_center_3d.z
	)

	# Transform axis directions without translation.
	var u_xy := t.basis_xform(Vector2(local_axis_u.x, local_axis_u.y))
	var v_xy := t.basis_xform(Vector2(local_axis_v.x, local_axis_v.y))

	var axis_u_world := Vector3(u_xy.x, u_xy.y, local_axis_u.z).normalized()
	var axis_v_world := Vector3(v_xy.x, v_xy.y, local_axis_v.z).normalized()

	return {
		"enabled": enabled,
		"center": center_world,
		"axis_u": axis_u_world,
		"axis_v": axis_v_world,
		"half_size": half_size,
		"two_sided": two_sided,
		"shadow_texture": shadow_texture,
		"shadow_strength": shadow_strength,
	}
