extends Node

var checkpoint_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false

func set_checkpoint(pos: Vector2) -> void:
	checkpoint_position = pos
	has_checkpoint = true

func clear() -> void:
	checkpoint_position = Vector2.ZERO
	has_checkpoint = false
