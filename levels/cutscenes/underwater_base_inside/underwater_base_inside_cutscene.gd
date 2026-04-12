extends Node2D

const COMBAT_MUSIC := preload("res://audio/music/synthwave_combat.mp3")
const CUTSCENE_ENV := preload("res://levels/cutscenes/cutscene_environment.tres")

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
var _fade_overlay: ColorRect
var _music_player: AudioStreamPlayer

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
	_create_fade_overlay()
	_create_world_environment()
	_start_label_pulse(_subtitle_continue_label)
	_start_label_pulse(_sos_continue_label)
	_start_music()
	_run_cutscene()


func _start_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = COMBAT_MUSIC
	_music_player.volume_db = -40.0
	add_child(_music_player)
	_music_player.play()
	create_tween().tween_property(_music_player, "volume_db", 0.0, 1.5)


func _run_cutscene() -> void:
	# Fade in from black
	create_tween().tween_property(_fade_overlay, "color:a", 0.0, 0.4)
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
		_fade_in_label(_subtitle_label)
		_fade_in_label(_subtitle_continue_label)
		await _wait_for_input()
		_subtitle_continue_label.visible = false
	_subtitle_label.visible = false


# -- Alien at window -----------------------------------------------------------

func _step_alien_at_window() -> void:
	_attack_player.play()
	_alien_window.modulate.a = 0.0
	_alien_window.visible = true
	var tween := create_tween()
	tween.tween_property(_alien_window, "modulate:a", 1.0, 0.5) \
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
		_screen_target.global_position, 1.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_camera, "zoom",
		Vector2(2.5, 2.5), 1.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

	# Typewriter animation (same message as intro)
	_sfx_player.play()
	await _sos_label.play_typewriter()
	_sfx_player.stop()

	_fade_in_label(_sos_continue_label)
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
		Color(0.0, 0.1, 0.3, 0.5), 1.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# Alien disappears from window, appears inside
	await get_tree().create_timer(1.0).timeout
	_alien_window.visible = false

	_alien_inside.modulate.a = 0.0
	_alien_inside.visible = true
	var tween2 := create_tween()
	tween2.tween_property(_alien_inside, "modulate:a", 1.0, 0.5) \
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode != KEY_ESCAPE:
		_pressed_continue.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_pressed_continue.emit()
		get_viewport().set_input_as_handled()


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


func _create_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color.BLACK
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_fade_overlay)


func _create_world_environment() -> void:
	var we := WorldEnvironment.new()
	we.environment = CUTSCENE_ENV
	add_child(we)


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


func _go_to_next_scene() -> void:
	if _finished:
		return
	_finished = true

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_fade_overlay, "color:a", 1.0, 0.5)
	tween.tween_property(_music_player, "volume_db", -40.0, 0.5)
	await tween.finished

	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
