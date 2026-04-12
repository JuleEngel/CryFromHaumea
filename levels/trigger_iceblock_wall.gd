extends Area2D
@export var iceblock_wall:StaticBody2D

var _triggered := false

const EXPLOSION_SOUND = preload("res://audio/sound_effects/underwater_explosion.mp3")

func _ready():
	iceblock_wall.collision_layer = 0

func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	_triggered = true

	iceblock_wall.visible = true
	iceblock_wall.collision_layer = 4
	var target_position = iceblock_wall.position
	iceblock_wall.position.y -= 100
	var tween = create_tween()
	tween.tween_property(iceblock_wall, "position", target_position, 0.5) \
	.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)

	# Play explosion sound
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = EXPLOSION_SOUND
	sfx.volume_db = 8.0
	sfx.max_distance = 3000.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

	# Strong camera shake
	_shake_camera()

func _shake_camera() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var cam: Camera2D = players[0].get_node_or_null("Camera2D")
	if not cam:
		return
	var tween := create_tween()
	var strength := 12.0
	for i in 6:
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tween.tween_property(cam, "offset", offset, 0.05)
		strength *= 0.7
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.05)
