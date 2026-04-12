extends Area2D

const SCREEN_TEXTURE := preload("res://ui_scenes/info_screen/screen.png")
const MENU_THEME := preload("res://ui_scenes/main_menu/menu_theme2.tres")
const MAIN_MENU_PATH := "res://ui_scenes/main_menu/main_menu.tscn"

@onready var continue_target: Marker2D = $ContinueTarget

var _canvas: CanvasLayer
var _overlay: ColorRect
var _screen: TextureRect
var _player: Node2D
var _dismissing := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if _dismissing:
		return

	_player = body
	get_tree().paused = true

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var screen := TextureRect.new()
	screen.texture = SCREEN_TEXTURE
	screen.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	screen.set_anchors_preset(Control.PRESET_CENTER)
	screen.grow_horizontal = Control.GROW_DIRECTION_BOTH
	screen.grow_vertical = Control.GROW_DIRECTION_BOTH
	screen.custom_minimum_size = Vector2(1100, 680)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 180)
	margin.add_theme_constant_override("margin_right", 180)
	margin.add_theme_constant_override("margin_top", 150)
	margin.add_theme_constant_override("margin_bottom", 170)

	var vbox := VBoxContainer.new()
	vbox.theme = MENU_THEME
	vbox.add_theme_constant_override("separation", 20)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = "[b]Rettungsmission abbrechen?[/b]\n\nMöchtest du die Rettungsmission wirklich aufgeben und zum Hauptmenü zurückkehren?"
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", 28)
	label.add_theme_font_size_override("bold_font_size", 32)

	var button_container := HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 40)
	button_container.size_flags_vertical = Control.SIZE_SHRINK_END

	var exit_button := Button.new()
	exit_button.text = "Mission aufgeben"
	exit_button.custom_minimum_size = Vector2(250, 0)
	exit_button.add_theme_color_override("font_color", Color.WHITE)
	exit_button.add_theme_color_override("font_hover_color", Color.WHITE)
	exit_button.add_theme_color_override("font_focus_color", Color.WHITE)
	var exit_stylebox := StyleBoxFlat.new()
	exit_stylebox.bg_color = Color(0.8, 0.15, 0.15)
	exit_stylebox.corner_radius_top_left = 8
	exit_stylebox.corner_radius_top_right = 8
	exit_stylebox.corner_radius_bottom_left = 8
	exit_stylebox.corner_radius_bottom_right = 8
	exit_stylebox.content_margin_left = 20
	exit_stylebox.content_margin_right = 20
	exit_stylebox.content_margin_top = 12
	exit_stylebox.content_margin_bottom = 12
	exit_button.add_theme_stylebox_override("normal", exit_stylebox)
	var exit_hover := exit_stylebox.duplicate()
	exit_hover.bg_color = Color(0.9, 0.2, 0.2)
	exit_button.add_theme_stylebox_override("hover", exit_hover)
	var exit_pressed := exit_stylebox.duplicate()
	exit_pressed.bg_color = Color(0.65, 0.1, 0.1)
	exit_button.add_theme_stylebox_override("pressed", exit_pressed)
	var exit_focus := exit_stylebox.duplicate()
	exit_focus.bg_color = Color(0.9, 0.2, 0.2)
	exit_button.add_theme_stylebox_override("focus", exit_focus)

	var continue_button := Button.new()
	continue_button.text = "Mission fortsetzen"
	continue_button.custom_minimum_size = Vector2(250, 0)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	vbox.add_child(label)
	button_container.add_child(continue_button)
	button_container.add_child(exit_button)
	vbox.add_child(button_container)
	margin.add_child(vbox)
	screen.add_child(margin)
	overlay.add_child(screen)

	_canvas = CanvasLayer.new()
	_canvas.layer = 101
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.add_child(overlay)
	add_child(_canvas)

	_overlay = overlay
	_screen = screen

	overlay.modulate = Color(1, 1, 1, 0)
	screen.scale = Vector2(0.7, 0.7)
	screen.pivot_offset = screen.custom_minimum_size / 2.0

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate", Color(1, 1, 1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(screen, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_callback(continue_button.grab_focus)

	continue_button.pressed.connect(_dismiss)
	exit_button.pressed.connect(_exit_game)

func _dismiss() -> void:
	if _dismissing:
		return
	_dismissing = true

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(_overlay, "modulate", Color(1, 1, 1, 0), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_screen, "scale", Vector2(0.7, 0.7), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_callback(func():
		if continue_target and _player:
			_player.global_position = continue_target.global_position
			_player.velocity = Vector2.ZERO
		get_tree().paused = false
		_canvas.queue_free()
		_dismissing = false
	)

func _exit_game() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
