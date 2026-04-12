extends Enemy

enum State { IDLE, PURSUING, ZIGZAG_CHARGING, ZIGZAG_DASHING }

@export var idle_speed: float = 50.0
@export var pursue_speed: float = 1000.0
@export var pursue_duration: float = 0.8
@export var charge_duration: float = 0.35
@export var zigzag_dash_count: int = 4
@export var zigzag_dash_duration: float = 0.18
@export var zigzag_pause_duration: float = 0.08
@export var zigzag_dash_speed: float = 420.0
@export var zigzag_angle_offset: float = 0.55
@export var zigzag_damage: float = 8.0
@export var attack_range: float = 350.0
@export var rotation_speed: float = 6.0
@export var charge_rotation_speed: float = 5.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var dash_hitbox: Area2D = $DashHitbox
@onready var bubble_particles: CPUParticles2D = $BubbleParticles
@onready var dash_bubbles: CPUParticles2D = $DashBubbles
@onready var dash_sound: AudioStreamPlayer2D = $DashSound
@onready var detection_sound: AudioStreamPlayer2D = $DetectionSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound

var _state := State.IDLE
var _timer: float = 0.0
var _idle_direction := Vector2.ZERO
var _idle_change_timer: float = 0.0
var _base_scale := Vector2.ONE
var _aggro_tween: Tween
var _charge_tween: Tween

var _zigzag_remaining: int = 0
var _zigzag_up: bool = true
var _zigzag_pausing: bool = false
var _zigzag_base_dir := Vector2.ZERO

const _AGGRO_COLOR := Color(1.0, 0.75, 0.6, 1.0)
const _NORMAL_COLOR := Color.WHITE


func _ready() -> void:
	super()
	_base_scale = sprite.scale
	dash_hitbox.monitoring = false
	dash_hitbox.body_entered.connect(_on_dash_hit)
	aggro_changed.connect(_on_aggro_changed)
	_pick_idle_direction()


func _physics_process(delta: float) -> void:
	if dead:
		velocity.y += 40.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		rotation += 0.5 * delta
		move_and_slide()
		return

	_timer -= delta

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.PURSUING:
			_process_pursuing(delta)
		State.ZIGZAG_CHARGING:
			_process_charging(delta)
		State.ZIGZAG_DASHING:
			_process_zigzag(delta)

	if _state != State.ZIGZAG_CHARGING and velocity.length() > 10.0:
		var target_angle := velocity.angle()
		rotation = lerp_angle(rotation, target_angle, rotation_speed * delta)

	var angle := wrapf(rotation, -PI, PI)
	sprite.flip_v = absf(angle) > PI / 2.0

	var target_wave := 0.0
	match _state:
		State.IDLE:
			target_wave = 0.5
		State.PURSUING:
			target_wave = 1.0
		State.ZIGZAG_CHARGING:
			target_wave = 0.2
		State.ZIGZAG_DASHING:
			target_wave = 0.0 if not _zigzag_pausing else 0.3
	var mat := sprite.material as ShaderMaterial
	if mat:
		var current: float = 1.0
		var param = mat.get_shader_parameter("intensity")
		if param != null:
			current = param
		mat.set_shader_parameter("intensity", lerpf(current, target_wave, 5.0 * delta))

	var spd := velocity.length()
	bubble_particles.emitting = spd > 15.0
	bubble_particles.amount = clampi(int(spd / 25.0), 2, 24)

	move_and_slide()


func _on_aggro_changed(is_aggressive: bool) -> void:
	if _aggro_tween:
		_aggro_tween.kill()
	_aggro_tween = create_tween()
	_aggro_tween.set_ease(Tween.EASE_IN_OUT)
	_aggro_tween.set_trans(Tween.TRANS_CUBIC)
	_aggro_tween.tween_property(
		sprite, "modulate",
		_AGGRO_COLOR if is_aggressive else _NORMAL_COLOR, 0.4
	)
	if is_aggressive:
		detection_sound.pitch_scale = randf_range(0.9, 1.2)
		detection_sound.volume_db = randf_range(-3.0, 3.0)
		detection_sound.play()
	if is_aggressive and _state == State.IDLE:
		_start_pursue()


func _pick_idle_direction() -> void:
	_idle_direction = Vector2.from_angle(randf() * TAU)
	_idle_change_timer = randf_range(1.5, 3.0)


