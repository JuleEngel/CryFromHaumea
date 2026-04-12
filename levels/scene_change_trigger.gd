extends Area2D
@export var next_scene:PackedScene
@export var show_loading_screen := true
const loading_screen = preload("res://levels/cutscenes/loading_screen/loading_screen.tscn")

func _on_body_entered(body: Node2D) -> void:
	CheckpointManager.clear()
	if show_loading_screen:
		var current = loading_screen.instantiate()
		current.next_scene = next_scene
		get_tree().change_scene_to_node(current)
	else:
		get_tree().change_scene_to_packed(next_scene)
	
