extends Node2D

@export var next_scene: PackedScene

var _skip_pressed := false
var _finished := false

@onready var _skip_label: Label = $UI/SkipLabel


func _ready() -> void:
	_run_cutscene()


func _run_cutscene() -> void:
	await get_tree().create_timer(3.0).timeout
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
