extends Entity

@export var max_speed: float = 600.0
@export var acceleration: float = 2400.0
@export var deceleration: float = 1200.0
@export var visual_tilt_degrees: float = 15.0
@export var tilt_speed: float = 8.0
@export var fire_cooldown: float = 1.0

const ROCKET_SCENE := preload("res://game_objects/rocket/rocket.tscn")

@onready var sprite: Sprite2D = $Sprite2D
@onready var rocket_spawn: Marker2D = $RocketSpawn
@onready var bubble_particles: CPUParticles2D = $BubbleParticles
@onready var headlight: PointLight2D = $Sprite2D/Headlight

var _fire_timer: float = 0.0

func _ready() -> void:
	super()
	headlight.texture = _generate_cone_texture(512, 512)

func _physics_process(delta: float) -> void:
	_fire_timer -= delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _fire_timer <= 0.0:
		_fire_timer = fire_cooldown
		_spawn_rocket()

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)

	if velocity.x > 10.0:
		sprite.flip_h = false
		headlight.position.x = abs(headlight.position.x)
		headlight.scale.x = 1.0
	elif velocity.x < -10.0:
		sprite.flip_h = true
		headlight.position.x = -abs(headlight.position.x)
		headlight.scale.x = -1.0

	var target_tilt := 0.0
	if velocity.length() > 10.0:
		var direction := velocity.normalized()
		target_tilt = direction.y * deg_to_rad(visual_tilt_degrees)
		if sprite.flip_h:
			target_tilt = -target_tilt
	sprite.rotation = lerp_angle(sprite.rotation, target_tilt, tilt_speed * delta)

	# Bubble particles: emit from behind the submarine when moving
	var is_moving := velocity.length() > 20.0
	bubble_particles.emitting = is_moving
	if sprite.flip_h:
		bubble_particles.position.x = abs(bubble_particles.position.x)
		bubble_particles.direction.x = 1.0
	else:
		bubble_particles.position.x = -abs(bubble_particles.position.x)
		bubble_particles.direction.x = -1.0

	move_and_slide()


static func _generate_cone_texture(size: int, tex_size: int) -> ImageTexture:
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

func _spawn_rocket() -> void:
	var rocket := ROCKET_SCENE.instantiate()
	rocket.global_position = rocket_spawn.global_position
	rocket.rotation = (get_global_mouse_position() - rocket_spawn.global_position).angle()
	get_tree().current_scene.add_child(rocket)
