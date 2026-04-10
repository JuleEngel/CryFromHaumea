extends Enemy

enum State { IDLE, SWIMMING, CHARGING, DASHING }

@export var idle_speed: float = 40.0
@export var swim_duration: float = 3.0
@export var swim_speed: float = 120.0
@export var charge_duration: float = 1.2
@export var dash_duration: float = 2.5
@export var dash_speed: float = 500.0
@export var dash_damage: float = 25.0
@export var rotation_speed: float = 5.0
@export var charge_rotation_speed: float = 4.0
@export var dash_projection_length: float = 300.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var charge_light: PointLight2D = $ChargeLight
@onready var dash_hitbox: Area2D = $DashHitbox
@onready var dash_projection: Line2D = $DashProjection

var _state := State.IDLE
var _timer: float = 0.0
var _dash_direction := Vector2.ZERO
var _idle_direction := Vector2.ZERO
var _idle_change_timer: float = 0.0
var _base_scale := Vector2.ONE
var _charge_tween: Tween

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

	move_and_slide()

func _on_aggro_changed(is_aggressive: bool) -> void:
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

	var player := _find_player()
	if player:
		var to_player := (player.global_position - global_position).normalized()
		_idle_direction = (to_player + Vector2.from_angle(randf() * TAU) * 0.5).normalized()
	else:
		_idle_direction = Vector2.from_angle(randf() * TAU)

	velocity = _idle_direction * swim_speed

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
	if body is Entity:
		body.take_damage(dash_damage)

func _process_swimming(_delta: float) -> void:
	if not aggressive:
		_state = State.IDLE
		_pick_idle_direction()
		return
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

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null
