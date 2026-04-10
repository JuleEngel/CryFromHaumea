class_name Enemy
extends Entity

signal aggro_changed(is_aggressive: bool)

@export var aggro_range: float = 300.0

@onready var aggro_area: Area2D = $AggroArea

var aggressive := false

func _ready() -> void:
	super()
	collision_layer = 2
	collision_mask = 1

	var shape := CircleShape2D.new()
	shape.radius = aggro_range
	var col := CollisionShape2D.new()
	col.shape = shape
	aggro_area.add_child(col)
	aggro_area.body_entered.connect(_on_aggro_body_entered)
	aggro_area.body_exited.connect(_on_aggro_body_exited)

func _on_aggro_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		aggressive = true
		aggro_changed.emit(true)

func _on_aggro_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		aggressive = false
		aggro_changed.emit(false)
