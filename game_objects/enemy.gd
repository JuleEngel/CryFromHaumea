class_name Enemy
extends Entity

signal aggro_changed(is_aggressive: bool)

@export var aggro_range: float = 780.0
@export var deaggro_range_multiplier: float = 3.0

@onready var aggro_area: Area2D = $AggroArea

var aggressive := false
var dead := false

func _ready() -> void:
	super()
	add_to_group("enemy")
	collision_layer = 2
	collision_mask = 5

	var shape := CircleShape2D.new()
	shape.radius = aggro_range
	var col := CollisionShape2D.new()
	col.shape = shape
	aggro_area.add_child(col)
	aggro_area.body_entered.connect(_on_aggro_body_entered)

func _process(delta: float) -> void:
	super(delta)
	if aggressive and not dead:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var dist := global_position.distance_to(players[0].global_position)
			if dist > aggro_range * deaggro_range_multiplier:
				aggressive = false
				aggro_changed.emit(false)

func _on_aggro_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		aggressive = true
		aggro_changed.emit(true)

func _die() -> void:
	died.emit()
	dead = true
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
