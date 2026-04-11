extends Node2D

@export var speed: float = 250.0
@export var turn_speed: float = 2.0
@export var wobble_strength: float = 0.8
@export var wobble_frequency: float = 8.0
@export var lifetime: float = 5.0
@export var damage: float = 20.0
@export var eject_speed: float = 160.0
@export var eject_duration: float = 0.35

@onready var sprite: Sprite2D = $Sprite2D
@onready var engine_particles: GPUParticles2D = $EngineParticles
@onready var explosion_particles: GPUParticles2D = $ExplosionParticles
@onready var hitbox: Area2D = $Hitbox
@onready var trajectory_line: Line2D = $TrajectoryLine
@onready var bubble_particles: CPUParticles2D = $BubbleParticles

var _time: float = 0.0
var _alive := true
var _powered := false
var _eject_timer: float = 0.0

func _ready() -> void:
	sprite.scale = Vector2.ZERO
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "scale", Vector2.ONE * .5, 0.3)

	# Start unpowered: no engine, no hitbox
	engine_particles.emitting = false
	bubble_particles.emitting = false
	hitbox.set_deferred("monitoring", false)
	_eject_timer = eject_duration

	get_tree().create_timer(lifetime).timeout.connect(_explode)

func _physics_process(delta: float) -> void:
	if not _alive:
		return

	_time += delta

	if not _powered:
		# Eject phase: drift upward, decelerating
		_eject_timer -= delta
		var eject_progress := 1.0 - (_eject_timer / eject_duration)
		var eject_spd := eject_speed * (1.0 - eject_progress)
		global_position += Vector2.from_angle(rotation) * eject_spd * delta

		if _eject_timer <= 0.0:
			_power_up()
		return

	# Powered phase: home toward mouse
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
	_update_trajectory()

func _power_up() -> void:
	_powered = true
	engine_particles.emitting = true
	bubble_particles.emitting = true
	hitbox.body_entered.connect(_on_hit)
	hitbox.set_deferred("monitoring", true)
	trajectory_line.visible = true

func _update_trajectory() -> void:
	var target := get_global_mouse_position()
	var sim_pos := global_position
	var sim_rot := rotation
	var sim_time := _time
	var sim_dt := 1.0 / 60.0
	var steps := 60

	var points := PackedVector2Array()
	points.append(sim_pos)
	var close_enough := speed * sim_dt * 2.0
	for i in steps:
		sim_time += sim_dt
		var desired := (target - sim_pos).angle()
		var wobble := sin(sim_time * wobble_frequency) * wobble_strength
		sim_rot = lerp_angle(sim_rot, desired + wobble, turn_speed * sim_dt)
		sim_pos += Vector2.from_angle(sim_rot) * speed * sim_dt
		points.append(sim_pos)
		if sim_pos.distance_to(target) < close_enough:
			break
	points.append(target)
	trajectory_line.points = points

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
	engine_particles.emitting = false
	bubble_particles.emitting = false
	explosion_particles.emitting = true
	trajectory_line.clear_points()
	hitbox.set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): sprite.visible = false)
	explosion_particles.finished.connect(queue_free)
