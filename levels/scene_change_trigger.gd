extends Area2D
@export var nextScene:PackedScene

func _on_body_entered(body: Node2D) -> void:
	get_tree().change_scene_to_packed(nextScene)
	
