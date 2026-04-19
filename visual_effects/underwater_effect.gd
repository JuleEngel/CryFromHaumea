extends ColorRect

const GRID_SIZE := 48
const WORLD_EXTENT := 1500.0
const RING_WIDTH := 1.5
const TERRAIN_MASK := 4
const SQRT2 := 1.41421356
const MAX_SHOCKWAVES := 4
const SHOCK_DURATION := 2.2

var _shockwaves: Array[Dictionary] = []
var _shock_texture: ImageTexture
var _was_active := false

# Reusable heap for Dijkstra
var _heap: Array[Vector2] = []

func _ready() -> void:
	add_to_group("water_effect")
	var blank := Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_R8)
	_shock_texture = ImageTexture.create_from_image(blank)
	(material as ShaderMaterial).set_shader_parameter("shockwave_texture", _shock_texture)

func trigger_shockwave(world_pos: Vector2, strength: float = 1.0) -> void:
	if _shockwaves.size() >= MAX_SHOCKWAVES:
		_shockwaves.pop_front()

	var result := _build_distance_field(world_pos)
	if result.is_empty():
		return

	_shockwaves.append({
		"center": world_pos,
		"progress": 0.001,
		"strength": strength,
		"distances": result.distances,
		"max_dist": result.max_dist,
	})

