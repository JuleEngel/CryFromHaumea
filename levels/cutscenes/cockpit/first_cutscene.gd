extends Node2D

@export var next_scene: PackedScene

@export_group("Audio")
## Voiceline: "Such a headache... don't remember..."
@export var headache_audio: AudioStream
## Radio/SOS response voiceline
@export var radio_audio: AudioStream
## Modem sound during SOS typewriter
@export var modem_audio: AudioStream
## Engine rumble during planet approach
@export var engine_audio: AudioStream

@export_group("Subtitles")
@export_multiline var radio_subtitle: String = "Ein neuer Tag im Weltraum. Ein neuer Tag im Kuiper-Gürtel."
@export_multiline var radio_subtitle_2: String = "Ein"

var _skip_pressed := false
var _finished := false
var _fade_overlay: ColorRect

@onready var _universe: Sprite2D = $UniversePure
@onready var _planet: Sprite2D = $PlanetPure
@onready var _camera: Camera2D = $Camera2D
@onready var _screen_target: Marker2D = $ScreenTarget
@onready var _sos_label: Label = $ScreenTarget/SOSLabel
@onready var _continue_label: Label = $ScreenTarget/ContinueLabel
@onready var _subtitle_label: Label = $UI/SubtitleLabel
@onready var _subtitle_continue_label: Label = $UI/SubtitleContinueLabel
@onready var _skip_label: Label = $UI/SkipLabel
@onready var _voice_player: AudioStreamPlayer = $VoicePlayer
@onready var _engine_player: AudioStreamPlayer = $EnginePlayer
@onready var _music: AudioStreamPlayer = $Music


func _ready() -> void:
	_sos_label.visible = false
	_subtitle_label.visible = false
	_create_fade_overlay()
	_start_label_pulse(_continue_label)
	_start_label_pulse(_subtitle_continue_label)
	_run_cutscene()


func _run_cutscene() -> void:
	# Fade in from black (runs concurrently with stars drift)
	create_tween().tween_property(_fade_overlay, "color:a", 0.0, 1.0)
	# Step 1 — cockpit + stars, stars drift slightly larger
	await _step_stars_drift()
	# Step 2 — headache voiceline
	await _step_headache_voiceline()
	# Step 3 — radio response with subtitles
	await _step_radio_message()
	# Step 4 — SOS on screen + camera zoom to cockpit monitor
	await _step_sos_message()
	# Step 5 — radio response with subtitles
	await _step_radio_message_2()
	# Step 6 — pan universe & planet into view
	await _step_move_to_planet()
	# Step 7 — planet grows (slow then fast) + engine audio
	await _step_approach_planet()

	_go_to_next_scene()


# -- Steps -----------------------------------------------------------------

func _step_stars_drift() -> void:
	var end_scale := _universe.scale * 1.03
	var tween := create_tween()
	tween.tween_property(_universe, "scale", end_scale, 5.0) \
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _step_headache_voiceline() -> void:
	if headache_audio:
		_voice_player.stream = headache_audio
		_voice_player.play()
		await _voice_player.finished
	else:
		await get_tree().create_timer(2.0).timeout


func _step_sos_message() -> void:
	_sos_label.visible = true

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_camera, "global_position",
		_screen_target.global_position, 3.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_camera, "zoom",
		Vector2(1.8, 1.8), 3.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

	if modem_audio:
		_voice_player.stream = modem_audio
		_voice_player.play()
	await _sos_label.play_typewriter()
	_voice_player.stop()
	_fade_in_label(_continue_label)
	await _sos_label.wait_for_input()
	_continue_label.visible = false


func _step_radio_message() -> void:
	await _show_radio_pages(radio_subtitle, radio_audio)


func _step_radio_message_2() -> void:
	await _show_radio_pages(radio_subtitle_2, radio_audio)


func _show_radio_pages(full_text: String, audio: AudioStream = null) -> void:
	var pages := full_text.split("\n\n")
	for i in pages.size():
		var page := pages[i].strip_edges()
		if page.is_empty():
			continue
		_subtitle_label.text = page
		_fade_in_label(_subtitle_label)

		if i == 0 and audio:
			_voice_player.stream = audio
			_voice_player.play()
			await _voice_player.finished

		_fade_in_label(_subtitle_continue_label)
		await _sos_label.wait_for_input()
		_subtitle_continue_label.visible = false
	_subtitle_label.visible = false


func _step_move_to_planet() -> void:
	_sos_label.visible = false

	var center := Vector2(960, 540)
	# Keep planet at the same offset relative to the universe
	var offset := _planet.position - _universe.position
	var universe_target := center - offset

	var tween := create_tween().set_parallel(true)
	# Zoom camera back out
	tween.tween_property(_camera, "global_position", center, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_camera, "zoom", Vector2.ONE, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	# Slide universe + planet together, planet lands at center
	tween.tween_property(_universe, "position", universe_target, 3.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_planet, "position", center, 3.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished


func _step_approach_planet() -> void:
	if engine_audio:
		_engine_player.stream = engine_audio
		_engine_player.play()

	_shake_camera(12.0, 2.0, 12.0)

	# Exponential ease-in: slow at first, then accelerates
	var tween := create_tween()
	tween.tween_property(_planet, "scale", Vector2(4.0, 4.0), 12.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	await tween.finished
	_camera.offset = Vector2.ZERO


# -- Camera shake -----------------------------------------------------------

func _shake_camera(duration: float, min_strength: float, max_strength: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		var t := elapsed / duration
		var strength := lerpf(min_strength, max_strength, t * t)
		_camera.offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength),
		)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_camera.offset = Vector2.ZERO


# -- Fade helpers -----------------------------------------------------------

func _create_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color.BLACK
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_fade_overlay)


func _fade_in_label(label: Control) -> void:
	label.modulate.a = 0.0
	label.visible = true
	create_tween().tween_property(label, "modulate:a", 1.0, 0.3)


func _start_label_pulse(label: Label) -> void:
	var base_color := Color(0.7, 0.7, 0.7, 1.0)
	var pulse_color := Color(1.0, 0.85, 0.2, 1.0)
	var tween := create_tween().set_loops()
	tween.tween_property(label, "theme_override_colors/font_color", pulse_color, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "theme_override_colors/font_color", base_color, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


# -- Skip / navigation ------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		return

	if _skip_pressed:
		_go_to_next_scene()
	else:
		_skip_pressed = true
		_skip_label.visible = true
		get_tree().create_timer(1.5).timeout.connect(_reset_skip)


func _reset_skip() -> void:
	_skip_pressed = false
	_skip_label.visible = false


func _go_to_next_scene() -> void:
	if _finished:
		return
	_finished = true

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_fade_overlay, "color:a", 1.0, 0.5)
	tween.tween_property(_music, "volume_db", -40.0, 0.5)
	await tween.finished

	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
