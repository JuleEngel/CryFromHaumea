extends Area2D

@export_multiline var info_text: String = "Information folgt."
var info_image: Texture2D

const SCREEN_TEXTURE := preload("res://ui_scenes/info_screen/screen.png")
const MENU_THEME := preload("res://ui_scenes/main_menu/menu_theme2.tres")

var _canvas: CanvasLayer
var _overlay: ColorRect
var _screen: TextureRect
var _dismissing := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	get_tree().paused = true

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Screen texture as TextureRect (preserves aspect ratio)
	var screen := TextureRect.new()
	screen.texture = SCREEN_TEXTURE
	screen.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	screen.set_anchors_preset(Control.PRESET_CENTER)
	screen.grow_horizontal = Control.GROW_DIRECTION_BOTH
	screen.grow_vertical = Control.GROW_DIRECTION_BOTH
	screen.custom_minimum_size = Vector2(900, 550)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 130)
	margin.add_theme_constant_override("margin_right", 130)
	margin.add_theme_constant_override("margin_top", 100)
	margin.add_theme_constant_override("margin_bottom", 120)

	var vbox := VBoxContainer.new()
	vbox.theme = MENU_THEME
	vbox.add_theme_constant_override("separation", 20)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = info_text
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", 28)
	label.add_theme_font_size_override("bold_font_size", 28)

	var button := Button.new()
	button.text = "Weiter"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_END

	if info_image:
		var img := TextureRect.new()
		img.texture = info_image
		img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(img)

	vbox.add_child(label)
	vbox.add_child(button)
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

	# Tween in: scale up from small + fade in
	overlay.modulate = Color(1, 1, 1, 0)
	screen.scale = Vector2(0.7, 0.7)
	screen.pivot_offset = screen.custom_minimum_size / 2.0

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate", Color(1, 1, 1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(screen, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_callback(button.grab_focus)

	button.pressed.connect(_dismiss)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused and not _dismissing and event.is_action_pressed("ui_accept"):
		_dismiss()

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
		get_tree().paused = false
		_canvas.queue_free()
		queue_free()
	)
