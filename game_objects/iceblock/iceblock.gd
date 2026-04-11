extends Entity

@export var crumble_duration: float = 1.2

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	bob_amplitude = 0.0
	super()
	collision_layer = 4  # walls
	collision_mask = 0

func take_damage(amount: float) -> void:
	super(amount)
	var mat := sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("damage_ratio", 1.0 - (hp / max_hp))

func _die() -> void:
	died.emit()
	collision_layer = 0
	set_physics_process(false)
	var mat := sprite.material as ShaderMaterial
	if mat:
		var tween := create_tween()
		tween.tween_method(
			func(v: float): mat.set_shader_parameter("crumble_progress", v),
			0.0, 1.0, crumble_duration
		)
		tween.tween_callback(queue_free)
	else:
		queue_free()
