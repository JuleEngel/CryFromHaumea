extends CanvasLayer

signal all_collected

@export var next_scene: PackedScene
@export var required_clues: int = 10

const LOADING_SCREEN := preload("res://levels/cutscenes/loading_screen/loading_screen.tscn")
const FONT := preload("res://ui_scenes/fonts/Orbitron-VariableFont_wght.ttf")

var _collected := 0

var _label: Label
var _panel: PanelContainer
@export var _final_trigger_orb: TriggerOrb

func _ready() -> void:
	layer = 100
	_build_ui()
	# Wait one frame so all sibling nodes are ready before scanning.
	await get_tree().process_frame
	_scan_orbs()
	_update_label()

func _build_ui() -> void:
	_panel = PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)

	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -30
	_panel.offset_top = 30

	_label = Label.new()
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	_panel.add_child(_label)
	add_child(_panel)

func _scan_orbs() -> void:
	var orbs: Array[Node] = []
	for node in _find_trigger_orbs(get_tree().current_scene):
		if node.required_for_next_level:
			orbs.append(node)

	for orb in orbs:
		orb.collected.connect(_on_orb_collected.bind(orb), CONNECT_ONE_SHOT)

func _find_trigger_orbs(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	if root.get("required_for_next_level") != null and root.has_signal("collected"):
		result.append(root)
	for child in root.get_children():
		result.append_array(_find_trigger_orbs(child))
	return result

func _on_orb_collected(_orb: Node) -> void:
	_collected += 1
	_update_label()
	_animate_pulse()
	if _collected == required_clues - 1:
		for trigger_orb in get_tree().get_nodes_in_group("trigger_orb"):
			if trigger_orb.required_for_next_level:
				trigger_orb.text = _final_trigger_orb.text
				trigger_orb.image = _final_trigger_orb.image
	if _collected >= required_clues:
		all_collected.emit()
		_on_all_collected()

func _update_label() -> void:
	_label.text = "%d / %d Hinweise gefunden\nfür nächstes Level" % [_collected, required_clues]

func _animate_pulse() -> void:
	_panel.pivot_offset = _panel.size / 2.0
	var tween := create_tween()
	tween.tween_property(_panel, "scale", Vector2(1.15, 1.15), 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_IN)

func _on_all_collected() -> void:
	# Brief delay so the player sees the final count.
	await get_tree().create_timer(1.5).timeout
	if next_scene:
		CheckpointManager.clear()
		var screen := LOADING_SCREEN.instantiate()
		screen.next_scene = next_scene
		get_tree().change_scene_to_node(screen)
