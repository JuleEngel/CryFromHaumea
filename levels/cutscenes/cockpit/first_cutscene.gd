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
@export_multiline var radio_subtitle: String = "[SOS-Antwort - Platzhalter]"

var _skip_pressed := false
var _finished := false

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


func _ready() -> void:
	_sos_label.visible = false
	_subtitle_label.visible = false
	_run_cutscene()


func _run_cutscene() -> void:
	# Step 1 — cockpit + stars, stars drift slightly larger
	await _step_stars_drift()
	# Step 2 — headache voiceline
	await _step_headache_voiceline()
	# Step 3 — SOS on screen + camera zoom to cockpit monitor
	await _step_sos_message()
	# Step 4 — radio response with subtitles
	await _step_radio_message()
	# Step 5 — pan universe & planet into view
	await _step_move_to_planet()
	# Step 6 — planet grows (slow then fast) + engine audio
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
	_continue_label.visible = true
	await _sos_label.wait_for_input()
	_continue_label.visible = false


func _step_radio_message() -> void:
	_subtitle_label.text = radio_subtitle
	_subtitle_label.visible = true

	if radio_audio:
		_voice_player.stream = radio_audio
		_voice_player.play()
		await _voice_player.finished

	_subtitle_continue_label.visible = true
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


# -- Skip / navigation ------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
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

	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
