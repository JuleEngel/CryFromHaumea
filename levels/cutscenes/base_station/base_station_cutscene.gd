extends Node2D

const DialogTextScene := preload("res://ui_scenes/dialog_text/dialog_text.tscn")
const OutlineShader := preload("res://levels/cutscenes/base_station/outline.gdshader")

const COLOR_UNSELECTED := Color(1.0, 0.85, 0.0, 1.0)
const COLOR_SELECTED := Color(0.0, 1.0, 0.3, 1.0)
const WIDTH_DEFAULT := 2.0
const WIDTH_HOVER := 4.0

@export var next_scene: PackedScene

@export_group("Dialog Texts")
@export_multiline var book_text: String = "Ein Forschungsjournal... der letzte Eintrag erwähnt seltsame seismische Messwerte."
@export_multiline var chocolate_text: String = "Eine Tasse heiße Schokolade. Irgendwie noch warm."
@export_multiline var heater_text: String = "Ein tragbarer Heizstrahler. Er läuft schon eine Weile."
@export_multiline var monitors_text: String = "Stationsmonitore zeigen Wetter- und Seismikdaten. Irgendetwas stimmt nicht..."
@export_multiline var tablet_text: String = "Ein Tablet mit Expeditionsnotizen. Die Crew ist überstürzt aufgebrochen."

var _objects: Array[Dictionary] = []
var _time := 0.0
var _finished := false
var _skip_pressed := false
var _active_dialog: Node = null

@onready var _skip_label: Label = $UI/SkipLabel
@onready var _hint_label: Label = $UI/HintLabel
@onready var _start_button: Button = $UI/StartButton


func _ready() -> void:
	var object_data := [
		{node = $Book, text = book_text},
		{node = $Chocolate, text = chocolate_text},
		{node = $Heater, text = heater_text},
		{node = $Monitors, text = monitors_text},
		{node = $Tablet, text = tablet_text},
	]
	for data in object_data:
		var sprite: Sprite2D = data.node
		var image := sprite.texture.get_image()
		var mat := ShaderMaterial.new()
		mat.shader = OutlineShader
		mat.set_shader_parameter("outline_color", COLOR_UNSELECTED)
		mat.set_shader_parameter("outline_width", WIDTH_DEFAULT)
		sprite.material = mat
		_objects.append({
			sprite = sprite,
			text = data.text,
			image = image,
			selected = false,
		})


func _process(delta: float) -> void:
	_time += delta
	var mouse_pos := get_global_mouse_position()

	for obj in _objects:
		var mat: ShaderMaterial = obj.sprite.material
		if obj.selected:
			mat.set_shader_parameter("outline_color", COLOR_SELECTED)
			mat.set_shader_parameter("outline_width", WIDTH_DEFAULT)
		elif _is_mouse_over_object(obj, mouse_pos):
			mat.set_shader_parameter("outline_color", COLOR_UNSELECTED)
			mat.set_shader_parameter("outline_width", WIDTH_HOVER)
		else:
			var alpha := 0.5 + 0.3 * sin(_time * 3.0)
			mat.set_shader_parameter("outline_color", Color(COLOR_UNSELECTED, alpha))
			mat.set_shader_parameter("outline_width", WIDTH_DEFAULT)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(get_global_mouse_position())
		return

	if not event.is_pressed() or event.is_echo():
		return
	if _skip_pressed:
		_go_to_next_scene()
	else:
		_skip_pressed = true
		_skip_label.visible = true
		get_tree().create_timer(1.5).timeout.connect(_reset_skip)


func _handle_click(global_pos: Vector2) -> void:
	for i in range(_objects.size() - 1, -1, -1):
		var obj = _objects[i]
		if obj.selected:
			continue
		if _is_mouse_over_object(obj, global_pos):
			_select_object(obj)
			return


func _is_mouse_over_object(obj: Dictionary, global_pos: Vector2) -> bool:
	var sprite: Sprite2D = obj.sprite
	var local_pos := sprite.to_local(global_pos)
	var image: Image = obj.image
	var tex_size := Vector2(image.get_width(), image.get_height())
	var pixel_pos := local_pos + tex_size / 2.0
	if pixel_pos.x < 0 or pixel_pos.y < 0:
		return false
	if pixel_pos.x >= tex_size.x or pixel_pos.y >= tex_size.y:
		return false
	var pixel := image.get_pixel(int(pixel_pos.x), int(pixel_pos.y))
	return pixel.a > 0.1


func _select_object(obj: Dictionary) -> void:
	obj.selected = true
	_show_dialog(obj.text)
	_check_all_selected()


func _show_dialog(text: String) -> void:
	if is_instance_valid(_active_dialog):
		_active_dialog.dismiss()
	var dialog := DialogTextScene.instantiate()
	get_tree().current_scene.add_child(dialog)
	dialog.show_text(text)
	_active_dialog = dialog
	dialog.tree_exited.connect(func(): _active_dialog = null)


func _check_all_selected() -> void:
	for obj in _objects:
		if not obj.selected:
			return
	_hint_label.visible = false
	_start_button.visible = true
	_start_button.pressed.connect(_go_to_next_scene)


func _reset_skip() -> void:
	_skip_pressed = false
	_skip_label.visible = false


func _go_to_next_scene() -> void:
	if _finished:
		return
	_finished = true
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
