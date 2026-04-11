extends Node2D

@export var duration: float = 30.0
@export var next_scene: PackedScene

@export var planet_start_scale := Vector2(0.35, 0.35)
@export var planet_end_scale := Vector2(1.5, 1.5)

var _skip_pressed := false
var _finished := false

@onready var _planet: Sprite2D = $PlanetUniverse
@onready var _skip_label: Label = $UI/SkipLabel


func _ready() -> void:
	_planet.scale = planet_start_scale

	var tween := create_tween()
	tween.tween_property(_planet, "scale", planet_end_scale, duration).set_ease(Tween.EASE_IN)
	tween.tween_callback(_go_to_next_scene)


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
