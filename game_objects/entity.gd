class_name Entity
extends CharacterBody2D

signal died
signal health_changed(new_hp: float, max_hp: float)

@export var max_hp: float = 100.0
@export var bob_amplitude: float = 3.0
@export var bob_speed: float = 0.5

var hp: float
var _dead := false
var _bob_time: float = 0.0
var _bob_sprite: Node2D
var _bob_base_y: float

func _ready() -> void:
	hp = max_hp
	_bob_sprite = get_node_or_null("Sprite2D")
	if _bob_sprite:
		_bob_base_y = _bob_sprite.position.y
		_bob_time = randf() * TAU

func _process(delta: float) -> void:
	if _bob_sprite:
		_bob_time += delta
		_bob_sprite.position.y = _bob_base_y + sin(_bob_time * bob_speed * TAU) * bob_amplitude

func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	health_changed.emit(hp, max_hp)
	_flash_damage()
	if hp <= 0.0:
		hp = 0.0
		_dead = true
		_die()

func _flash_damage() -> void:
	if _bob_sprite:
		var tween := create_tween()
		tween.tween_property(_bob_sprite, "modulate", Color(1, 0.2, 0.2), 0.05)
		tween.tween_property(_bob_sprite, "modulate", Color.WHITE, 0.25)

func _die() -> void:
	died.emit()
	queue_free()