func _build_distance_field(center: Vector2, grid_size: int = GRID_SIZE, world_extent: float = WORLD_EXTENT) -> Dictionary:
	var distances := PackedFloat32Array()
	distances.resize(grid_size * grid_size)
	distances.fill(INF)

	var terrain := PackedByteArray()
	terrain.resize(grid_size * grid_size)
	terrain.fill(0)

	_heap.clear()

	var space := get_viewport().world_2d.direct_space_state
	var cell_size := world_extent * 2.0 / float(grid_size)
	var origin := center - Vector2.ONE * world_extent

	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = TERRAIN_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var cx := grid_size / 2
	var cy := grid_size / 2

	# Find nearest water cell (center may land inside terrain on collision)
	var start := Vector2i(-1, -1)
	for radius in range(0, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var px := cx + dx
				var py := cy + dy
				if px < 0 or px >= grid_size or py < 0 or py >= grid_size:
					continue
				query.position = origin + Vector2(px, py) * cell_size + Vector2.ONE * cell_size * 0.5
				if space.intersect_point(query, 1).size() == 0:
					terrain[py * grid_size + px] = 1
					start = Vector2i(px, py)
					break
				else:
					terrain[py * grid_size + px] = 2
			if start.x >= 0:
				break
		if start.x >= 0:
			break

	if start.x < 0:
		return {}

	var start_idx := start.y * grid_size + start.x
	distances[start_idx] = 0.0
	_heap_push(0.0, start_idx)
	var max_dist := 0.0

	while _heap.size() > 0:
		var top := _heap_pop()
		var d: float = top.x
		var ci: int = int(top.y)

		if d > distances[ci]:
			continue

		var cell_x := ci % grid_size
		var cell_y := ci / grid_size

		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx := cell_x + dx
				var ny := cell_y + dy
				if nx < 0 or nx >= grid_size or ny < 0 or ny >= grid_size:
					continue
				var nidx := ny * grid_size + nx

				if terrain[nidx] == 0:
					query.position = origin + Vector2(nx, ny) * cell_size + Vector2.ONE * cell_size * 0.5
					terrain[nidx] = 1 if space.intersect_point(query, 1).size() == 0 else 2
				if terrain[nidx] == 2:
					continue

				var step := SQRT2 if (dx != 0 and dy != 0) else 1.0
				var nd := d + step
				if nd < distances[nidx]:
					distances[nidx] = nd
					if nd > max_dist:
						max_dist = nd
					_heap_push(nd, nidx)

	return { "distances": distances, "max_dist": max_dist }

func _heap_push(dist: float, idx: int) -> void:
	_heap.append(Vector2(dist, idx))
	var i := _heap.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if _heap[p].x <= _heap[i].x:
			break
		var tmp := _heap[i]
		_heap[i] = _heap[p]
		_heap[p] = tmp
		i = p

func _heap_pop() -> Vector2:
	var top := _heap[0]
	var last = _heap.pop_back()
	if _heap.is_empty():
		return top
	_heap[0] = last
	var i := 0
	var n := _heap.size()
	while true:
		var l := 2 * i + 1
		var r := l + 1
		var s := i
		if l < n and _heap[l].x < _heap[s].x:
			s = l
		if r < n and _heap[r].x < _heap[s].x:
			s = r
		if s == i:
			break
		var tmp := _heap[i]
		_heap[i] = _heap[s]
		_heap[s] = tmp
		i = s
	return top

func _process(delta: float) -> void:
	# Advance and cull shockwaves
	var i := _shockwaves.size() - 1
	while i >= 0:
		_shockwaves[i].progress += delta / SHOCK_DURATION
		if _shockwaves[i].progress >= 1.0:
			_shockwaves.remove_at(i)
		i -= 1

	if _shockwaves.size() > 0:
		_update_shock_texture()
		_was_active = true
	elif _was_active:
		_was_active = false
		(material as ShaderMaterial).set_shader_parameter(
			"shockwave_rect_origin", Vector2(-2.0, -2.0))

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

			var sprite := sub.get_node("Sprite2D") as Sprite2D
			var base_dir := Vector2(-1.0, 0.0) if sprite.scale.x < 0 else Vector2(1.0, 0.0)
			mat.set_shader_parameter("light_direction", base_dir.rotated(sub.rotation))


func _update_shock_texture() -> void:
	# Compute union world rect of all active shockwaves
	var min_corner := Vector2(INF, INF)
	var max_corner := Vector2(-INF, -INF)
	for sw in _shockwaves:
		var c: Vector2 = sw.center
		min_corner = min_corner.min(c - Vector2.ONE * WORLD_EXTENT)
		max_corner = max_corner.max(c + Vector2.ONE * WORLD_EXTENT)

	var composite_size := max_corner - min_corner
	var inv_extent := float(GRID_SIZE) / (WORLD_EXTENT * 2.0)

	var data := PackedByteArray()
	data.resize(GRID_SIZE * GRID_SIZE)

	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var world_pos := min_corner + Vector2(x + 0.5, y + 0.5) / float(GRID_SIZE) * composite_size
			var total := 0.0

			for sw in _shockwaves:
				var local := (world_pos - (sw.center as Vector2) + Vector2.ONE * WORLD_EXTENT) * inv_extent
				var lx := int(local.x)
				var ly := int(local.y)
				if lx < 0 or lx >= GRID_SIZE or ly < 0 or ly >= GRID_SIZE:
					continue
				var d: float = (sw.distances as PackedFloat32Array)[ly * GRID_SIZE + lx]
				if d == INF:
					continue

				var max_dist: float = sw.max_dist
				if max_dist <= 0.0:
					continue
				var ring_dist := (sw.progress as float) * max_dist
				var ring_diff := absf(d - ring_dist)
				var t := clampf(ring_diff / RING_WIDTH, 0.0, 1.0)
				var ring := 1.0 - t * t * (3.0 - 2.0 * t)

				var fade_t := clampf(((sw.progress as float) - 0.3) / 0.7, 0.0, 1.0)
				var fade := (1.0 - fade_t * fade_t * (3.0 - 2.0 * fade_t)) * (sw.strength as float)
				total += ring * fade

			data[y * GRID_SIZE + x] = clampi(int(total * 255.0), 0, 255)

	var image := Image.create_from_data(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_R8, data)
	_shock_texture.set_image(image)

	# Map union rect to screen UV
	var mat := material as ShaderMaterial
	var vp_size := get_viewport_rect().size
	var canvas_transform := get_viewport().get_canvas_transform()
	var screen_origin := (canvas_transform * min_corner) / vp_size
	var screen_end := (canvas_transform * max_corner) / vp_size
	mat.set_shader_parameter("shockwave_rect_origin", screen_origin)
	mat.set_shader_parameter("shockwave_rect_size", screen_end - screen_origin)

