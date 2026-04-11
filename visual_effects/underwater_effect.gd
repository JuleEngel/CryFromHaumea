extends ColorRect

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera or not material is ShaderMaterial:
		return

	var mat := material as ShaderMaterial
	var vp_size := get_viewport_rect().size
	mat.set_shader_parameter("camera_offset", camera.get_screen_center_position())
	mat.set_shader_parameter("screen_pixel_size", Vector2(1.0 / vp_size.x, 1.0 / vp_size.y))

	# Find headlight on the submarine
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var sub := players[0]
		var headlight := sub.get_node_or_null("Headlight") as PointLight2D
		if headlight:
			if not headlight.visible:
				mat.set_shader_parameter("light_intensity", 0.0)
				return

			var canvas_transform := get_viewport().get_canvas_transform()
			var screen_pos := canvas_transform * headlight.global_position
			var screen_uv := screen_pos / vp_size
			mat.set_shader_parameter("light_position_screen", screen_uv)

			# Direction depends on which way the sub faces + tilt
			var sprite := sub.get_node("Sprite2D") as Sprite2D
			var base_dir := Vector2(-1.0, 0.0) if sprite.flip_h else Vector2(1.0, 0.0)
			mat.set_shader_parameter("light_direction", base_dir.rotated(sub.rotation))
