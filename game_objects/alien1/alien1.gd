extends Enemy

enum State { IDLE, SWIMMING, CHARGING, DASHING }

@export var idle_speed: float = 40.0
@export var swim_duration: float = 0.6
@export var swim_speed: float = 120.0
@export var charge_duration: float = 0.8
@export var dash_duration: float = 0.6
@export var dash_speed: float = 500.0
@export var dash_damage: float = 25.0
@export var rotation_speed: float = 5.0
@export var charge_rotation_speed: float = 4.0
@export var dash_projection_length: float = 300.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var charge_light: PointLight2D = $ChargeLight
@onready var dash_hitbox: Area2D = $DashHitbox
@onready var dash_projection: Line2D = $DashProjection
@onready var bubble_particles: CPUParticles2D = $BubbleParticles

var _state := State.IDLE
var _timer: float = 0.0
var _dash_direction := Vector2.ZERO
var _idle_direction := Vector2.ZERO
var _idle_change_timer: float = 0.0
var _base_scale := Vector2.ONE
var _charge_tween: Tween
var _aggro_tween: Tween
const _AGGRO_COLOR := Color(1.0, 0.6, 0.6, 1.0)
const _NORMAL_COLOR := Color.WHITE

func _ready() -> void:
	super()
	_base_scale = sprite.scale
	charge_light.energy = 0.0
	dash_hitbox.monitoring = false
	dash_hitbox.body_entered.connect(_on_dash_hit)
	dash_projection.visible = false
	aggro_changed.connect(_on_aggro_changed)
	_pick_idle_direction()

func _physics_process(delta: float) -> void:
	if dead:
		velocity.y += 40.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		rotation += 0.3 * delta
		move_and_slide()
		return

	_timer -= delta

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.SWIMMING:
			_process_swimming(delta)
		State.CHARGING:
			_process_charging(delta)
		State.DASHING:
			_process_dashing(delta)

	# Rotate to face movement direction (not during charge — handled separately)
	if _state != State.CHARGING and velocity.length() > 10.0:
		var target_angle := velocity.angle()
		rotation = lerp_angle(rotation, target_angle, rotation_speed * delta)

	# Flip sprite when facing left
	var angle := wrapf(rotation, -PI, PI)
	sprite.flip_v = absf(angle) > PI / 2.0

	# Wave intensity based on state
	var target_wave := 0.0
	match _state:
		State.IDLE:
			target_wave = 0.5
		State.SWIMMING:
			target_wave = 1.0
		State.CHARGING:
			target_wave = 0.2
		State.DASHING:
			target_wave = 0.0
	var mat := sprite.material as ShaderMaterial
	if mat:
		var current: float = 1.0
		var param = mat.get_shader_parameter("intensity")
		if param != null:
			current = param
		mat.set_shader_parameter("intensity", lerpf(current, target_wave, 5.0 * delta))

	# Bubble emission scales with speed
	var spd := velocity.length()
	bubble_particles.emitting = spd > 15.0
	bubble_particles.amount = clampi(int(spd / 30.0), 2, 20)

	move_and_slide()

func _on_aggro_changed(is_aggressive: bool) -> void:
	if _aggro_tween:
		_aggro_tween.kill()
	_aggro_tween = create_tween()
	_aggro_tween.set_ease(Tween.EASE_IN_OUT)
	_aggro_tween.set_trans(Tween.TRANS_CUBIC)
	_aggro_tween.tween_property(sprite, "modulate", _AGGRO_COLOR if is_aggressive else _NORMAL_COLOR, 0.4)
	if is_aggressive and _state == State.IDLE:
		_start_swim()

func _pick_idle_direction() -> void:
	_idle_direction = Vector2.from_angle(randf() * TAU)
	_idle_change_timer = randf_range(2.0, 4.0)

func _process_idle(delta: float) -> void:
	_idle_change_timer -= delta
	if _idle_change_timer <= 0.0:
		_pick_idle_direction()
	velocity = velocity.move_toward(_idle_direction * idle_speed, 60.0 * delta)

func _start_swim() -> void:
	_state = State.SWIMMING
	_timer = swim_duration

func _start_charge() -> void:
	_state = State.CHARGING
	_timer = charge_duration
	velocity = Vector2.ZERO

	var player := _find_player()
	if player:
		_dash_direction = (player.global_position - global_position).normalized()
	else:
		_dash_direction = Vector2.from_angle(randf() * TAU)

	# Show projection line
	dash_projection.visible = true
	_update_projection(0.0)

	# Subtle stretch with exponential ease (slow start, fast end)
	if _charge_tween:
		_charge_tween.kill()
	_charge_tween = create_tween()
	_charge_tween.set_parallel(true)
	var stretch := _base_scale * Vector2(1.12, 0.9)
	_charge_tween.tween_property(sprite, "scale", stretch, charge_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	_charge_tween.tween_property(charge_light, "energy", 1.5, charge_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)

func _start_dash() -> void:
	_state = State.DASHING
	_timer = dash_duration
	velocity = _dash_direction * dash_speed
	dash_hitbox.monitoring = true
	dash_projection.visible = false

	if _charge_tween:
		_charge_tween.kill()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "scale", _base_scale, 0.2)
	tween.tween_property(charge_light, "energy", 0.3, dash_duration)

func _on_dash_hit(body: Node2D) -> void:
	if dead:
		return
	if body is Entity:
		body.take_damage(dash_damage)

func _process_swimming(delta: float) -> void:
	if not aggressive:
		_state = State.IDLE
		_pick_idle_direction()
		return

	var player := _find_player()
	if player:
		var to_player := (player.global_position - global_position).normalized()
		velocity = velocity.move_toward(to_player * swim_speed, 200.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 100.0 * delta)

	if _timer <= 0.0:
		_start_charge()

func _process_charging(delta: float) -> void:
	var player := _find_player()
	if player:
		_dash_direction = (player.global_position - global_position).normalized()

	# Rotate toward dash direction
	var target_angle := _dash_direction.angle()
	rotation = lerp_angle(rotation, target_angle, charge_rotation_speed * delta)

	# Update projection opacity and direction
	var charge_progress := 1.0 - (_timer / charge_duration)
	_update_projection(charge_progress)

	if _timer <= 0.0:
		_start_dash()

func _update_projection(progress: float) -> void:
	# Line is in local space; the node rotates, so point along local X
	var length := dash_projection_length * progress
	dash_projection.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0)])
	dash_projection.default_color = Color(1, 0.3, 0.2, 0.6 * progress)

func _process_dashing(_delta: float) -> void:
	if _timer <= 0.0:
		dash_hitbox.monitoring = false
		if aggressive:
			_start_swim()
		else:
			_state = State.IDLE
			_pick_idle_direction()

func _die() -> void:
	# Clean up charge/dash visuals
	if _charge_tween:
		_charge_tween.kill()
	if _aggro_tween:
		_aggro_tween.kill()
	charge_light.energy = 0.0
	bubble_particles.emitting = false
	dash_projection.visible = false
	dash_hitbox.monitoring = false
	sprite.scale = _base_scale
	sprite.modulate = _NORMAL_COLOR
	super()

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null
