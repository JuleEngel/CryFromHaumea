extends Area2D
@export var next_scene:PackedScene
var loading_screen = preload("res://levels/cutscenes/loading_screen/loading_screen.tscn")

func _on_body_entered(body: Node2D) -> void:
	var current = loading_screen.instantiate()
	current.next_scene = next_scene
	get_tree().change_scene_to_node(current)
	
