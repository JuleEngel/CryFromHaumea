class_name Enemy
extends Entity

signal aggro_changed(is_aggressive: bool)

@export var aggro_range: float = 780.0
@export var deaggro_range_multiplier: float = 3.0
@export var group_range: float = 500.0

@onready var aggro_area: Area2D = $AggroArea

var aggressive := false
var dead := false
var _group: Array = []

func _ready() -> void:
	super()
	add_to_group("enemy")
	collision_layer = 2
	collision_mask = 5

	var shape := CircleShape2D.new()
	# Compensate for node scale so aggro_range is always in world-space units
	shape.radius = aggro_range / scale.x
	var col := CollisionShape2D.new()
	col.shape = shape
	aggro_area.add_child(col)
	aggro_area.body_entered.connect(_on_aggro_body_entered)

	_group = [self]
	call_deferred("_form_groups")

func _form_groups() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self or not (enemy is Enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= group_range:
			_merge_group(enemy)

func _merge_group(other: Enemy) -> void:
	if _group == other._group:
		return
	var target: Array = _group if _group.size() >= other._group.size() else other._group
	var source: Array = other._group if target == _group else _group
	for e in source:
		target.append(e)
		e._group = target

func _process(delta: float) -> void:
	super(delta)
	if aggressive and not dead:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var any_in_range := false
			for e in _group:
				var member := e as Enemy
				if not is_instance_valid(member) or member.dead:
					continue
				var dist := member.global_position.distance_to(players[0].global_position)
				if dist <= member.aggro_range * member.deaggro_range_multiplier:
					any_in_range = true
					break
			if not any_in_range:
				_group_deaggro()

func _group_aggro() -> void:
	for e in _group:
		var member := e as Enemy
		if not is_instance_valid(member) or member.dead or member.aggressive:
			continue
		member.aggressive = true
		member.aggro_changed.emit(true)

func _group_deaggro() -> void:
	for e in _group:
		var member := e as Enemy
		if not is_instance_valid(member) or member.dead or not member.aggressive:
			continue
		member.aggressive = false
		member.aggro_changed.emit(false)

func _on_aggro_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_group_aggro()

func _die() -> void:
	died.emit()
	dead = true
	aggressive = false
	aggro_changed.emit(false)
	# Can't damage player, but still collides with walls
	collision_layer = 0
	collision_mask = 4
	aggro_area.monitoring = false
	set_process(false)
	# Sink with gravity via move_and_slide
	velocity = Vector2(randf_range(-20.0, 20.0), 30.0)
	# Turn grey, then fade out
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.2, 0.2, 0.2, 1.0), 0.5)
	tween.tween_interval(7.5)
	tween.tween_property(self, "modulate:a", 0.0, 2.0)
	tween.tween_callback(queue_free)
