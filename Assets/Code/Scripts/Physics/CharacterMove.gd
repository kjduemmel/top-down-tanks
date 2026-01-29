#this is a simple script for demonstration. We will change it when we work on controls.

extends CharacterBody2D

@export var speed: float = 200.0

func _physics_process(_dt: float) -> void:
	var dir := Vector2.ZERO

	if Input.is_action_pressed("ui_right"):
		dir.x += 1.0
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("ui_down"):
		dir.y += 1.0
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1.0

	if dir.length() > 0.0:
		dir = dir.normalized()

	velocity = dir * speed
	move_and_slide()
