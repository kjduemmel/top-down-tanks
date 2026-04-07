extends Node

@export var internal_size: Vector2i = Vector2i(320, 180)
@export var y_min: float = 0.0
@export var y_max: float = 180.0
@export var height_scale: float = 1.0

@export var clear_rdshader: RDShaderFile = preload("res://Assets/Code/Shaders/rd_occlusion_clear.glsl")
@export var draw_rdshader: RDShaderFile = preload("res://Assets/Code/Shaders/rd_occlusion_draw.glsl")
@export var light_rdshader: RDShaderFile = preload("res://Assets/Code/Shaders/rd_lighting.glsl")

@onready var world: Node2D = get_node("../World") as Node2D
@onready var output: TextureRect = $Output

var rd: RenderingDevice

# Pipelines
var shader_clear: RID
var shader_draw: RID
var pipe_clear: RID
var pipe_draw: RID

# Output images (RD)
var depth_rid: RID          # r32ui (encoded height)
var default_depth_rid: RID  # a default if the thing has no depth map
var color_rid: RID          # rgba8 (encoded albedo)
var normal_rid: RID         # rgba8 (encoded normal)
var default_normal_rid: RID # a default if the thing has no normal map
var lit_rid: RID            # rgba8 (final lit output)
var out_tex: Texture2DRD    # wraps lit_rid for UI

# Uniform sets
var us0_clear: RID          # set=0 for clear shader (depth+color)
var us0_draw: RID           # set=0 for draw shader (depth+color)

# Sampler
var sampler_rid: RID

# Dummy height (1x1 black)
var dummy_height_rid: RID

# Caches: Godot Texture2D -> RD texture RID
var _rd_albedo_cache: Dictionary = {}  # Texture2D -> RID (RGBA8)
var _rd_height_cache: Dictionary = {}  # Texture2D -> RID (R8)

# Sprite list
var _sprites: Array[Sprite2D] = []
var _pending_rebuild: bool = true

var shader_light: RID
var pipe_light: RID
var us0_light: RID  # set=0 for lighting: depth+color+normal+lit
var us1_lights: RID # set=1: SSBO for lights
var lights_ssbo: RID
const MAX_LIGHTS := 64

var us2_shadow_planes: RID
var shadow_planes_ssbo: RID
const MAX_SHADOW_PLANES := 256

const COS_T := 2.0 / 3.0
const SIN_T := 0.7453559925

func _ready() -> void:
	# Use the MAIN rendering device so Texture2DRD can display the RID
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_error("RenderingDevice not available yet.")
		return
	output.set_anchors_preset(Control.PRESET_FULL_RECT)
	output.offset_left = 0
	output.offset_top = 0
	output.offset_right = 0
	output.offset_bottom = 0
	output.stretch_mode = TextureRect.STRETCH_SCALE
	output.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


	_make_sampler()
	_create_dummy_height()
	_create_default_normal()
	_create_output_images()
	_load_pipelines_and_sets()
	

	# Show the output texture
	out_tex = Texture2DRD.new()
	out_tex.texture_rd_rid = lit_rid
	output.texture = out_tex
	output.set_anchors_preset(Control.PRESET_FULL_RECT)

	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _screen_to_internal(p: Vector2) -> Vector2:
	var vp := _viewport_size()
	if vp.x <= 0.0 or vp.y <= 0.0:
		return p
	return Vector2(
		p.x * float(internal_size.x) / vp.x,
		p.y * float(internal_size.y) / vp.y
	)

func _delta_to_internal(d: Vector2) -> Vector2:
	# same scale as position
	return _screen_to_internal(d)

