@tool
extends Sprite2D

@export var source_path: NodePath = NodePath("..")

# How many directions to simulate from rotation
@export var directions: int = 8

# How many direction frames across the sheet (used for rotation)
@export var frame_columns: int = 4

# Rows = states
@export var states: int = 1
@export var state_row: int = 0

@export var degrees_offset: float = 0.0
@export var use_global_rotation: bool = true

@export var height_tex: Texture2D

var _source: Node2D

func _ready() -> void:
	_source = get_node_or_null(source_path) as Node2D
	_apply_frame()

func _process(_dt: float) -> void:
	_apply_frame()
	position = _source.position

func set_state_row(new_row: int) -> void:
	state_row = new_row
	_apply_frame()

func _apply_frame() -> void:
	if _source == null:
		return
	if directions <= 0:
		return
	if frame_columns <= 0:
		return

	var rot: float
	if use_global_rotation:
		rot = -_source.global_rotation
	else:
		rot = -_source.rotation

	var deg: float = rad_to_deg(rot) + degrees_offset
	deg = fposmod(deg, 360.0)

	var slice: float = 360.0 / float(directions)
	var dir_index: int = int(floor((deg + slice * 0.5) / slice)) % directions

	# Wrap into available columns
	var col: int = dir_index % frame_columns

	# Clamp state row
	var row: int = state_row
	if row < 0:
		row = 0
	if states > 0 and row >= states:
		row = states - 1

	frame = row * frame_columns + col
