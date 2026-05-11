extends Node2D

@export var follow_parent := true
@export var directions : int = 16

func _process(_delta: float) -> void:
	var tank := get_parent() as Node2D
	if tank == null:
		return

	global_position = tank.global_position
	global_rotation = snap_angle(tank.global_rotation, directions)

func snap_angle(angle: float, directions: int) -> float:
	var step := TAU / directions
	return round(angle / step) * step
