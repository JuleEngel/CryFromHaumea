extends Entity

@export var max_speed: float = 600.0
@export var acceleration: float = 2400.0
@export var deceleration: float = 1200.0
@export var visual_tilt_degrees: float = 15.0
@export var tilt_speed: float = 8.0
@export var fire_cooldown: float = 1.0
@export var heal_rate: float = 5.0

const ROCKET_SCENE := preload("res://game_objects/rocket/rocket.tscn")
const GAME_OVER_SCENE := preload("res://ui_scenes/game_over/game_over.tscn")

@onready var sprite: Sprite2D = $Sprite2D
@onready var rocket_spawn: Marker2D = $RocketSpawn
@onready var bubble_particles: CPUParticles2D = $BubbleParticles
@onready var headlight: PointLight2D = $Headlight
@onready var ambiance_sound: AudioStreamPlayer = $AmbianceSound
@onready var dive_sound: AudioStreamPlayer2D = $DiveSound
@onready var music_adventure: AudioStreamPlayer = $MusicAdventure
@onready var music_combat: AudioStreamPlayer = $MusicCombat
@onready var damage_sound: AudioStreamPlayer2D = $DamageSound
@onready var broken_screen: TextureRect = $BrokenScreenLayer/BrokenScreen
@onready var ice_hit_sound: AudioStreamPlayer2D = $IceHitSound

const DIVE_VOL_MIN := -40.0
const DIVE_VOL_MAX := -2.0
const MUSIC_VOL := -6.0
const MUSIC_FADE_SPEED := 3.0

var _fire_timer: float = 0.0
var _in_combat := false
var _headlight_base_y: float
var _stunned := false
var _stun_timer: float = 0.0
var _stun_overlay: ColorRect

func _ready() -> void:
	super()
	headlight.texture = _generate_cone_texture(512, 512)
	ambiance_sound.stream.loop = true
	dive_sound.stream.loop = true
	music_adventure.volume_db = MUSIC_VOL
	music_combat.volume_db = -80.0
	music_adventure.play()
	music_combat.play()
	_headlight_base_y = headlight.position.y

func _process(delta: float) -> void:
	super(delta)
	headlight.position.y = _headlight_base_y + sin(_bob_time * bob_speed * TAU) * bob_amplitude

	# Slow healing
	if hp < max_hp:
		hp = minf(hp + heal_rate * delta, max_hp)
		health_changed.emit(hp, max_hp)

	# Gray tint based on damage (modulate on CharacterBody2D, independent of sprite flash)
	var hp_ratio := hp / max_hp
	var gray := lerpf(0.4, 1.0, hp_ratio)
	modulate = Color(gray, gray, gray, 1.0)

	# Broken screen overlay
	broken_screen.self_modulate.a = (1.0 - hp_ratio) * 0.7

func apply_stun(duration: float) -> void:
	_stunned = true
	_stun_timer = duration
	velocity = velocity * 0.2
	# Yellow ship tint
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 0.3), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, duration)
	# Yellow screen tint
	if not _stun_overlay:
		_stun_overlay = ColorRect.new()
		_stun_overlay.anchors_preset = Control.PRESET_FULL_RECT
		_stun_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$BrokenScreenLayer.add_child(_stun_overlay)
	_stun_overlay.color = Color(1.0, 1.0, 0.2, 0.25)
	var screen_tween := create_tween()
	screen_tween.tween_property(_stun_overlay, "color:a", 0.0, duration)

