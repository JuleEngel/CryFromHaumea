extends Area2D

@export var target: Node2D

const COIN_SOUND := preload("res://audio/sound_effects/pickup_coin.wav")

var _activated := false

func _ready() -> void:
	_check_respawn.call_deferred()

func _check_respawn() -> void:
	if CheckpointManager.has_checkpoint and global_position.distance_to(CheckpointManager.checkpoint_position) < 1.0:
		_activated = true
		if target:
			var target_dir := (target.global_position - global_position).normalized()
			_show_direction_arrow(target_dir)

func _on_body_entered(body: Node2D) -> void:
	if _activated:
		return
	if body.is_in_group("player"):
		_activated = true
		var flip_h: bool = body.get_node("Sprite2D").scale.x < 0
		var target_dir := Vector2.ZERO
		if target:
			target_dir = (target.global_position - global_position).normalized()
		CheckpointManager.set_checkpoint(global_position, flip_h, target_dir)
		_play_coin_sound()
		_show_saved_notification()

func _play_coin_sound() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = COIN_SOUND
	player.volume_db = -4.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _show_direction_arrow(dir: Vector2) -> void:
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		Vector2(40, -15), Vector2(120, -15), Vector2(120, -35),
		Vector2(170, 0),
		Vector2(120, 35), Vector2(120, 15), Vector2(40, 15),
	])
	arrow.color = Color(1.0, 1.0, 0.4, 0.9)
	arrow.z_index = 10
	arrow.global_position = global_position
	arrow.rotation = dir.angle()
	get_tree().current_scene.add_child(arrow)
	var tween := create_tween()
	tween.tween_interval(30.0)
	tween.tween_property(arrow, "modulate:a", 0.0, 1.5)
	tween.tween_callback(arrow.queue_free)

func _show_saved_notification() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	var label := Label.new()
	label.text = "Gespeichert"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	label.position.y -= 80
	layer.add_child(label)
	get_tree().current_scene.add_child(layer)
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(layer.queue_free)
