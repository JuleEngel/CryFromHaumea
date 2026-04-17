extends Node2D

const CUTSCENE_MUSIC := preload("res://audio/music/exploration_track.ogg")
const CUTSCENE_ENV := preload("res://levels/cutscenes/cutscene_environment.tres")

@export var next_scene: PackedScene
@export_multiline var landing_text: String = ""

var _skip_pressed := false
var _finished := false
var _waiting_for_input := false
var _fade_overlay: ColorRect
var _music_player: AudioStreamPlayer

signal _pressed_continue

@onready var _submarine: Sprite2D = $Submarine
@onready var _landing_target: Marker2D = $LandingTarget
@onready var _landing_sound: AudioStreamPlayer = $LandingSoundPlayer
@onready var _skip_label: Label = $UI/SkipLabel
@onready var _subtitle_label: Label = $UI/SubtitleLabel
@onready var _subtitle_continue_label: Label = $UI/SubtitleContinueLabel


func _ready() -> void:
	# Start submarine off-screen at top
	_submarine.position = Vector2(_landing_target.position.x, -200)
	_create_fade_overlay()
	_create_world_environment()
	_start_label_pulse(_subtitle_continue_label)
	_start_music()
	_run_cutscene()


func _start_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = CUTSCENE_MUSIC
	_music_player.volume_db = -40.0
	add_child(_music_player)
	_music_player.play()
	create_tween().tween_property(_music_player, "volume_db", 0.0, 1.5)


func _run_cutscene() -> void:
	# Fade in from black
	create_tween().tween_property(_fade_overlay, "color:a", 0.0, 1.0)

	# Brief pause before descent
	await get_tree().create_timer(1.0).timeout

	# Play landing sound
	_landing_sound.play()

	# Animate submarine descending to landing target
	var tween := create_tween()
	tween.tween_property(_submarine, "position",
		_landing_target.position, 4.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

	# Show landing text pages
	await _show_landing_text()

	_go_to_next_scene()


func _show_landing_text() -> void:
	if landing_text.is_empty():
		return
	var pages := landing_text.split("\n\n")
	for page in pages:
		var text := page.strip_edges()
		if text.is_empty():
			continue
		_subtitle_label.text = text
		_fade_in_label(_subtitle_label)
		_fade_in_label(_subtitle_continue_label)
		await _wait_for_input()
		_subtitle_continue_label.visible = false
	_subtitle_label.visible = false


func _wait_for_input() -> void:
	_waiting_for_input = true
	await _pressed_continue
	_waiting_for_input = false


# -- Input ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not _waiting_for_input:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode != KEY_ESCAPE:
		_pressed_continue.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_pressed_continue.emit()
		get_viewport().set_input_as_handled()


# -- Fade helpers -----------------------------------------------------------

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
	tween.tween_property(_music_player, "volume_db", -40.0, 0.5)
	await tween.finished

	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