func _process_idle(delta: float) -> void:
	_idle_change_timer -= delta
	if _idle_change_timer <= 0.0:
		_pick_idle_direction()
	velocity = velocity.move_toward(_idle_direction * idle_speed, 80.0 * delta)


func _start_pursue() -> void:
	_state = State.PURSUING
	_timer = pursue_duration * randf_range(0.6, 1.5)


func _process_pursuing(delta: float) -> void:
	if not aggressive:
		_state = State.IDLE
		_pick_idle_direction()
		return

	var player := _find_player()
	if player:
		var to_player := (player.global_position - global_position).normalized()
		velocity = velocity.move_toward(to_player * pursue_speed, 250.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 100.0 * delta)

	if _timer <= 0.0:
		var close_enough := false
		if player:
			close_enough = global_position.distance_to(player.global_position) <= attack_range
		if close_enough:
			_start_charge()
		else:
			_timer = pursue_duration * randf_range(0.3, 0.6)


func _start_charge() -> void:
	_state = State.ZIGZAG_CHARGING
	_timer = charge_duration
	velocity *= 0.3

	var player := _find_player()
	if player:
		_zigzag_base_dir = (player.global_position - global_position).normalized()
	else:
		_zigzag_base_dir = Vector2.from_angle(randf() * TAU)

	if _charge_tween:
		_charge_tween.kill()
	_charge_tween = create_tween()
	var stretch := _base_scale * Vector2(1.15, 0.85)
	_charge_tween.tween_property(
		sprite, "scale", stretch, charge_duration
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)


func _process_charging(delta: float) -> void:
	var player := _find_player()
	if player:
		_zigzag_base_dir = (player.global_position - global_position).normalized()

	var target_angle := _zigzag_base_dir.angle()
	rotation = lerp_angle(rotation, target_angle, charge_rotation_speed * delta)
	velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)

	if _timer <= 0.0:
		_start_zigzag()


func _start_zigzag() -> void:
	_state = State.ZIGZAG_DASHING
	_zigzag_remaining = zigzag_dash_count
	_zigzag_up = randf() > 0.5
	_zigzag_pausing = false

	if _charge_tween:
		_charge_tween.kill()
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "scale", _base_scale, 0.15)

	_begin_next_dash()


func _begin_next_dash() -> void:
	if _zigzag_remaining <= 0:
		dash_hitbox.monitoring = false
		if aggressive:
			_start_pursue()
		else:
			_state = State.IDLE
			_pick_idle_direction()
		return

	_zigzag_pausing = false
	_timer = zigzag_dash_duration
	_zigzag_remaining -= 1

	var player := _find_player()
	if player:
		_zigzag_base_dir = (player.global_position - global_position).normalized()

	var offset := zigzag_angle_offset if _zigzag_up else -zigzag_angle_offset
	_zigzag_up = not _zigzag_up
	var dash_dir := _zigzag_base_dir.rotated(offset)

	velocity = dash_dir * zigzag_dash_speed
	dash_hitbox.monitoring = true
	dash_bubbles.emitting = true
	dash_sound.pitch_scale = randf_range(1.0, 1.4)
	dash_sound.volume_db = randf_range(-6.0, 0.0)
	dash_sound.play()


func _process_zigzag(delta: float) -> void:
	if _zigzag_pausing:
		velocity = velocity.move_toward(Vector2.ZERO, 2000.0 * delta)
		if _timer <= 0.0:
			_begin_next_dash()
	else:
		if _timer <= 0.0:
			dash_hitbox.monitoring = false
			_zigzag_pausing = true
			_timer = zigzag_pause_duration
			velocity *= 0.2


func _on_dash_hit(body: Node2D) -> void:
	if dead:
		return
	if body is Entity:
		body.take_damage(zigzag_damage)


func _die() -> void:
	if _charge_tween:
		_charge_tween.kill()
	if _aggro_tween:
		_aggro_tween.kill()
	bubble_particles.emitting = false
	death_sound.pitch_scale = randf_range(0.9, 1.2)
	death_sound.volume_db = randf_range(-3.0, 3.0)
	death_sound.play()
	dash_hitbox.monitoring = false
	sprite.scale = _base_scale
	sprite.modulate = _NORMAL_COLOR
	super()


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null
