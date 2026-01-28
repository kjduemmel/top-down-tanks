@tool
extends Node2D

# How many angle frames exist on the spritesheet (set to 1 for no rotation)
@export_range(1, 16) var angle_count: int = 1


# Node to read rotation from (usually your physics body)
@export var body_path: NodePath = NodePath("../Body")

@onready var spr: Sprite2D = $Sprite2D
@onready var body: Node2D = get_node_or_null(body_path)

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_physics_process(true)

func _process(_dt: float) -> void:
	_update_frame()

func _physics_process(_dt: float) -> void:
	_update_frame()

func _update_frame() -> void:
	if spr == null:
		return

	body = body if body != null else get_node_or_null(body_path)
	if body == null:
		return

	# Never rotate the sprite node itself
	spr.rotation = 0.0

	# "Rotate" by choosing a frame based on the body's rotation
	spr.frame = _rotation_to_frame(body.global_rotation)

func _rotation_to_frame(r: float) -> int:
	if angle_count <= 1:
		return 0
	var rot := wrapf(r, 0.0, TAU)
	return int(round((rot / TAU) * angle_count)) % angle_count