func _physics_process(delta: float) -> void:
	if _stunned:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_stunned = false

	_fire_timer -= delta
	if not _stunned and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _fire_timer <= 0.0:
		_fire_timer = fire_cooldown
		_spawn_rocket()

	var input_direction := Vector2.ZERO
	if not _stunned:
		input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)

	if velocity.x > 10.0:
		sprite.flip_h = false
		headlight.position.x = abs(headlight.position.x)
	elif velocity.x < -10.0:
		sprite.flip_h = true
		headlight.position.x = -abs(headlight.position.x)

	var target_tilt := 0.0
	if velocity.length() > 10.0:
		var direction := velocity.normalized()
		target_tilt = direction.y * deg_to_rad(visual_tilt_degrees)
		if sprite.flip_h:
			target_tilt = -target_tilt
	rotation = lerp_angle(rotation, target_tilt, tilt_speed * delta)

	if sprite.flip_h:
		headlight.global_rotation = rotation + PI
	else:
		headlight.global_rotation = rotation

	# Bubble particles: emit from behind the submarine when moving
	var is_moving := velocity.length() > 20.0
	bubble_particles.emitting = is_moving
	if sprite.flip_h:
		bubble_particles.position.x = abs(bubble_particles.position.x)
		bubble_particles.direction.x = 1.0
	else:
		bubble_particles.position.x = -abs(bubble_particles.position.x)
		bubble_particles.direction.x = -1.0

	# Dive sound volume scales with speed
	var speed_ratio := clampf(velocity.length() / max_speed, 0.0, 1.0)
	dive_sound.volume_db = lerpf(DIVE_VOL_MIN, DIVE_VOL_MAX, speed_ratio)

	# Crossfade music based on combat state
	var any_aggro := false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Enemy and enemy.aggressive:
			any_aggro = true
			break
	_in_combat = any_aggro
	var fade := MUSIC_FADE_SPEED * delta
	if _in_combat:
		music_combat.volume_db = move_toward(music_combat.volume_db, MUSIC_VOL, fade * 80.0)
		music_adventure.volume_db = move_toward(music_adventure.volume_db, -80.0, fade * 80.0)
	else:
		music_adventure.volume_db = move_toward(music_adventure.volume_db, MUSIC_VOL, fade * 80.0)
		music_combat.volume_db = move_toward(music_combat.volume_db, -80.0, fade * 80.0)

	move_and_slide()

	if get_slide_collision_count() > 0 and not ice_hit_sound.playing:
		ice_hit_sound.play()


static func _generate_cone_texture(_size: int, tex_size: int) -> ImageTexture:
	# PointLight2D renders the texture centered on position.
	# We build a texture where the bright point is at the center,
	# and the cone opens to the right half only.
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(tex_size / 2.0, tex_size / 2.0)
	var half_size := tex_size / 2.0
	var cone_half_angle := deg_to_rad(25.0)

	for x in tex_size:
		for y in tex_size:
			var px := Vector2(x, y) - center
			# Only light the right half (cone opens rightward)
			if px.x <= 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
				continue

			var dist := px.length()
			var angle := absf(px.angle())

			if angle > cone_half_angle:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
				continue

			# Distance falloff (quadratic)
			var dist_factor := 1.0 - clampf(dist / half_size, 0.0, 1.0)
			dist_factor *= dist_factor

			# Angular falloff (soft edges)
			var angle_factor := 1.0 - (angle / cone_half_angle)
			angle_factor *= angle_factor

			var alpha := dist_factor * angle_factor
			img.set_pixel(x, y, Color(1, 1, 1, alpha))

	return ImageTexture.create_from_image(img)

func take_damage(amount: float) -> void:
	super(amount)
	var ratio := clampf(amount / max_hp, 0.0, 1.0)
	damage_sound.volume_db = lerpf(-20.0, -4.0, ratio)
	damage_sound.play()

func _die() -> void:
	died.emit()
	set_physics_process(false)
	set_process(false)
	bubble_particles.emitting = false
	headlight.visible = false
	var water_rect := get_tree().current_scene.get_node_or_null("WaterEffect/ColorRect")
	if water_rect and water_rect.material is ShaderMaterial:
		(water_rect.material as ShaderMaterial).set_shader_parameter("light_intensity", 0.0)
	dive_sound.stop()
	music_adventure.stop()
	music_combat.stop()
	# Turn grey and tilt
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(0.35, 0.35, 0.35, 1.0), 0.8)
	tween.tween_property(self, "rotation", randf_range(-0.15, 0.15), 1.5)
	# Show game over screen
	get_tree().current_scene.add_child(GAME_OVER_SCENE.instantiate())

func _spawn_rocket() -> void:
	var rocket := ROCKET_SCENE.instantiate()
	rocket.global_position = rocket_spawn.global_position
	rocket.rotation = -PI / 2.0
	get_tree().current_scene.add_child(rocket)
