extends Enemy

enum State { IDLE, PURSUING, ATTACKING, LASER_CHARGING, LASER_FIRING }

@export var idle_speed: float = 25.0
@export var pursue_speed: float = 60.0
@export var rotation_speed: float = 2.0
@export var attack_damage: float = 20.0
@export var attack_cooldown: float = 1.0
@export var laser_enabled: bool = true
@export var laser_cooldown: float = 8.0
@export var laser_charge_duration: float = 2.0
@export var laser_fire_duration: float = 0.8
@export var laser_damage: float = 40.0
@export var laser_range: float = 600.0
@export var laser_width: float = 40.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var bubble_particles: CPUParticles2D = $BubbleParticles
@onready var whale_sound: AudioStreamPlayer2D = $WhaleSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var detection_sound: AudioStreamPlayer2D = $DetectionSound
@onready var laser_sound: AudioStreamPlayer2D = $LaserSound
@onready var laser_beam: Line2D = $LaserBeam
@onready var laser_preview: Line2D = $LaserPreview
@onready var laser_light: PointLight2D = $LaserLight

var _state := State.IDLE
var _idle_direction := Vector2.ZERO
var _idle_change_timer: float = 0.0
var _attack_timer: float = 0.0
var _laser_timer: float = 0.0
var _state_timer: float = 0.0
var _laser_direction := Vector2.ZERO
var _base_scale := Vector2.ONE
var _aggro_tween: Tween
var _laser_tween: Tween
var _laser_hit_this_fire := false
const _AGGRO_COLOR := Color(1.0, 0.7, 0.7, 1.0)
const _NORMAL_COLOR := Color.WHITE
const _LASER_CHARGE_COLOR := Color(1.0, 1.0, 0.5, 1.0)

func _ready() -> void:
	super()
	_base_scale = sprite.scale
	attack_area.monitoring = true
	aggro_changed.connect(_on_aggro_changed)
	_pick_idle_direction()
	_schedule_whale_sound()
	laser_beam.visible = false
	laser_preview.visible = false
	laser_light.energy = 0.0

func _physics_process(delta: float) -> void:
	if dead:
		velocity.y += 20.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		rotation += 0.15 * delta
		move_and_slide()
		return

	_attack_timer -= delta
	if laser_enabled and aggressive:
		_laser_timer -= delta

	_state_timer -= delta

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.PURSUING:
			_process_pursuing(delta)
		State.ATTACKING:
			_process_attacking(delta)
		State.LASER_CHARGING:
			_process_laser_charging(delta)
		State.LASER_FIRING:
			_process_laser_firing(delta)

	# Rotate to face movement direction (not during laser states)
	if _state not in [State.LASER_CHARGING, State.LASER_FIRING]:
		if velocity.length() > 5.0:
			var target_angle := velocity.angle()
			rotation = lerp_angle(rotation, target_angle, rotation_speed * delta)

	# Flip sprite when facing left
	var angle := wrapf(rotation, -PI, PI)
	sprite.flip_v = absf(angle) > PI / 2.0

	# Wave shader intensity
	var target_wave := 0.3 if _state == State.IDLE else 0.6
	if _state == State.LASER_CHARGING:
		target_wave = 0.1
	var mat := sprite.material as ShaderMaterial
	if mat:
		var current: float = 1.0
		var param = mat.get_shader_parameter("intensity")
		if param != null:
			current = param
		mat.set_shader_parameter("intensity", lerpf(current, target_wave, 3.0 * delta))

	# Bubble particles
	var spd := velocity.length()
	bubble_particles.emitting = spd > 10.0
	bubble_particles.amount = clampi(int(spd / 20.0), 2, 16)

	move_and_slide()

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
			_laser_timer = laser_cooldown

func _pick_idle_direction() -> void:
	_idle_direction = Vector2.from_angle(randf() * TAU)
	_idle_change_timer = randf_range(3.0, 6.0)

func _process_idle(delta: float) -> void:
	_idle_change_timer -= delta
	if _idle_change_timer <= 0.0:
		_pick_idle_direction()
	velocity = velocity.move_toward(_idle_direction * idle_speed, 30.0 * delta)

func _process_pursuing(delta: float) -> void:
	if not aggressive:
		_state = State.IDLE
		_pick_idle_direction()
		return

	# Check if it's time for a laser attack
	if laser_enabled and _laser_timer <= 0.0:
		_start_laser_charge()
		return

	var player := _find_player()
	if player:
		var to_player := (player.global_position - global_position).normalized()
		velocity = velocity.move_toward(to_player * pursue_speed, 80.0 * delta)
		if not laser_enabled:
			var dist := global_position.distance_to(player.global_position)
			if dist < 120.0:
				_state = State.ATTACKING

func _process_attacking(delta: float) -> void:
	if not aggressive:
		_state = State.IDLE
		_pick_idle_direction()
		return

	var player := _find_player()
	if not player:
		_state = State.PURSUING
		return

	var dist := global_position.distance_to(player.global_position)
	if dist > 160.0:
		_state = State.PURSUING
		return

	var to_player := (player.global_position - global_position).normalized()
	velocity = velocity.move_toward(to_player * pursue_speed * 0.5, 60.0 * delta)

	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_do_attack()

func _do_attack() -> void:
	var player := _find_player()
	if not player:
		return
	var to_player := (player.global_position - global_position).normalized()
	velocity = to_player * pursue_speed * 1.5

	var tween := create_tween()
	var squash := _base_scale * Vector2(1.15, 0.88)
	tween.tween_property(sprite, "scale", squash, 0.1)
	tween.tween_property(sprite, "scale", _base_scale, 0.2)

	for body in attack_area.get_overlapping_bodies():
		if body is Entity and body.is_in_group("player"):
			body.take_damage(attack_damage)

