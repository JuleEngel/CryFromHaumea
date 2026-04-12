extends Node2D

@export var next_scene: PackedScene

var _skip_pressed := false
var _finished := false

@onready var _submarine: Sprite2D = $Submarine
@onready var _landing_target: Marker2D = $LandingTarget
@onready var _camera: Camera2D = $Camera2D
@onready var _skip_label: Label = $UI/SkipLabel
@onready var _dive_player: AudioStreamPlayer = $DiveSoundPlayer


func _ready() -> void:
	#_submarine.position = Vector2(1800, 200)
	_run_cutscene()


func _run_cutscene() -> void:
	await get_tree().create_timer(0.5).timeout

	_dive_player.play()

	# Animate submarine descending to the base
	var tween := create_tween()
	tween.tween_property(_submarine, "position",
		_landing_target.position, 5.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(_submarine, "scale",
		Vector2.ONE * 0.6, 5.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

	await get_tree().create_timer(1.0).timeout

	_go_to_next_scene()


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
