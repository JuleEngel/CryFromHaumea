extends CanvasLayer

const CREDITS_SCENE = preload("uid://t2fq0e5biqhp")
const OPTIONS_SCENE = preload("uid://bm05tr65hiukv")
const TUTORIAL_SCENE = preload("uid://cq5crd7456h8s")

const MAIN_SCENE_PATH: String = "res://levels/cutscenes/cockpit/first_cutscene.tscn"

enum ContentType {
	OPTIONS,
	CREDITS,
	MULTIPLAYER,
	MULTIPLAYER_LOBBY,
	TUTORIAL
}

@onready var main_menu_content_container = %MainMenuContentContainer

var max_parallax = 20000
var currently_displayed = null
var currently_displayed_type = null
var target: Vector2 = Vector2.ZERO
var curr: Vector2 = Vector2.ZERO
var speed = 20


func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if currently_displayed == null:
		return 
	if currently_displayed_type == ContentType.CREDITS:
		currently_displayed.position.y -= 30 * delta


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_options_pressed() -> void:
	if currently_displayed != null:
		currently_displayed.queue_free()
	var options = OPTIONS_SCENE.instantiate()
	main_menu_content_container.add_child(options)
	currently_displayed = options
	currently_displayed_type = ContentType.OPTIONS


func _on_credits_pressed() -> void:
	if currently_displayed != null:
		currently_displayed.queue_free()
	var credits = CREDITS_SCENE.instantiate()
	main_menu_content_container.add_child(credits)
	currently_displayed = credits
	currently_displayed_type = ContentType.CREDITS


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_how_to_play_pressed() -> void:
	if currently_displayed != null:
		currently_displayed.queue_free()
	var how_to_play = TUTORIAL_SCENE.instantiate()
	main_menu_content_container.add_child(how_to_play)
	currently_displayed = how_to_play
	currently_displayed_type = ContentType.TUTORIAL
