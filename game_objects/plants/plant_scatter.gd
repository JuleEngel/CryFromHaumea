@tool
extends StaticBody2D

const PLANTS_DIR = "res://game_objects/plants/"

@export var count: int = 20
@export_range(0.1, 3.0) var scale_min: float = 0.7
@export_range(0.1, 3.0) var scale_max: float = 1.3
@export_range(10.0, 500.0) var min_distance: float = 80.0
@export_tool_button("Scatter Plants") var scatter = _scatter_plants
@export_tool_button("Clear Plants") var clear = _clear_plants

var _plant_scenes: Array[PackedScene] = []


func _load_plant_scenes() -> void:
	_plant_scenes.clear()
	for file in DirAccess.get_files_at(PLANTS_DIR):
		if file.get_extension() == "tscn":
			_plant_scenes.append(load(PLANTS_DIR.path_join(file)))


func _scatter_plants() -> void:
	_load_plant_scenes()
	if _plant_scenes.is_empty():
		push_warning("PlantScatter: No .tscn files found in %s" % PLANTS_DIR)
		return

	var shapes: Array[SS2D_Shape] = []
	_find_closed_shapes(self, shapes)
	if shapes.is_empty():
		push_warning("PlantScatter: No closed SS2D shapes found")
		return

	# Build weighted segment list across all shapes
	var segments: Array[Dictionary] = []
	var total_length: float = 0.0

	for shape in shapes:
		var points := shape.get_point_array().get_tessellated_points()
		if points.size() < 3:
			continue

		var clockwise := shape.get_point_array().are_points_clockwise()

		for i in points.size():
			var p1 := points[i]
			var p2 := points[(i + 1) % points.size()]
			var edge := p2 - p1
			var length := edge.length()
			if length < 0.01:
				continue

			var dir := edge / length
			# Outward normal depends on winding direction
			var normal: Vector2
			if clockwise:
				normal = Vector2(dir.y, -dir.x)
			else:
				normal = Vector2(-dir.y, dir.x)

			segments.append({
				"p1": p1,
				"p2": p2,
				"normal": normal,
				"length": length,
				"shape": shape,
			})
			total_length += length

	if segments.is_empty():
		push_warning("PlantScatter: Shapes have no valid segments")
		return

	# Get or create container
	_clear_plants()
	var container := Node2D.new()
	container.name = "ScatteredPlants"
	add_child(container)
	container.owner = get_tree().edited_scene_root

	# Spawn plants with minimum distance check
	var placed_positions: Array[Vector2] = []
	var max_attempts := count * 10
	var attempts := 0

	while placed_positions.size() < count and attempts < max_attempts:
		attempts += 1

		var r := randf() * total_length
		var accumulated: float = 0.0
		var seg: Dictionary = segments[-1]
		for s in segments:
			accumulated += s.length
			if accumulated >= r:
				seg = s
				break

		# Random position along segment
		var t := randf()
		var local_pos: Vector2 = seg.p1.lerp(seg.p2, t)
		var normal: Vector2 = seg.normal
		var shape_node: Node2D = seg.shape

		# Transform position from shape-local to container-local
		var global_pos := shape_node.to_global(local_pos)
		var pos := container.to_local(global_pos)

		# Check minimum distance to already placed plants
		var too_close := false
		for existing in placed_positions:
			if pos.distance_to(existing) < min_distance:
				too_close = true
				break
		if too_close:
			continue

		placed_positions.append(pos)

		# Transform normal direction
		var global_normal_end := shape_node.to_global(local_pos + normal * 10.0)
		var normal_dir := (container.to_local(global_normal_end) - pos).normalized()

		# Rotation: align plant's up (-Y) with the outward normal
		var angle := Vector2.UP.angle_to(normal_dir)

		var plant := (_plant_scenes.pick_random() as PackedScene).instantiate()
		plant.name = "Plant_%d" % placed_positions.size()
		plant.position = pos
		plant.rotation = angle
		var s := randf_range(scale_min, scale_max)
		plant.scale = Vector2(s, s)

		container.add_child(plant)
		plant.owner = get_tree().edited_scene_root
		_set_owner_recursive(plant, get_tree().edited_scene_root)

	print("PlantScatter: Placed %d/%d plants across %d shapes" % [placed_positions.size(), count, shapes.size()])


func _clear_plants() -> void:
	var old := get_node_or_null("ScatteredPlants")
	if old:
		old.free()


func _find_closed_shapes(node: Node, result: Array[SS2D_Shape]) -> void:
	if node is SS2D_Shape and node.get_point_array().is_shape_closed():
		result.append(node)
	for child in node.get_children():
		_find_closed_shapes(child, result)


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)