func _exit_tree() -> void:
	if rd == null:
		return

	# Free cached RD textures
	for rid_val in _rd_albedo_cache.values():
		var r: RID = rid_val as RID
		if r.is_valid():
			rd.free_rid(r)
	_rd_albedo_cache.clear()

	for rid_val2 in _rd_height_cache.values():
		var r2: RID = rid_val2 as RID
		if r2.is_valid():
			rd.free_rid(r2)
	_rd_height_cache.clear()

	# Free core RIDs
	if us0_clear.is_valid(): rd.free_rid(us0_clear)
	if us0_draw.is_valid(): rd.free_rid(us0_draw)

	if dummy_height_rid.is_valid(): rd.free_rid(dummy_height_rid)
	if sampler_rid.is_valid(): rd.free_rid(sampler_rid)

	if depth_rid.is_valid(): rd.free_rid(depth_rid)
	if color_rid.is_valid(): rd.free_rid(color_rid)
	if normal_rid.is_valid(): rd.free_rid(normal_rid)
	if lit_rid.is_valid(): rd.free_rid(lit_rid)
	if default_normal_rid.is_valid(): rd.free_rid(default_normal_rid)

	if pipe_clear.is_valid(): rd.free_rid(pipe_clear)
	if pipe_draw.is_valid(): rd.free_rid(pipe_draw)

	if shader_clear.is_valid(): rd.free_rid(shader_clear)
	if shader_draw.is_valid(): rd.free_rid(shader_draw)
	
	if us0_light.is_valid(): rd.free_rid(us0_light)
	if us1_lights.is_valid(): rd.free_rid(us1_lights)
	if us2_shadow_planes.is_valid(): rd.free_rid(us2_shadow_planes)

	if lights_ssbo.is_valid(): rd.free_rid(lights_ssbo)
	if shadow_planes_ssbo.is_valid(): rd.free_rid(shadow_planes_ssbo)

	if pipe_light.is_valid(): rd.free_rid(pipe_light)
	if shader_light.is_valid(): rd.free_rid(shader_light)


func _process(_dt: float) -> void:
	if rd == null:
		return

	if _pending_rebuild:
		_pending_rebuild = false
		_sprites = _gather_sprites(world)
		
	_sprites.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool:
		if a.global_position.y == b.global_position.y:
			return a.get_instance_id() < b.get_instance_id() # stable tiebreak
		return a.global_position.y > b.global_position.y      # bottom first
		)

	# Clear buffers each frame
	_dispatch_clear()

	# Draw all sprites (order doesn't matter; per-pixel depth compare decides)
	for s in _sprites:
		if is_instance_valid(s):
			_dispatch_draw_sprite(s)
			
	var light_count := _update_lights_ssbo()
	var plane_count := _update_shadow_planes_ssbo()
	_dispatch_lighting(light_count, plane_count)


# ----------------------------
# Setup
# ----------------------------

func _make_sampler() -> void:
	var samp := RDSamplerState.new()
	samp.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	samp.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	samp.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	samp.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_rid = rd.sampler_create(samp)


func _create_output_images() -> void:
	# Depth image: R32_UINT storage
	var df := RDTextureFormat.new()
	df.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	df.width = internal_size.x
	df.height = internal_size.y
	df.format = RenderingDevice.DATA_FORMAT_R32_UINT
	df.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	depth_rid = rd.texture_create(df, RDTextureView.new(), [])

	# Color image: RGBA8 storage + sampling (displayable)
	var cf := RDTextureFormat.new()
	cf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	cf.width = internal_size.x
	cf.height = internal_size.y
	cf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	cf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	color_rid = rd.texture_create(cf, RDTextureView.new(), [])
	
	# Normal image: RGBA8 storage + sampling
	var nf := RDTextureFormat.new()
	nf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	nf.width = internal_size.x
	nf.height = internal_size.y
	nf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	nf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	normal_rid = rd.texture_create(nf, RDTextureView.new(), [])

	# Lit output: RGBA8 storage + sampling (displayable)
	var lf := RDTextureFormat.new()
	lf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	lf.width = internal_size.x
	lf.height = internal_size.y
	lf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	lf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	lit_rid = rd.texture_create(lf, RDTextureView.new(), [])


