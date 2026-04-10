extends Node2D

@export var speed: float = 150.0
@export var turn_speed: float = 2.0
@export var wobble_strength: float = 0.8
@export var wobble_frequency: float = 8.0
@export var lifetime: float = 5.0
@export var damage: float = 50.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var engine_particles: GPUParticles2D = $EngineParticles
@onready var explosion_particles: GPUParticles2D = $ExplosionParticles
@onready var hitbox: Area2D = $Hitbox

var _time: float = 0.0
var _alive := true

func _ready() -> void:
	sprite.scale = Vector2.ZERO
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.3)

	hitbox.body_entered.connect(_on_hit)
	get_tree().create_timer(lifetime).timeout.connect(_explode)

func _physics_process(delta: float) -> void:
	if not _alive:
		return

	_time += delta

	var target := get_global_mouse_position()
	var desired_angle := (target - global_position).angle()
	var wobble := sin(_time * wobble_frequency) * wobble_strength
	rotation = lerp_angle(rotation, desired_angle + wobble, turn_speed * delta)

	var movement := Vector2.from_angle(rotation) * speed * delta
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + movement, 4)
	var result := space_state.intersect_ray(query)
	if result:
		global_position = result.position
		_explode()
		return
	global_position += movement

func _on_hit(body: Node2D) -> void:
	if not _alive:
		return
	if body is Entity:
		body.take_damage(damage)
	_explode()

func _explode() -> void:
	if not _alive:
		return
	_alive = false
	sprite.visible = false
	engine_particles.emitting = false
	explosion_particles.emitting = true
	hitbox.set_deferred("monitoring", false)
	explosion_particles.finished.connect(queue_free)
