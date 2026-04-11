extends CanvasLayer

@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton
@onready var panel: PanelContainer = %Panel
@onready var music: AudioStreamPlayer = $Music

func _ready() -> void:
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)
	get_tree().paused = true
	# Fade in
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 1.0, 0.8).set_delay(0.5)

func _on_restart() -> void:
	music.stop()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu() -> void:
	music.stop()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui_scenes/main_menu/main_menu.tscn")
