extends Node2D

@export var next_scene: PackedScene
@export_multiline var landing_text: String = ""

var _skip_pressed := false
var _finished := false
var _waiting_for_input := false

signal _pressed_continue

@onready var _submarine: Sprite2D = $Submarine
@onready var _landing_target: Marker2D = $LandingTarget
@onready var _camera: Camera2D = $Camera2D
@onready var _landing_sound: AudioStreamPlayer = $LandingSoundPlayer
@onready var _skip_label: Label = $UI/SkipLabel
@onready var _subtitle_label: Label = $UI/SubtitleLabel
@onready var _subtitle_continue_label: Label = $UI/SubtitleContinueLabel


func _ready() -> void:
	# Start submarine off-screen at top
	_submarine.position = Vector2(_landing_target.position.x, -200)
	_run_cutscene()


func _run_cutscene() -> void:
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
		_subtitle_label.visible = true
		_subtitle_continue_label.visible = true
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
	if event is InputEventKey and event.pressed and not event.echo:
		_pressed_continue.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_pressed_continue.emit()
		get_viewport().set_input_as_handled()


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
