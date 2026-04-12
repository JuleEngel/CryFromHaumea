extends Enemy

enum State { IDLE, PURSUING, LASER_SHOOTING, STUN_CHARGING, STUN_RELEASING }

@export var idle_speed: float = 25.0
@export var pursue_speed: float = 200.0
# Laser
@export var laser_cooldown: float = 1.5
@export var laser_damage: float = 15.0
@export var laser_speed: float = 450.0
@export var laser_count: int = 3
@export var laser_range: float = 800.0

# Stun wave
@export var stun_interval: float = 8.0
@export var stun_charge_duration: float = 2.0
@export var stun_radius: float = 450.0
@export var stun_duration: float = 1.5

@onready var sprite: Sprite2D = $Sprite2D
@onready var bubble_particles: CPUParticles2D = $BubbleParticles
@onready var stun_light: PointLight2D = $StunLight
@onready var detection_sound: AudioStreamPlayer2D = $DetectionSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var oscillation_sound: AudioStreamPlayer2D = $OscillationSound
@onready var laser_sound: AudioStreamPlayer2D = $LaserSound
@onready var stun_wave_visual: Node2D = $StunWaveVisual

var _state := State.IDLE
var _idle_direction := Vector2.ZERO
var _idle_change_timer: float = 0.0
var _laser_timer: float = 0.0
var _stun_timer: float = 0.0
var _state_timer: float = 0.0
var _base_scale := Vector2.ONE
var _aggro_tween: Tween
var _stun_tween: Tween
var _pulse_tween: Tween
var _stun_wave_radius: float = 0.0

const _AGGRO_COLOR := Color(1.0, 0.7, 0.8, 1.0)
const _NORMAL_COLOR := Color.WHITE
const _STUN_CHARGE_COLOR := Color(1.0, 1.0, 0.4, 1.0)

const LASER_SCENE := preload("res://game_objects/jellyfish/jellyfish_laser.tscn")

func _ready() -> void:
	super()
	_base_scale = sprite.scale
	aggro_changed.connect(_on_aggro_changed)
	_pick_idle_direction()
	stun_light.energy = 0.0
	stun_wave_visual.visible = false
	_stun_timer = stun_interval
	_laser_timer = laser_cooldown

func _physics_process(delta: float) -> void:
	if dead:
		velocity.y += 15.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		move_and_slide()
		return

	_state_timer -= delta
	if aggressive:
		_laser_timer -= delta
		_stun_timer -= delta

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.PURSUING:
			_process_pursuing(delta)
		State.LASER_SHOOTING:
			_process_laser_shooting(delta)
		State.STUN_CHARGING:
			_process_stun_charging(delta)
		State.STUN_RELEASING:
			_process_stun_releasing(delta)

	# Wave shader intensity
	var target_wave := 0.3
	match _state:
		State.IDLE:
			target_wave = 0.4
		State.PURSUING:
			target_wave = 0.6
		State.STUN_CHARGING:
			target_wave = 0.8
		State.STUN_RELEASING:
			target_wave = 0.2
		State.LASER_SHOOTING:
			target_wave = 0.3
	var mat := sprite.material as ShaderMaterial
	if mat:
		var current: float = 1.0
		var param = mat.get_shader_parameter("intensity")
		if param != null:
			current = param
		mat.set_shader_parameter("intensity", lerpf(current, target_wave, 3.0 * delta))

	# Bubble particles
	var spd := velocity.length()
	bubble_particles.emitting = spd > 8.0
	bubble_particles.amount = clampi(int(spd / 15.0), 2, 16)

	move_and_slide()

# -- Aggro --

func _on_aggro_changed(is_aggressive: bool) -> void:
	if _aggro_tween:
		_aggro_tween.kill()
	_aggro_tween = create_tween()
	_aggro_tween.set_ease(Tween.EASE_IN_OUT)
	_aggro_tween.set_trans(Tween.TRANS_CUBIC)
	_aggro_tween.tween_property(sprite, "modulate", _AGGRO_COLOR if is_aggressive else _NORMAL_COLOR, 0.5)
	if is_aggressive:
		detection_sound.pitch_scale = randf_range(0.85, 1.15)
		detection_sound.play()
		if _state == State.IDLE:
			_state = State.PURSUING
			_stun_timer = stun_interval * randf_range(0.6, 1.4)
			_laser_timer = laser_cooldown * randf_range(0.3, 1.0)

# -- Idle --

func _pick_idle_direction() -> void:
	_idle_direction = Vector2.from_angle(randf() * TAU)
	_idle_change_timer = randf_range(3.0, 6.0)

func _process_idle(delta: float) -> void:
	_idle_change_timer -= delta
	if _idle_change_timer <= 0.0:
		_pick_idle_direction()
	velocity = velocity.move_toward(_idle_direction * idle_speed, 20.0 * delta)

# -- Pursuing --

