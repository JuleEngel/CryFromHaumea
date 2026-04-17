extends Node2D

const DialogTextScene := preload("res://ui_scenes/dialog_text/dialog_text.tscn")
const OutlineShader := preload("res://levels/cutscenes/base_station/outline.gdshader")
const CUTSCENE_MUSIC := preload("res://audio/music/exploration_track.ogg")
const CUTSCENE_ENV := preload("res://levels/cutscenes/cutscene_environment.tres")

const COLOR_UNSELECTED := Color(1.0, 0.85, 0.0, 1.0)
const COLOR_SELECTED := Color(0.0, 1.0, 0.3, 1.0)
const WIDTH_DEFAULT := 2.0
const WIDTH_HOVER := 4.0

@export var next_scene: PackedScene

@export_group("Dialog Texts")
@export_multiline var book_text: String = "Ein Forschungsjournal... der letzte Eintrag erwähnt, dass aus der Schlucht ein seltsames Signal empfangen wurde. Und auch die seismischen Messwerte wirken anders als erwartet."
@export_multiline var chocolate_text: String = "Eine Tasse heiße Schokolade. Naja, sie war jedenfalls mal heiß. Ob das noch schmeckt?"
@export_multiline var heater_text: String = "Ein tragbarer Heizstrahler. Er läuft schon eine Weile. Bei einem Eisplaneten wäre dieser Heizstrahl auch meine erste Wahl!"
@export_multiline var monitors_text: String = "Stationsmonitore zeigen Wetter- und Seismikdaten. Irgendetwas stimmt nicht..."
@export_multiline var tablet_text: String = "Ein Tablet mit Expeditionsnotizen. Der Pilot ist wohl überstürzt aufgebrochen."
@export_multiline var base_station_text: String = "Es ist niemand hier. Ich sollte mich ein wenig umsehen."
@export_multiline var mission_start_text: String = "Hier werde ich nichts mehr finden. Nach Logbuch wollte der Pilot die Spalte im Eis genauer erkunden. Die Stelle, von der die seltsamen Signale kamen.\n\n Wenn ich den Piloten finden möchte, muss ich mich wohl auch in die Tiefe begeben. Zum Glück kann mein kleines Raumschiff auch unter Wasser fahren..."

var _objects: Array[Dictionary] = []
var _time := 0.0
var _finished := false
var _skip_pressed := false
var _active_dialog: Node = null
var _fade_overlay: ColorRect
var _music_player: AudioStreamPlayer
var _all_hints_shown := false

@onready var _skip_label: Label = $UI/SkipLabel
@onready var _hint_label: Label = $UI/HintLabel
@onready var _start_button: Button = $UI/StartButton


func _ready() -> void:
	_show_dialog(base_station_text)
	
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

	_create_fade_overlay()
	_create_world_environment()
	_start_music()
	# Fade in from black
	create_tween().tween_property(_fade_overlay, "color:a", 0.0, 1.0)


func _start_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = CUTSCENE_MUSIC
	_music_player.volume_db = -40.0
	add_child(_music_player)
	_music_player.play()
	create_tween().tween_property(_music_player, "volume_db", 0.0, 1.5)


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

	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		return

	if _skip_pressed:
		_go_to_next_scene()
	else:
		_skip_pressed = true
		_skip_label.visible = true
		get_tree().create_timer(1.5).timeout.connect(_reset_skip)


func _handle_click(global_pos: Vector2) -> void:
	if _active_dialog != null:
		_active_dialog.queue_free()
		_active_dialog = null
	elif _all_hints_shown:
		_fade_in_label(_start_button)
		_start_button.pressed.connect(_go_to_next_scene)
	else:
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
	_show_dialog(mission_start_text)
	await get_tree().create_timer(0.01).timeout
	_all_hints_shown = true


# -- Fade helpers -----------------------------------------------------------

func _create_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color.BLACK
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_fade_overlay)


func _create_world_environment() -> void:
	var we := WorldEnvironment.new()
	we.environment = CUTSCENE_ENV
	add_child(we)


func _fade_in_label(label: Control) -> void:
	label.modulate.a = 0.0
	label.visible = true
	create_tween().tween_property(label, "modulate:a", 1.0, 0.3)


func _reset_skip() -> void:
	_skip_pressed = false
	_skip_label.visible = false


func _go_to_next_scene() -> void:
	if _finished:
		return
	_finished = true

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_fade_overlay, "color:a", 1.0, 0.5)
	tween.tween_property(_music_player, "volume_db", -40.0, 0.5)
	await tween.finished

	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