func _create_dummy_height() -> void:
	# 1x1 black height texture in R8_UNORM
	var img := Image.create(1, 1, false, Image.FORMAT_L8)
	img.fill(Color(0, 0, 0, 1))
	var bytes: PackedByteArray = img.get_data()

	var hf := RDTextureFormat.new()
	hf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	hf.width = 1
	hf.height = 1
	hf.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	hf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT

	dummy_height_rid = rd.texture_create(hf, RDTextureView.new(), [bytes])

func _create_default_normal() -> void:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0.502, 0.875, 0.835, 1.0))
	var bytes := img.get_data()

	var tf := RDTextureFormat.new()
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = 1
	tf.height = 1
	tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT

	default_normal_rid = rd.texture_create(tf, RDTextureView.new(), [bytes])

func _create_lights_ssbo_and_set() -> void:
	var total := MAX_LIGHTS * 64
	if lights_ssbo.is_valid():
		rd.free_rid(lights_ssbo)

	lights_ssbo = rd.storage_buffer_create(total)

	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = 0
	u.add_id(lights_ssbo)

	us1_lights = rd.uniform_set_create([u], shader_light, 1)

func _update_lights_ssbo() -> int:
	var nodes := get_tree().get_nodes_in_group("rd_lights")
	var count := 0

	var data := PackedByteArray()
	data.resize(MAX_LIGHTS * 64)

	for n in nodes:
		if count >= MAX_LIGHTS:
			break
		if not n.has_method("get_gpu_data_world"):
			continue

		var d: Dictionary = n.call("get_gpu_data_world")
		if d.get("enabled", true) == false:
			continue

		var pos_world: Vector2 = d.get("pos_xy", (n as Node2D).global_position)
		# convert world -> screen -> internal (match your sprite path)
		var ct: Transform2D = get_viewport().canvas_transform
		var pos_screen: Vector2 = ct * pos_world
		var pos_internal: Vector2 = _screen_to_internal(pos_screen)

		var z: float = float(d.get("z", 0.0))
		var type: float = float(d.get("type", 0))

		var dir: Vector3 = d.get("dir", Vector3(1,0,0))
		var inner_cos: float = float(d.get("inner_cos", 0.0))

		var col_any = d.get("color", Color.WHITE)
		var col: Color = Color.WHITE
		if col_any is Color:
			col = col_any
		elif col_any is Vector3:
			var v: Vector3 = col_any
			col = Color(v.x, v.y, v.z, 1.0)
		var light_range: float = float(d.get("range", 0.0))

		var intensity: float = float(d.get("intensity", 1.0))
		var outer_cos: float = float(d.get("outer_cos", 0.0))
		var falloff: float = float(d.get("falloff", 2.0))
		var shadow_steps: float = float(d.get("shadow_steps", 0))

		var base := count * 64
		_write_vec4(data, base + 0,  Vector4(pos_internal.x, pos_internal.y, z, type))
		_write_vec4(data, base + 16, Vector4(dir.x, dir.y, dir.z, inner_cos))
		_write_vec4(data, base + 32, Vector4(col.r, col.g, col.b, light_range))
		_write_vec4(data, base + 48, Vector4(intensity, outer_cos, falloff, shadow_steps))

		count += 1

	rd.buffer_update(lights_ssbo, 0, data.size(), data)
	return count
	
func _create_shadow_planes_ssbo_and_set() -> void:
	var total_bytes := MAX_SHADOW_PLANES * 48

	if shadow_planes_ssbo.is_valid():
		rd.free_rid(shadow_planes_ssbo)

	shadow_planes_ssbo = rd.storage_buffer_create(total_bytes)

	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = 0
	u.add_id(shadow_planes_ssbo)

	us2_shadow_planes = rd.uniform_set_create([u], shader_light, 2)
	