func _process_pursuing(delta: float) -> void:
	if not aggressive:
		_state = State.IDLE
		_pick_idle_direction()
		return

	# Priority: stun wave > laser
	if _stun_timer <= 0.0:
		_start_stun_charge()
		return

	if _laser_timer <= 0.0:
		_shoot_laser()
		_laser_timer = laser_cooldown * randf_range(0.8, 1.3)
		return

	var player := _find_player()
	if player:
		var to_player := (player.global_position - global_position).normalized()
		velocity = velocity.move_toward(to_player * pursue_speed, 40.0 * delta)

# -- Laser shooting --

func _shoot_laser() -> void:
	var player := _find_player()
	if not player:
		return

	_state = State.LASER_SHOOTING
	_state_timer = 0.4
	velocity = velocity * 0.3

	var base_dir := (player.global_position - global_position).normalized()
	var spread_step := 0.25
	var start_offset := -spread_step * (laser_count - 1) / 2.0

	for i in laser_count:
		var dir := base_dir.rotated(start_offset + spread_step * i)
		var laser := LASER_SCENE.instantiate()
		laser.global_position = global_position + dir * 40.0
		laser.rotation = dir.angle()
		laser.speed = laser_speed
		laser.damage = laser_damage
		laser.max_range = laser_range
		get_tree().current_scene.add_child(laser)

	laser_sound.pitch_scale = randf_range(0.9, 1.2)
	laser_sound.volume_db = randf_range(-6.0, 0.0)
	laser_sound.play()

func _process_laser_shooting(_delta: float) -> void:
	if _state_timer <= 0.0:
		if aggressive:
			_state = State.PURSUING
		else:
			_state = State.IDLE
			_pick_idle_direction()

# -- Stun wave --

func _start_stun_charge() -> void:
	_state = State.STUN_CHARGING
	_state_timer = stun_charge_duration
	velocity = Vector2.ZERO

	# Start oscillation sound
	oscillation_sound.pitch_scale = randf_range(0.85, 1.05)
	oscillation_sound.play()

	# Start pulsing yellow
	_start_pulse()

	# Light energy ramp
	if _stun_tween:
		_stun_tween.kill()
	_stun_tween = create_tween()
	_stun_tween.tween_property(stun_light, "energy", 3.0, stun_charge_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)

func _start_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(sprite, "modulate", _STUN_CHARGE_COLOR, 0.3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(sprite, "modulate", Color(1.0, 0.85, 0.5, 1.0), 0.3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null

func _process_stun_charging(_delta: float) -> void:
	if dead:
		return

	# Subtle scale pulsing
	var charge_progress := 1.0 - (_state_timer / stun_charge_duration)
	var pulse := 1.0 + 0.05 * sin(charge_progress * 30.0) * charge_progress
	sprite.scale = _base_scale * pulse

	if _state_timer <= 0.0:
		_release_stun_wave()

func _release_stun_wave() -> void:
	_state = State.STUN_RELEASING
	_state_timer = 0.5
	_stop_pulse()
	sprite.scale = _base_scale

	# Visual stun wave expansion
	_stun_wave_radius = 0.0
	stun_wave_visual.visible = true

	# Flash bright
	if _stun_tween:
		_stun_tween.kill()
	_stun_tween = create_tween()
	_stun_tween.set_parallel(true)
	_stun_tween.tween_property(stun_light, "energy", 5.0, 0.05)
	_stun_tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	var fade_tween := create_tween()
	fade_tween.tween_interval(0.1)
	fade_tween.tween_property(stun_light, "energy", 0.0, 0.4)

	# Stun nearby player
	var player := _find_player()
	if player:
		var dist := global_position.distance_to(player.global_position)
		if dist <= stun_radius:
			_apply_stun(player)

	_stun_timer = stun_interval

func _apply_stun(player: Node2D) -> void:
	# Temporarily disable player movement by zeroing velocity and blocking input
	if player.has_method("apply_stun"):
		player.apply_stun(stun_duration)
	else:
		# Fallback: just deal minor damage and camera shake
		if player is Entity:
			player.take_damage(5.0)

func _process_stun_releasing(delta: float) -> void:
	# Expand the wave ring visually
	_stun_wave_radius += stun_radius * 2.0 * delta
	stun_wave_visual.queue_redraw()

	if _state_timer <= 0.0:
		stun_wave_visual.visible = false
		if aggressive:
			_state = State.PURSUING
		else:
			_state = State.IDLE
			_pick_idle_direction()

# -- Death --

func _die() -> void:
	_stop_pulse()
	if _aggro_tween:
		_aggro_tween.kill()
	if _stun_tween:
		_stun_tween.kill()
	stun_light.energy = 0.0
	stun_wave_visual.visible = false
	bubble_particles.emitting = false
	oscillation_sound.stop()
	death_sound.pitch_scale = randf_range(0.7, 0.9)
	death_sound.play()
	sprite.scale = _base_scale
	sprite.modulate = _NORMAL_COLOR
	super()

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null
