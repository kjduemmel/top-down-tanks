@tool
extends EditorPlugin

const GROUP_NAME := "ORTHOGRAPHIC"
const BODY_NAME := "Body"

var squash_factor: float = 2.0 / 3.0

func _enter_tree() -> void:
	set_process(true)

func _exit_tree() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	var scene_root: Node = get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return

	var changed := 0
	changed = _sync_descendants_in_group(scene_root)

func _sync_descendants_in_group(scene_root: Node) -> int:
	var changed := 0

	# Get *all* nodes in group, then only keep the ones under the edited scene root.
	for n: Node in scene_root.get_tree().get_nodes_in_group(GROUP_NAME):
		if not (n is Node2D):
			continue

		var root2d := n as Node2D

		# Only affect nodes that belong to the currently edited scene tree
		if not scene_root.is_ancestor_of(root2d) and root2d != scene_root:
			continue

		var body_node := root2d.find_child(BODY_NAME, true, false)
		if body_node == null or not (body_node is Node2D):
			continue

		var body := body_node as Node2D
		var desired_world := Vector2(root2d.global_position.x, root2d.global_position.y / squash_factor)

		if body.global_position.distance_to(desired_world) > 0.01:
			body.global_position = desired_world
			changed += 1

	return changed