func _update_shadow_planes_ssbo() -> int:
	var nodes := get_tree().get_nodes_in_group("rd_shadow_planes")
	var count := 0

	var data := PackedByteArray()
	data.resize(MAX_SHADOW_PLANES * 48)

	for n in nodes:
		if count >= MAX_SHADOW_PLANES:
			break
		if not n.has_method("get_shadow_plane_gpu_data"):
			continue

		var d: Dictionary = n.call("get_shadow_plane_gpu_data")
		if d.get("enabled", true) == false:
			continue

		var ct: Transform2D = get_viewport().canvas_transform

		var center_world: Vector3 = d["center"]
		var center_screen: Vector2 = ct * Vector2(center_world.x, center_world.y)
		var center_internal: Vector2 = _screen_to_internal(center_screen)

		var center := Vector3(
			center_internal.x,
			center_internal.y * 1.5,
			center_world.z / SIN_T
		)

		var axis_u: Vector3 = d["axis_u"].normalized()
		var axis_v: Vector3 = d["axis_v"].normalized()

		var half_size: Vector2 = d["half_size"]

		var half_u := half_size.x * sqrt(
			axis_u.x * axis_u.x +
			axis_u.y * axis_u.y +
			(axis_u.z / SIN_T) * (axis_u.z / SIN_T)
		)

		var half_v := half_size.y * sqrt(
			axis_v.x * axis_v.x +
			axis_v.y * axis_v.y +
			(axis_v.z / SIN_T) * (axis_v.z / SIN_T)
		)

		var two_sided: float = 1.0 if bool(d.get("two_sided", true)) else 0.0

		var base := count * 48
		_write_vec4(data, base + 0,  Vector4(center.x, center.y, center.z, two_sided))
		_write_vec4(data, base + 16, Vector4(axis_u.x, axis_u.y, axis_u.z, half_u))
		_write_vec4(data, base + 32, Vector4(axis_v.x, axis_v.y, axis_v.z, half_v))

		count += 1

	rd.buffer_update(shadow_planes_ssbo, 0, data.size(), data)
	return count

func _load_pipelines_and_sets() -> void:
	shader_clear = rd.shader_create_from_spirv(clear_rdshader.get_spirv())
	shader_draw = rd.shader_create_from_spirv(draw_rdshader.get_spirv())
	shader_light = rd.shader_create_from_spirv(light_rdshader.get_spirv())

	pipe_clear = rd.compute_pipeline_create(shader_clear)
	pipe_draw = rd.compute_pipeline_create(shader_draw)
	pipe_light = rd.compute_pipeline_create(shader_light)

	# set=0 bindings used by clear/draw/light (depth/color/normal/lit)
	var u0 := RDUniform.new()
	u0.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u0.binding = 0
	u0.add_id(depth_rid)

	var u1 := RDUniform.new()
	u1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u1.binding = 1
	u1.add_id(color_rid)

	var u2 := RDUniform.new()
	u2.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u2.binding = 2
	u2.add_id(normal_rid)

	var u3 := RDUniform.new()
	u3.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u3.binding = 3
	u3.add_id(lit_rid)

	us0_clear = rd.uniform_set_create([u0, u1, u2, u3], shader_clear, 0)
	us0_draw  = rd.uniform_set_create([u0, u1, u2],      shader_draw,  0)

	# Lighting needs all 4
	us0_light = rd.uniform_set_create([u0, u1, u2, u3], shader_light, 0)

	_create_lights_ssbo_and_set()
	_create_shadow_planes_ssbo_and_set()

# ----------------------------
# Dispatch
# ----------------------------

func _dispatch_clear() -> void:
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipe_clear)
	rd.compute_list_bind_uniform_set(cl, us0_clear, 0)

	# Push constant for clear shader:
	# ivec2 size padded to 16 bytes => 4 int32
	var pc_i := PackedInt32Array([internal_size.x, internal_size.y, 0, 0])
	var pc_bytes: PackedByteArray = pc_i.to_byte_array()
	rd.compute_list_set_push_constant(cl, pc_bytes, pc_bytes.size())

	var gx: int = int(ceil(float(internal_size.x) / 8.0))
	var gy: int = int(ceil(float(internal_size.y) / 8.0))
	rd.compute_list_dispatch(cl, gx, gy, 1)
	rd.compute_list_end()


