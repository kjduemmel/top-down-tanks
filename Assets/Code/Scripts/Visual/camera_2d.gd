extends Camera2D
@export var target_path: NodePath
@export var snap_px: int = 4
var target: Node2D

func _ready() -> void:
	target = get_node_or_null(target_path) as Node2D

func _process(_dt: float) -> void:
	if target == null:
		return
	var p := target.global_position
	global_position = (p / float(snap_px)).round() * float(snap_px)