# -- Laser attack --

func _start_laser_charge() -> void:
	_state = State.LASER_CHARGING
	_state_timer = laser_charge_duration
	_laser_hit_this_fire = false
	velocity = Vector2.ZERO

	var player := _find_player()
	if player:
		_laser_direction = (player.global_position - global_position).normalized()
	else:
		_laser_direction = Vector2.from_angle(rotation)

	# Play oscillation sound
	laser_sound.pitch_scale = randf_range(0.85, 1.05)
	laser_sound.play()

	# Show preview beam
	laser_preview.visible = true
	laser_beam.visible = false
	_update_laser_preview(0.0)

	# Tween whale to yellow glow
	if _laser_tween:
		_laser_tween.kill()
	_laser_tween = create_tween()
	_laser_tween.set_parallel(true)
	_laser_tween.tween_property(sprite, "modulate", _LASER_CHARGE_COLOR, laser_charge_duration * 0.6)
	_laser_tween.tween_property(laser_light, "energy", 2.0, laser_charge_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)

func _process_laser_charging(delta: float) -> void:
	if dead:
		return

	# Slowly track the player
	var player := _find_player()
	if player:
		var desired := (player.global_position - global_position).normalized()
		_laser_direction = _laser_direction.lerp(desired, 1.5 * delta).normalized()

	# Rotate whale to face laser direction
	var target_angle := _laser_direction.angle()
	rotation = lerp_angle(rotation, target_angle, 3.0 * delta)

	# Update preview with charge progress
	var progress := 1.0 - (_state_timer / laser_charge_duration)
	_update_laser_preview(progress)

	if _state_timer <= 0.0:
		_start_laser_fire()

func _update_laser_preview(progress: float) -> void:
	# Preview in local space (node rotates), so beam points along local +X
	var length := laser_range * progress
	laser_preview.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0)])
	# Pulsing opacity
	var pulse := 0.2 + 0.3 * progress + 0.1 * sin(progress * 20.0)
	laser_preview.width = laser_width * 0.8
	laser_preview.default_color = Color(1.0, 1.0, 0.3, pulse)

func _start_laser_fire() -> void:
	_state = State.LASER_FIRING
	_state_timer = laser_fire_duration
	_laser_hit_this_fire = false

	# Lock direction at fire time
	laser_preview.visible = false
	laser_beam.visible = true
	laser_beam.width = laser_width
	laser_beam.points = PackedVector2Array([Vector2.ZERO, Vector2(laser_range, 0)])
	laser_beam.default_color = Color(1.0, 1.0, 0.4, 0.9)

	# Bright flash on light
	if _laser_tween:
		_laser_tween.kill()
	_laser_tween = create_tween()
	_laser_tween.tween_property(laser_light, "energy", 4.0, 0.1)
	_laser_tween.tween_property(laser_light, "energy", 2.5, laser_fire_duration - 0.1)

func _process_laser_firing(delta: float) -> void:
	if dead:
		return

	# Beam visual flicker
	var flicker := 0.85 + randf() * 0.15
	laser_beam.default_color = Color(1.0 * flicker, 1.0 * flicker, 0.3 * flicker, 0.9)
	laser_beam.width = laser_width * (0.9 + randf() * 0.2)

	# Check for player hits along the beam (in global space)
	var player := _find_player()
	if player and not _laser_hit_this_fire:
		var beam_start := global_position
		var beam_end := beam_start + _laser_direction * laser_range
		var dist := _point_to_segment_distance(player.global_position, beam_start, beam_end)
		if dist < laser_width * 0.5 + 20.0:
			player.take_damage(laser_damage)
			_laser_hit_this_fire = true

	if _state_timer <= 0.0:
		_end_laser()

func _end_laser() -> void:
	laser_beam.visible = false
	laser_preview.visible = false
	_laser_timer = laser_cooldown

	# Tween back to aggro color
	if _laser_tween:
		_laser_tween.kill()
	_laser_tween = create_tween()
	_laser_tween.set_parallel(true)
	_laser_tween.tween_property(sprite, "modulate", _AGGRO_COLOR if aggressive else _NORMAL_COLOR, 0.5)
	_laser_tween.tween_property(laser_light, "energy", 0.0, 0.5)

	if aggressive:
		_state = State.PURSUING
	else:
		_state = State.IDLE
		_pick_idle_direction()

func _point_to_segment_distance(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	var ab := seg_b - seg_a
	var ap := point - seg_a
	var t := clampf(ap.dot(ab) / ab.dot(ab), 0.0, 1.0)
	var closest := seg_a + ab * t
	return point.distance_to(closest)

# -- Death --

func _die() -> void:
	if _aggro_tween:
		_aggro_tween.kill()
	if _laser_tween:
		_laser_tween.kill()
	laser_beam.visible = false
	laser_preview.visible = false
	laser_light.energy = 0.0
	bubble_particles.emitting = false
	whale_sound.stop()
	laser_sound.stop()
	death_sound.pitch_scale = randf_range(0.7, 0.9)
	death_sound.play()
	sprite.scale = _base_scale
	sprite.modulate = _NORMAL_COLOR
	super()

# -- Ambient sounds --

func _schedule_whale_sound() -> void:
	var delay := randf_range(5.0, 12.0)
	get_tree().create_timer(delay).timeout.connect(_play_whale_sound)

func _play_whale_sound() -> void:
	if dead:
		return
	whale_sound.pitch_scale = randf_range(0.8, 1.1)
	whale_sound.play()
	_schedule_whale_sound()

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null
