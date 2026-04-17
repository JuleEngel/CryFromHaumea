extends ColorRect

const GRID_SIZE := 48
const WORLD_EXTENT := 1500.0
const RING_WIDTH := 1.5
const TERRAIN_MASK := 4

var _shock_active := false
var _shock_progress := 0.0
var _shock_duration := 2.2
var _shock_center := Vector2.ZERO
var _shock_strength := 1.0
var _shock_distances := PackedFloat32Array()
var _shock_max_dist := 0.0
var _shock_texture: ImageTexture

func _ready() -> void:
	add_to_group("water_effect")
	_shock_distances.resize(GRID_SIZE * GRID_SIZE)
	var blank := Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_R8)
	_shock_texture = ImageTexture.create_from_image(blank)
	(material as ShaderMaterial).set_shader_parameter("shockwave_texture", _shock_texture)

func trigger_shockwave(world_pos: Vector2, strength: float = 1.0) -> void:
	_shock_center = world_pos
	_shock_strength = strength
	_shock_progress = 0.001
	_shock_active = true
	_build_distance_field()

func _build_distance_field() -> void:
	_shock_distances.fill(-1.0)
	_shock_max_dist = 0.0

	var space := get_viewport().world_2d.direct_space_state
	var cell_size := WORLD_EXTENT * 2.0 / float(GRID_SIZE)
	var origin := _shock_center - Vector2.ONE * WORLD_EXTENT

	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = TERRAIN_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var cx := GRID_SIZE / 2
	var cy := GRID_SIZE / 2

	# Find nearest water cell (center may land inside terrain on collision)
	var start := Vector2i(-1, -1)
	for radius in range(0, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var px := cx + dx
				var py := cy + dy
				if px < 0 or px >= GRID_SIZE or py < 0 or py >= GRID_SIZE:
					continue
				query.position = origin + Vector2(px, py) * cell_size + Vector2.ONE * cell_size * 0.5
				if space.intersect_point(query, 1).size() == 0:
					start = Vector2i(px, py)
					break
			if start.x >= 0:
				break
		if start.x >= 0:
			break

	if start.x < 0:
		_shock_active = false
		return

	_shock_distances[start.y * GRID_SIZE + start.x] = 0.0
	var queue: Array[Vector2i] = [start]
	var head := 0

	while head < queue.size():
		var cell := queue[head]
		head += 1
		var d := _shock_distances[cell.y * GRID_SIZE + cell.x]

		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx := cell.x + dx
				var ny := cell.y + dy
				if nx < 0 or nx >= GRID_SIZE or ny < 0 or ny >= GRID_SIZE:
					continue
				var idx := ny * GRID_SIZE + nx
				if _shock_distances[idx] != -1.0:
					continue

				query.position = origin + Vector2(nx, ny) * cell_size + Vector2.ONE * cell_size * 0.5
				if space.intersect_point(query, 1).size() > 0:
					_shock_distances[idx] = -2.0
					continue

				var step := 1.414 if (dx != 0 and dy != 0) else 1.0
				var nd := d + step
				_shock_distances[idx] = nd
				if nd > _shock_max_dist:
					_shock_max_dist = nd
				queue.append(Vector2i(nx, ny))

func _process(delta: float) -> void:
	if _shock_active:
		_shock_progress += delta / _shock_duration
		if _shock_progress >= 1.0:
			_shock_progress = 1.0
			_shock_active = false
			(material as ShaderMaterial).set_shader_parameter(
				"shockwave_rect_origin", Vector2(-2.0, -2.0))
		else:
			_update_shock_texture()

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

func _update_shock_texture() -> void:
	if _shock_max_dist <= 0.0:
		return

	var ring_dist := _shock_progress * _shock_max_dist
	var fade_t := clampf((_shock_progress - 0.3) / 0.7, 0.0, 1.0)
	var fade := (1.0 - fade_t * fade_t * (3.0 - 2.0 * fade_t)) * _shock_strength

	var data := PackedByteArray()
	data.resize(GRID_SIZE * GRID_SIZE)

	for i in _shock_distances.size():
		var d := _shock_distances[i]
		if d < 0.0:
			data[i] = 0
			continue
		var ring_diff := absf(d - ring_dist)
		var t := clampf(ring_diff / RING_WIDTH, 0.0, 1.0)
		var ring := 1.0 - t * t * (3.0 - 2.0 * t)
		data[i] = clampi(int(ring * fade * 255.0), 0, 255)

	var image := Image.create_from_data(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_R8, data)
	_shock_texture.set_image(image)

	# Update screen-space rect for shader
	var mat := material as ShaderMaterial
	var vp_size := get_viewport_rect().size
	var canvas_transform := get_viewport().get_canvas_transform()
	var screen_origin := (canvas_transform * (_shock_center - Vector2.ONE * WORLD_EXTENT)) / vp_size
	var screen_end := (canvas_transform * (_shock_center + Vector2.ONE * WORLD_EXTENT)) / vp_size
	mat.set_shader_parameter("shockwave_rect_origin", screen_origin)
	mat.set_shader_parameter("shockwave_rect_size", screen_end - screen_origin)
