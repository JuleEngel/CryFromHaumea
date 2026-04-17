class_name ConsistentEnemies
extends Area2D

## Maintains a constant enemy population inside this area.
## At _ready, finds every Enemy overlapping this area (regardless of parent).
## When one dies, a replacement spawns at a random position inside the area
## that is not inside terrain and not too close to the player.
## Enemies are tracked permanently once registered — leaving the area doesn't matter.

@export var min_player_distance: float = 800.0
@export var respawn_delay: float = 12.0

const TERRAIN_MASK := 4
const MAX_SPAWN_ATTEMPTS := 40

var _templates: Array[Dictionary] = []

func _ready() -> void:
	# Need monitoring enabled and mask on enemy layer (2) to detect overlapping enemies.
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	# Wait two physics frames so overlapping bodies are registered.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_register_existing_enemies()

func _register_existing_enemies() -> void:
	var count := 0
	for body in get_overlapping_bodies():
		if body is Enemy:
			_track_enemy(body as Enemy)
			count += 1
	print("ConsistentEnemies: registered %d enemies" % count)

func _track_enemy(enemy: Enemy) -> void:
	var scene_path := enemy.scene_file_path
	if scene_path.is_empty():
		push_warning("ConsistentEnemies: enemy %s has no scene_file_path, skipping." % enemy.name)
		return

	var exports := _capture_exports(enemy)

	var template := {
		"scene": load(scene_path) as PackedScene,
		"exports": exports,
	}
	_templates.append(template)
	enemy.died.connect(_on_enemy_died.bind(template))

func _capture_exports(enemy: Enemy) -> Dictionary:
	var exports := {}
	for prop in enemy.get_property_list():
		if prop.usage & PROPERTY_USAGE_STORAGE and prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			exports[prop.name] = enemy.get(prop.name)
	return exports

func _on_enemy_died(template: Dictionary) -> void:
	print("ConsistentEnemies: enemy died, respawning in %ss" % respawn_delay)
	get_tree().create_timer(respawn_delay).timeout.connect(
		_spawn_enemy.bind(template)
	)

func _spawn_enemy(template: Dictionary) -> void:
	var pos := _find_spawn_position()
	if pos == Vector2.INF:
		# Couldn't find a valid spot; retry after a short delay.
		get_tree().create_timer(3.0).timeout.connect(_spawn_enemy.bind(template))
		return

	var instance: Enemy = template.scene.instantiate()

	# Restore exported properties.
	for key in template.exports:
		instance.set(key, template.exports[key])

	get_parent().add_child(instance)
	instance.global_position = pos
	_track_enemy(instance)
	print("ConsistentEnemies: respawned %s at %s" % [instance.name, pos])

func _find_spawn_position() -> Vector2:
	var shape := _get_area_shape()
	if shape == null:
		push_warning("ConsistentEnemies: no CollisionShape2D found.")
		return Vector2.INF

	var rect := _get_area_rect(shape)
	var space := get_world_2d().direct_space_state
	var player := _find_player()

	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = TERRAIN_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true

	for _i in MAX_SPAWN_ATTEMPTS:
		var candidate := Vector2(
			randf_range(rect.position.x, rect.end.x),
			randf_range(rect.position.y, rect.end.y),
		)

		# Must be inside the area's shape.
		if not _point_in_shape(candidate, shape):
			continue

		# Must not be inside terrain.
		query.position = candidate
		if space.intersect_point(query, 1).size() > 0:
			continue

		# Must not be too close to the player.
		if player and candidate.distance_to(player.global_position) < min_player_distance:
			continue

		return candidate

	return Vector2.INF

func _get_area_shape() -> CollisionShape2D:
	for child in get_children():
		if child is CollisionShape2D:
			return child
	return null

func _get_area_rect(col: CollisionShape2D) -> Rect2:
	var center := col.global_position
	var s := col.shape
	if s is RectangleShape2D:
		var rect_s := s as RectangleShape2D
		var half := rect_s.size / 2.0
		return Rect2(center - half, rect_s.size)
	elif s is CircleShape2D:
		var circle := s as CircleShape2D
		return Rect2(center - Vector2(circle.radius, circle.radius), Vector2(circle.radius, circle.radius) * 2.0)
	elif s is CapsuleShape2D:
		var cap := s as CapsuleShape2D
		var r := cap.radius
		var h := cap.height / 2.0
		return Rect2(center - Vector2(r, h), Vector2(r * 2.0, h * 2.0))
	push_warning("ConsistentEnemies: unsupported shape type, using rough bounds.")
	return Rect2(center - Vector2(500, 500), Vector2(1000, 1000))

func _point_in_shape(point: Vector2, col: CollisionShape2D) -> bool:
	var local := point - col.global_position
	var s := col.shape
	if s is RectangleShape2D:
		var rect_s := s as RectangleShape2D
		var half := rect_s.size / 2.0
		return absf(local.x) <= half.x and absf(local.y) <= half.y
	elif s is CircleShape2D:
		var circle := s as CircleShape2D
		return local.length() <= circle.radius
	elif s is CapsuleShape2D:
		var cap := s as CapsuleShape2D
		var r := cap.radius
		var h := cap.height / 2.0 - r
		if absf(local.y) <= h:
			return absf(local.x) <= r
		var cap_center_y := h if local.y > 0 else -h
		return Vector2(local.x, local.y - cap_center_y).length() <= r
	return true

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null
