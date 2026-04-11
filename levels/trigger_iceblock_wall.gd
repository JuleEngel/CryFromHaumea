extends Area2D
@export var iceblock_wall:StaticBody2D

func _ready():
	iceblock_wall.collision_layer = 0

func _on_body_entered(body: Node2D) -> void:
	iceblock_wall.visible = true
	iceblock_wall.collision_layer = 4
	var target_position = iceblock_wall.position
	iceblock_wall.position.y -= 100
	var tween = create_tween()
	tween.tween_property(iceblock_wall, "position", target_position, 0.5) \
	.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	
