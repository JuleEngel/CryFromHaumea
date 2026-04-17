extends CanvasLayer

const SCENES := [
	["Cockpit Cutscene", "res://levels/cutscenes/cockpit/first_cutscene.tscn"],
	["Landing Cutscene", "res://levels/cutscenes/landing/landing_cutscene.tscn"],
	["Base Station Cutscene", "res://levels/cutscenes/base_station/base_station_cutscene.tscn"],
	["Level 1", "res://levels/level1.tscn"],
	["Level 2", "res://levels/level2.tscn"],
	["Level 3", "res://levels/level3.tscn"],
	["Level 4", "res://levels/level4.tscn"],
	["Underwater Base Cutscene", "res://levels/cutscenes/underwater_base/underwater_base_cutscene.tscn"],
	["Underwater Base Inside", "res://levels/cutscenes/underwater_base_inside/underwater_base_inside_cutscene.tscn"],
	["Final Scene Cutscene", "res://levels/cutscenes/final_scene/final_scene_cutscene.tscn"],
	["Main Menu", "res://ui_scenes/main_menu/main_menu.tscn"],
]

var _panel: PanelContainer
var _visible := false

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_O:
		_toggle()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and _visible:
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	get_tree().paused = _visible

func _build_ui() -> void:
	# Darken background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.3, 0.5, 1.0, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "Debug - Scene Selector"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	vbox.add_child(sep)

	for i in SCENES.size():
		var scene_name: String = SCENES[i][0]
		var scene_path: String = SCENES[i][1]

		var btn := Button.new()
		btn.text = "%d.  %s" % [i + 1, scene_name]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(400, 0)
		btn.add_theme_font_size_override("font_size", 18)

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
		btn_style.corner_radius_top_left = 6
		btn_style.corner_radius_top_right = 6
		btn_style.corner_radius_bottom_left = 6
		btn_style.corner_radius_bottom_right = 6
		btn_style.content_margin_left = 16
		btn_style.content_margin_right = 16
		btn_style.content_margin_top = 8
		btn_style.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", btn_style)

		var hover_style := btn_style.duplicate()
		hover_style.bg_color = Color(0.2, 0.3, 0.5, 0.9)
		btn.add_theme_stylebox_override("hover", hover_style)

		var pressed_style := btn_style.duplicate()
		pressed_style.bg_color = Color(0.15, 0.25, 0.45, 0.9)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		var focus_style := hover_style.duplicate()
		btn.add_theme_stylebox_override("focus", focus_style)

		btn.pressed.connect(_jump_to_scene.bind(scene_path))
		vbox.add_child(btn)

		if i == 0:
			btn.call_deferred("grab_focus")

	var hint := Label.new()
	hint.text = "Press O or Escape to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(hint)

	_panel.add_child(vbox)
	add_child(_panel)
	_panel.visible = false
	bg.visible = false
	_panel.visibility_changed.connect(func(): bg.visible = _panel.visible)

func _jump_to_scene(path: String) -> void:
	_visible = false
	_panel.visible = false
	get_tree().paused = false
	CheckpointManager.clear()
	get_tree().change_scene_to_file(path)
