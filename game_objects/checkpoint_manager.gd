extends Node

var checkpoint_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false
var facing_left: bool = false
var target_direction: Vector2 = Vector2.ZERO

func set_checkpoint(pos: Vector2, flip_h: bool, target_dir: Vector2) -> void:
	checkpoint_position = pos
	has_checkpoint = true
	facing_left = flip_h
	target_direction = target_dir

func clear() -> void:
	checkpoint_position = Vector2.ZERO
	has_checkpoint = false
	facing_left = false
	target_direction = Vector2.ZERO
