extends AudioStreamPlayer

@export var main_index: int = 0
@export var nes_index: int = 1
@export var fade_time: float = 0.75

var pb: AudioStreamPlaybackInteractive
var nes_enabled: bool = false
var fade_tween: Tween

func _ready() -> void:
	play()
	pb = get_stream_playback() as AudioStreamPlaybackInteractive
	_apply_mix_immediate(false)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("music_nes_on"):
		set_nes_mode(true)
	elif Input.is_action_just_pressed("music_nes_off"):
		set_nes_mode(false)

func set_nes_mode(enabled: bool) -> void:
	if nes_enabled == enabled:
		return

	nes_enabled = enabled

	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()

	var start_mix: float = 1.0 if enabled == false else 0.0
	var end_mix: float = 1.0 if enabled else 0.0

	fade_tween = create_tween()
	fade_tween.tween_method(_set_nes_mix, start_mix, end_mix, fade_time)

func _set_nes_mix(nes_mix: float) -> void:
	var interactive: AudioStreamInteractive = stream as AudioStreamInteractive
	if interactive == null:
		return

	# Apply the same mix to every synchronized clip in the interactive stream,
	# so the currently playing section and the next section stay consistent.
	for i in range(interactive.clip_count):
		var clip_stream: AudioStream = interactive.get_clip_stream(i)
		var sync_stream: AudioStreamSynchronized = clip_stream as AudioStreamSynchronized
		if sync_stream == null:
			continue

		var main_db: float = linear_to_db(1.0 - nes_mix)
		var nes_db: float = linear_to_db(nes_mix)

		sync_stream.set_sync_stream_volume(main_index, main_db)
		sync_stream.set_sync_stream_volume(nes_index, nes_db)

func _apply_mix_immediate(enabled: bool) -> void:
	var nes_mix: float = 1.0 if enabled else 0.0
	_set_nes_mix(nes_mix)
