extends Node2D

@export var speed: float = 200.0
@export var damage: float = 15.0
@export var max_range: float = 500.0

@onready var hitbox: Area2D = $Hitbox
@onready var light: PointLight2D = $PointLight2D
@onready var line: Line2D = $Line2D

var _alive := true
var _traveled: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	hitbox.body_entered.connect(_on_hit)
	hitbox.set_deferred("monitoring", true)

func _physics_process(delta: float) -> void:
	if not _alive:
		return

	_time += delta
	var movement := Vector2.from_angle(rotation) * speed * delta
	global_position += movement
	_traveled += movement.length()

	# Glow pulse
	var pulse := 1.2 + 0.3 * sin(_time * 12.0)
	light.energy = pulse
	line.width = 4.0 + 1.5 * sin(_time * 15.0)

	# Update trail line
	var trail_length := 30.0
	line.points = PackedVector2Array([Vector2.ZERO, Vector2(-trail_length, 0)])

	if _traveled >= max_range:
		_dissipate()

func _on_hit(body: Node2D) -> void:
	if not _alive:
		return
	if body is Entity and body.is_in_group("player"):
		body.take_damage(damage)
		_dissipate()

func _dissipate() -> void:
	if not _alive:
		return
	_alive = false
	hitbox.set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
