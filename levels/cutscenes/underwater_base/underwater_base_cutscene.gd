extends Node2D

const COMBAT_MUSIC := preload("res://audio/music/synthwave_combat.mp3")
const CUTSCENE_ENV := preload("res://levels/cutscenes/cutscene_environment.tres")

@export var next_scene: PackedScene

var _skip_pressed := false
var _finished := false
var _fade_overlay: ColorRect
var _music_player: AudioStreamPlayer

@onready var _submarine: Sprite2D = $Submarine
@onready var _landing_target: Marker2D = $LandingTarget
@onready var _skip_label: Label = $UI/SkipLabel
@onready var _dive_player: AudioStreamPlayer = $DiveSoundPlayer


func _ready() -> void:
	#_submarine.position = Vector2(1800, 200)
	_create_fade_overlay()
	_create_world_environment()
	_start_music()
	_run_cutscene()


func _start_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = COMBAT_MUSIC
	_music_player.volume_db = -40.0
	add_child(_music_player)
	_music_player.play()
	create_tween().tween_property(_music_player, "volume_db", 0.0, 1.5)


func _run_cutscene() -> void:
	# Fade in from black
	create_tween().tween_property(_fade_overlay, "color:a", 0.0, 1.0)
	await get_tree().create_timer(0.1).timeout

	_dive_player.play()

	# Animate submarine descending to the base
	var tween := create_tween()
	tween.tween_property(_submarine, "position",
		_landing_target.position, 5.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(_submarine, "scale",
		Vector2.ONE * 0.6, 5.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

	await get_tree().create_timer(0.1).timeout

	_go_to_next_scene()


# -- Skip / navigation ------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
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


func _reset_skip() -> void:
	_skip_pressed = false
	_skip_label.visible = false


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
