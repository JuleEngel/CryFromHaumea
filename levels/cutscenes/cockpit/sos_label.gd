extends Label

@export var chars_per_second: float = 20.0

var _waiting_for_input := false


func _ready() -> void:
	visible_characters = 0


func play_typewriter() -> void:
	visible_characters = 0
	var total := text.length()
	var tween := create_tween()
	tween.tween_property(self, "visible_characters", total, total / chars_per_second)
	await tween.finished


func wait_for_input() -> void:
	_waiting_for_input = true
	await pressed_continue
	_waiting_for_input = false


signal pressed_continue


func _input(event: InputEvent) -> void:
	if not _waiting_for_input:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode != KEY_ESCAPE:
		pressed_continue.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		pressed_continue.emit()
		get_viewport().set_input_as_handled()