func _dispatch_draw_sprite(s: Sprite2D) -> void:
	var tex: Texture2D = s.texture
	if tex == null:
		return
	
	# Upload/cache RD textures (you cannot bind Texture2D.get_rid() directly to RD compute)
	var albedo_rid: RID = _get_rd_texture_rgba8(tex)

	var htex: Texture2D = s.get("height_tex") as Texture2D
	var height_rid: RID = dummy_height_rid
	if htex != null:
		height_rid = _get_rd_texture_r8(htex)
		
	var ntex: Texture2D = s.get("normal_tex") as Texture2D
	var normal_tex_rid: RID = default_normal_rid # 1x1 (0.5,0.5,1)
	if ntex != null:
		normal_tex_rid = _get_rd_texture_rgba8(ntex)

	# ----- Sprite2D sheet/frame info -----
	var hf: int = max(1, s.hframes)
	var vf: int = max(1, s.vframes)

	var frame_i: int = s.frame
	if frame_i < 0:
		frame_i = 0

	var frame_x: int = frame_i % hf
	var frame_y: int = frame_i / hf
	if frame_y >= vf:
		frame_y = vf - 1

	var sheet_px: Vector2i = Vector2i(int(tex.get_width()), int(tex.get_height()))
	# Frame pixel size on the sheet
	var frame_px: Vector2 = Vector2(float(sheet_px.x) / float(hf), float(sheet_px.y) / float(vf))

	# ----- Compute screen-space rect for the *frame* (not the whole sheet) -----
	var ct: Transform2D = get_viewport().canvas_transform
	var pos_screen: Vector2 = ct * s.global_position
	pos_screen = _screen_to_internal(pos_screen)

	var sc: Vector2 = s.global_transform.get_scale()
	var size_px: Vector2 = frame_px * sc
	size_px = _delta_to_internal(size_px)

	var top_left: Vector2 = pos_screen
	if s.centered:
		top_left -= size_px * 0.5
	top_left += s.offset * sc

	var spr_pos := Vector2i(floor(top_left.x), floor(top_left.y))
	var spr_size := Vector2i(max(1, int(round(size_px.x))), max(1, int(round(size_px.y))))

	# Quick reject
	if spr_pos.x >= internal_size.x or spr_pos.y >= internal_size.y:
		return
	if spr_pos.x + spr_size.x <= 0 or spr_pos.y + spr_size.y <= 0:
		return

	var base_d: float = 0.0

	# set=1: samplers (albedo + height)
	var u_alb := RDUniform.new()
	u_alb.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_alb.binding = 0
	u_alb.add_id(sampler_rid)
	u_alb.add_id(albedo_rid)

	var u_h := RDUniform.new()
	u_h.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_h.binding = 1
	u_h.add_id(sampler_rid)
	u_h.add_id(height_rid)
	
	var u_n := RDUniform.new()
	u_n.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_n.binding = 2
	u_n.add_id(sampler_rid)
	u_n.add_id(normal_tex_rid)

	var us1_tex: RID = rd.uniform_set_create([u_alb, u_h, u_n], shader_draw, 1)

	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipe_draw)
	rd.compute_list_bind_uniform_set(cl, us0_draw, 0)
	rd.compute_list_bind_uniform_set(cl, us1_tex, 1)

	# Push constants for draw shader (64 bytes total):
	# ivec2 out_size; ivec2 spr_pos; ivec2 spr_size;
	# ivec2 sheet_px; ivec2 frames; ivec2 frame_xy;
	# float base_depth; float height_scale; padding
	var pc_i2 := PackedInt32Array([
		internal_size.x, internal_size.y,
		spr_pos.x, spr_pos.y,
		spr_size.x, spr_size.y,
		sheet_px.x, sheet_px.y,
		hf, vf,
		frame_x, frame_y
	])
	var pc_f := PackedFloat32Array([base_d, height_scale])

	var bytes := PackedByteArray()
	bytes.append_array(pc_i2.to_byte_array())  # 12 ints = 48 bytes
	bytes.append_array(pc_f.to_byte_array())   # 2 floats = 8 bytes => 56
	# pad to 64 bytes (2 more int32)
	bytes.append_array(PackedInt32Array([0, 0]).to_byte_array())  # +8 => 64

	rd.compute_list_set_push_constant(cl, bytes, bytes.size())

	var gx: int = int(ceil(float(spr_size.x) / 8.0))
	var gy: int = int(ceil(float(spr_size.y) / 8.0))
	rd.compute_list_dispatch(cl, gx, gy, 1)
	rd.compute_list_end()

	rd.free_rid(us1_tex)

