#this is a simple script for demonstration. We will change it when we work on controls.

extends CharacterBody2D

@export var speed: float = 200.0            # pixels/sec
@export var turn_speed: float = 3.0         # radians/sec

@onready var col: CollisionShape2D = $CollisionShape2D

func _physics_process(dt: float) -> void:
	# --- TURN (blocked by collision) ---
	var turn_input := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var desired_turn := turn_input * turn_speed * dt
	if desired_turn != 0.0:
		rotation += _safe_rotate(desired_turn)

	# --- MOVE (along facing direction) ---
	var move_input := Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	var forward := Vector2.RIGHT.rotated(rotation)  # change to Vector2.UP if your sprite faces up
	velocity = forward * (move_input * speed)

	move_and_slide()

func _safe_rotate(delta_rot: float) -> float:
	if col == null or col.shape == null:
		return delta_rot

	# If full turn is safe, take it
	if not _would_overlap(rotation + delta_rot):
		return delta_rot

	# Otherwise find the biggest safe fraction (smooth “blocked” feel)
	var lo := 0.0
	var hi := 1.0
	for _i in range(10):
		var mid := (lo + hi) * 0.5
		if _would_overlap(rotation + delta_rot * mid):
			hi = mid
		else:
			lo = mid

	if lo < 0.001:
		return 0.0
	return delta_rot * lo

func _would_overlap(test_rot: float) -> bool:
	var space := get_world_2d().direct_space_state

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = col.shape
	params.transform = Transform2D(test_rot, global_position)
	params.collision_mask = collision_mask
	params.exclude = [self]

	return space.intersect_shape(params, 1).size() > 0
