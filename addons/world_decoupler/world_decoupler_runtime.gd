@tool
extends Node

# Child node names in each game object scene
@export var physics_child_name: StringName = &"Physics"
@export var visual_child_name: StringName = &"Visual"

# Projection (physical -> visual)
const SQUASH_Y: float = 2.0 / 3.0

# Editor placement snapping (in VISUAL space, since root is visual-space)
@export var snap_position_in_editor: bool = true
@export var snap_to_tile_grid: bool = false
@export var physical_tile_size: float = 48.0

# Editor rotation snapping
@export var snap_rotation_in_editor: bool = false
@export var rotation_directions: int = 8

# Rotation sync (keep true if your sprite direction uses physics rotation)
@export var sync_rotation: bool = true

var _roots: Array[Node2D] = []
var _phys_cache: Dictionary = {}
var _vis_cache: Dictionary = {}

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	_rebuild()

func _process(_dt: float) -> void:

	var editor_mode: bool = Engine.is_editor_hint()

	var i: int = 0
	while i < _roots.size():
		var root: Node2D = _roots[i]
		if not is_instance_valid(root):
			_roots.remove_at(i)
			continue

		_apply(root, editor_mode)
		i += 1

func _apply(root: Node2D, editor_mode: bool) -> void:
	var phys: Node2D = _get_physics(root)
	var vis: Node2D = _get_visual(root)

	if phys == null and vis == null:
		return

	# Root lives in VISUAL space. Physics lives in PHYSICAL space.
	if phys != null:
		phys.top_level = true

	if editor_mode:
		# Global editor snapping
		if snap_position_in_editor:
			_snap_root_visual_space(root)

		if snap_rotation_in_editor:
			_snap_rotation(root)

		# Editor: root is visual-space, so place physics by unprojecting it
		if phys != null:
			phys.global_position = _unproject(root.global_position)
			if sync_rotation:
				phys.global_rotation = root.global_rotation

		_place_visual_on_root(vis)

	else:
		# Runtime: physics is truth. Root follows projected physics.
		if phys != null:
			var p: Vector2 = _project(phys.global_position)
			p = _snap_vec2(p, 1.0)

			root.global_position = p
			if sync_rotation:
				root.global_rotation = phys.global_rotation

		_place_visual_on_root(vis)

func _place_visual_on_root(vis: Node2D) -> void:
	if vis == null:
		return
	vis.position = Vector2.ZERO
	vis.rotation = 0.0

# ---------- Snapping (visual space) ----------

func _snap_root_visual_space(root: Node2D) -> void:
	var p: Vector2 = root.global_position

	if snap_to_tile_grid:
		var sx: float = physical_tile_size
		if sx < 1.0:
			sx = 1.0

		# Visual tile height is squashed
		var sy: float = physical_tile_size * SQUASH_Y
		if sy < 1.0:
			sy = 1.0

		p.x = round(p.x / sx) * sx
		p.y = round(p.y / sy) * sy
	else:
		p = _snap_vec2(p, 1.0)

	root.global_position = p

func _snap_rotation(root: Node2D) -> void:
	var dirs: int = rotation_directions
	if dirs < 1:
		dirs = 1

	var step_deg: float = 360.0 / float(dirs)

	# snap degrees to nearest step
	var deg: float = rad_to_deg(root.global_rotation)
	deg = round(deg / step_deg) * step_deg

	root.global_rotation = deg_to_rad(deg)


func _snap_vec2(p: Vector2, step: float) -> Vector2:
	var s: float = step
	if s <= 0.0:
		s = 1.0
	var out: Vector2 = p
	out.x = round(out.x / s) * s
	out.y = round(out.y / s) * s
	return out

# ---------- Projection math ----------

func _project(physical_pos: Vector2) -> Vector2:
	return Vector2(physical_pos.x, physical_pos.y * SQUASH_Y)

func _unproject(visual_pos: Vector2) -> Vector2:
	var inv: float = 1.0
	if SQUASH_Y != 0.0:
		inv = 1.0 / SQUASH_Y
	return Vector2(visual_pos.x, visual_pos.y * inv)

# ---------- Auto-detect roots ----------

func _rebuild() -> void:
	_roots.clear()
	_phys_cache.clear()
	_vis_cache.clear()
	_scan(get_tree().root)

func _scan(n: Node) -> void:
	if n is Node2D:
		var root: Node2D = n as Node2D
		if _looks_like_root(root):
			_register(root)

	for c in n.get_children():
		_scan(c)

func _looks_like_root(root: Node2D) -> bool:
	var has_phys: bool = root.get_node_or_null(NodePath(physics_child_name)) != null
	var has_vis: bool = root.get_node_or_null(NodePath(visual_child_name)) != null
	return has_phys or has_vis

func _register(root: Node2D) -> void:
	for r in _roots:
		if r == root:
			return
	_roots.append(root)
	_get_physics(root)
	_get_visual(root)

func _get_physics(root: Node2D) -> Node2D:
	if _phys_cache.has(root):
		return _phys_cache[root] as Node2D
	var node: Node = root.get_node_or_null(NodePath(physics_child_name))
	var phys: Node2D = node as Node2D
	_phys_cache[root] = phys
	return phys

func _get_visual(root: Node2D) -> Node2D:
	if _vis_cache.has(root):
		return _vis_cache[root] as Node2D
	var node: Node = root.get_node_or_null(NodePath(visual_child_name))
	var vis: Node2D = node as Node2D
	_vis_cache[root] = vis
	return vis

func _on_node_added(n: Node) -> void:
	if n is Node2D:
		var root: Node2D = n as Node2D
		if _looks_like_root(root):
			_register(root)

func _on_node_removed(n: Node) -> void:
	_phys_cache.erase(n)
	_vis_cache.erase(n)