func _dispatch_lighting(light_count: int, plane_count: int) -> void:
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipe_light)
	rd.compute_list_bind_uniform_set(cl, us0_light, 0)
	rd.compute_list_bind_uniform_set(cl, us1_lights, 1)
	rd.compute_list_bind_uniform_set(cl, us2_shadow_planes, 2)

	var pc := PackedByteArray()
	pc.resize(32)

	pc.encode_s32(0, internal_size.x)
	pc.encode_s32(4, internal_size.y)
	pc.encode_s32(8, light_count)
	pc.encode_s32(12, plane_count)
	pc.encode_float(16, 0.2)
	pc.encode_float(20, 0.0)
	pc.encode_float(24, 0.0)
	pc.encode_float(28, 0.0)

	rd.compute_list_set_push_constant(cl, pc, pc.size())

	var gx := int((internal_size.x + 7) / 8)
	var gy := int((internal_size.y + 7) / 8)
	rd.compute_list_dispatch(cl, gx, gy, 1)
	rd.compute_list_end()

# ----------------------------
# Texture upload helpers
# ----------------------------

func _get_rd_texture_rgba8(tex: Texture2D) -> RID:
	if _rd_albedo_cache.has(tex):
		return _rd_albedo_cache[tex] as RID

	var img: Image = tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var bytes: PackedByteArray = img.get_data()

	var tf := RDTextureFormat.new()
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = img.get_width()
	tf.height = img.get_height()
	tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT

	var rid: RID = rd.texture_create(tf, RDTextureView.new(), [bytes])
	_rd_albedo_cache[tex] = rid
	return rid


func _get_rd_texture_r8(tex: Texture2D) -> RID:
	if _rd_height_cache.has(tex):
		return _rd_height_cache[tex] as RID

	var img: Image = tex.get_image()
	# single-channel height (if your height is RGB grayscale, this still yields a usable L8)
	img.convert(Image.FORMAT_L8)
	var bytes: PackedByteArray = img.get_data()

	var tf := RDTextureFormat.new()
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = img.get_width()
	tf.height = img.get_height()
	tf.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT

	var rid: RID = rd.texture_create(tf, RDTextureView.new(), [bytes])
	_rd_height_cache[tex] = rid
	return rid


# ----------------------------
# Utilities
# ----------------------------

func _base_depth_from_y(y: float) -> float:
	var denom: float = (y_max - y_min)
	if absf(denom) < 0.00001:
		denom = 1.0
	return clampf((y - y_min) / denom, 0.0, 1.0)


func _gather_sprites(root: Node) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Sprite2D:
			out.append(n as Sprite2D)
		for c in n.get_children():
			stack.append(c)
	return out


func _on_node_added(n: Node) -> void:
	if world != null and world.is_ancestor_of(n):
		_pending_rebuild = true


func _on_node_removed(n: Node) -> void:
	if world != null and world.is_ancestor_of(n):
		_pending_rebuild = true

static func _write_vec4(buf: PackedByteArray, off: int, v: Vector4) -> void:
	buf.encode_float(off + 0,  v.x)
	buf.encode_float(off + 4,  v.y)
	buf.encode_float(off + 8,  v.z)
	buf.encode_float(off + 12, v.w)
