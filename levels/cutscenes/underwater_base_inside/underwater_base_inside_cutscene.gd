extends Node2D

@export var next_scene: PackedScene

@export_group("Texts")
@export_multiline var text_1: String
@export_multiline var text_2: String
@export_multiline var text_3: String
@export_multiline var text_4: String

var _skip_pressed := false
var _finished := false
var _waiting_for_input := false
var _shaking := false

signal _pressed_continue

@onready var _background: Sprite2D = $Background
@onready var _background_flooded: Sprite2D = $BackgroundFlooded
@onready var _water_overlay: ColorRect = $UI/WaterOverlay
@onready var _alien_window: Sprite2D = $AlienWindow
@onready var _alien_inside: Sprite2D = $AlienInside
@onready var _camera: Camera2D = $Camera2D
@onready var _screen_target: Marker2D = $ScreenTarget
@onready var _sos_label: Label = $ScreenTarget/SOSLabel
@onready var _sos_continue_label: Label = $ScreenTarget/ContinueLabel
@onready var _subtitle_label: Label = $UI/SubtitleLabel
@onready var _subtitle_continue_label: Label = $UI/SubtitleContinueLabel
@onready var _skip_label: Label = $UI/SkipLabel
@onready var _ambiance_player: AudioStreamPlayer = $AmbiancePlayer
@onready var _sfx_player: AudioStreamPlayer = $SfxPlayer
@onready var _attack_player: AudioStreamPlayer = $AttackPlayer


func _ready() -> void:
	_background_flooded.visible = false
	_water_overlay.visible = false
	_alien_window.visible = false
	_alien_inside.visible = false
	_sos_label.visible = false
	_sos_continue_label.visible = false
	_subtitle_label.visible = false
	_subtitle_continue_label.visible = false
	_run_cutscene()


func _run_cutscene() -> void:
	# Start ambiance and light shaking (attacks on base)
	_ambiance_player.play()
	_start_attack_shaking()

	# Step 1 — Text 1: Arrived at station
	await _show_text_pages(text_1)

	# Step 2 — Alien boss appears at window
	await _step_alien_at_window()

	# Step 3 — Text 2: What is that at the window?
	await _show_text_pages(text_2)

	# Step 4 — Zoom to computer + SOS typewriter
	await _step_sos_message()

	# Step 5 — Text 3: Wait, this is the same message...
	await _show_text_pages(text_3)

	# Step 6 — Background changes, water floods, alien inside
	await _step_flooding()

	# Step 7 — Text 4: They're inside!
	await _show_text_pages(text_4)

	# Brief pause before transition
	_shaking = false
	await get_tree().create_timer(1.0).timeout

	_go_to_next_scene()


# -- Text display --------------------------------------------------------------

func _show_text_pages(full_text: String) -> void:
	if full_text.is_empty():
		return
	var pages := full_text.split("\n\n")
	for page in pages:
		var t := page.strip_edges()
		if t.is_empty():
			continue
		_subtitle_label.text = t
		_subtitle_label.visible = true
		_subtitle_continue_label.visible = true
		await _wait_for_input()
		_subtitle_continue_label.visible = false
	_subtitle_label.visible = false


# -- Alien at window -----------------------------------------------------------

func _step_alien_at_window() -> void:
	_attack_player.play()
	_alien_window.modulate.a = 0.0
	_alien_window.visible = true
	var tween := create_tween()
	tween.tween_property(_alien_window, "modulate:a", 1.0, 1.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished


# -- SOS message (zoom to monitor + typewriter) --------------------------------

func _step_sos_message() -> void:
	_subtitle_label.visible = false
	_subtitle_continue_label.visible = false

	_sos_label.visible = true

	# Zoom camera to the computer screen
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_camera, "global_position",
		_screen_target.global_position, 3.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_camera, "zoom",
		Vector2(2.5, 2.5), 3.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

	# Typewriter animation (same message as intro)
	_sfx_player.play()
	await _sos_label.play_typewriter()
	_sfx_player.stop()

	_sos_continue_label.visible = true
	await _sos_label.wait_for_input()
	_sos_continue_label.visible = false

	# Zoom back out
	var tween2 := create_tween().set_parallel(true)
	tween2.tween_property(_camera, "global_position",
		Vector2(960, 540), 2.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween2.tween_property(_camera, "zoom",
		Vector2.ONE, 2.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween2.finished


# -- Flooding sequence ---------------------------------------------------------

func _step_flooding() -> void:
	# Increase shaking intensity
	_attack_player.play()

	# Flash and switch background
	_background.visible = false
	_background_flooded.visible = true

	# Water overlay rises from bottom
	_water_overlay.visible = true
	_water_overlay.color = Color(0.0, 0.1, 0.3, 0.0)
	var tween := create_tween()
	tween.tween_property(_water_overlay, "color",
		Color(0.0, 0.1, 0.3, 0.5), 3.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# Alien disappears from window, appears inside
	await get_tree().create_timer(1.0).timeout
	_alien_window.visible = false

	_alien_inside.modulate.a = 0.0
	_alien_inside.visible = true
	var tween2 := create_tween()
	tween2.tween_property(_alien_inside, "modulate:a", 1.0, 1.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween2.finished


# -- Camera shake (intermittent attack rumbles) --------------------------------

func _start_attack_shaking() -> void:
	_shaking = true
	_do_attack_shake_loop()


func _do_attack_shake_loop() -> void:
	while _shaking:
		# Wait a random pause between rumbles
		var pause := randf_range(3.0, 7.0)
		await get_tree().create_timer(pause).timeout
		if not _shaking:
			break
		# Short burst of shaking
		var duration := randf_range(0.4, 1.0)
		var elapsed := 0.0
		while elapsed < duration and _shaking:
			var strength := randf_range(2.0, 5.0)
			_camera.offset = Vector2(
				randf_range(-strength, strength),
				randf_range(-strength, strength),
			)
			await get_tree().process_frame
			elapsed += get_process_delta_time()
		_camera.offset = Vector2.ZERO


# -- Input / skip --------------------------------------------------------------

func _wait_for_input() -> void:
	_waiting_for_input = true
	await _pressed_continue
	_waiting_for_input = false


func _input(event: InputEvent) -> void:
	if not _waiting_for_input:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_pressed_continue.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_pressed_continue.emit()
		get_viewport().set_input_as_handled()


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
