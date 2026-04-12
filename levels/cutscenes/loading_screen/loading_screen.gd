extends Node2D
@export var next_scene:PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var tween = create_tween()
	$Background.modulate = Color.BLACK
	tween.tween_property($Background, "modulate", Color.WHITE, 0.5) 
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(func():get_tree().change_scene_to_packed(next_scene))
