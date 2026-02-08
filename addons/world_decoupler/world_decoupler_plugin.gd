@tool
extends EditorPlugin

const AUTOLOAD_NAME: StringName = &"WorldDecoupler"

var _dock: Control
var _status: Label

var _snap_pos: CheckBox
var _snap_tile: CheckBox
var _tile_size: SpinBox

var _snap_rot: CheckBox
var _rot_dirs: SpinBox

var _suspend_apply: bool = false
var _last_probe_ms: int = 0

func _enter_tree() -> void:
	_build_ui()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_refresh_from_autoload()
	set_process(true)

func _exit_tree() -> void:
	set_process(false)

	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.free()

func _process(_dt: float) -> void:
	# Probe occasionally and refresh once we can see the autoload.
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_probe_ms < 300:
		return
	_last_probe_ms = now_ms

	var dec := _get_autoload_node()
	if dec == null:
		_status.text = "WorldDecoupler: NOT FOUND (add Autoload named 'WorldDecoupler')"
		return

	_status.text = "WorldDecoupler: FOUND"

# ---------------- Autoload lookup ----------------

func _get_autoload_node() -> Node:
	var tree := get_editor_interface().get_base_control().get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("/root/" + String(AUTOLOAD_NAME)))

# ---------------- UI ----------------

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "World Decoupler"

	_status = Label.new()
	_status.text = "WorldDecoupler: (checking...)"
	root.add_child(_status)
	root.add_child(HSeparator.new())

	root.add_child(_title("Move"))

	_snap_pos = CheckBox.new()
	_snap_pos.text = "Snap Position in Editor"
	root.add_child(_snap_pos)

	_snap_tile = CheckBox.new()
	_snap_tile.text = "Snap to Tile Grid (otherwise pixel snap)"
	root.add_child(_snap_tile)

	_tile_size = _spin(1.0, 2048.0, 1.0)
	root.add_child(_row("Physical Tile Size", _tile_size))

	root.add_child(HSeparator.new())
	root.add_child(_title("Rotate"))

	_snap_rot = CheckBox.new()
	_snap_rot.text = "Snap Rotation in Editor"
	root.add_child(_snap_rot)

	_rot_dirs = _spin(1.0, 64.0, 1.0)
	_rot_dirs.rounded = true
	root.add_child(_row("Rotation Directions", _rot_dirs))

	_dock = root

	# Auto-apply on any change
	_snap_pos.toggled.connect(func(_v: bool): _apply_to_autoload())
	_snap_tile.toggled.connect(func(_v: bool): _apply_to_autoload())
	_snap_rot.toggled.connect(func(_v: bool): _apply_to_autoload())

	_tile_size.value_changed.connect(func(_v: float): _apply_to_autoload())
	_rot_dirs.value_changed.connect(func(_v: float): _apply_to_autoload())

func _title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 16)
	return l

func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _spin(mn: float, mx: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	return s

# ---------------- Sync settings ----------------

func _refresh_from_autoload() -> void:
	var dec := _get_autoload_node()
	if dec == null:
		_status.text = "WorldDecoupler: NOT FOUND (add Autoload named 'WorldDecoupler')"
		return

	_status.text = "WorldDecoupler: FOUND"

	_suspend_apply = true

	_snap_pos.button_pressed = bool(dec.get("snap_position_in_editor"))
	_snap_tile.button_pressed = bool(dec.get("snap_to_tile_grid"))
	_tile_size.value = float(dec.get("physical_tile_size"))

	_snap_rot.button_pressed = bool(dec.get("snap_rotation_in_editor"))
	_rot_dirs.value = float(dec.get("rotation_directions"))

	_suspend_apply = false

func _apply_to_autoload() -> void:
	if _suspend_apply:
		return

	var dec := _get_autoload_node()
	if dec == null:
		_status.text = "WorldDecoupler: NOT FOUND (add Autoload named 'WorldDecoupler')"
		return

	dec.set("snap_position_in_editor", bool(_snap_pos.button_pressed))
	dec.set("snap_to_tile_grid", bool(_snap_tile.button_pressed))
	dec.set("physical_tile_size", float(_tile_size.value))

	dec.set("snap_rotation_in_editor", bool(_snap_rot.button_pressed))
	dec.set("rotation_directions", int(round(_rot_dirs.value)))

	_status.text = "WorldDecoupler: FOUND"
