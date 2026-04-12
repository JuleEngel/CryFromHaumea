extends Node2D

@export var next_scene: PackedScene

@export_group("Glitch Audio")
@export var glitch_audio: AudioStream

@export_group("Glitch Texts")
@export_multiline var glitch_text_1: String = "Verbindung... hergestellt. Gedaechtnis... wird ausgelesen."
@export_multiline var glitch_text_2: String = "Erinnerung gefunden. Ankunft. Neugier. Naivitaet."
@export_multiline var glitch_text_3: String = "Erinnerung gefunden. Entdeckung. Angst. Flucht."
@export_multiline var glitch_text_4: String = "Erinnerung gefunden. Verzweiflung. Hilferuf. Hoffnung."
@export_multiline var glitch_text_5: String = "Uebernahme... abgeschlossen. Neuer Wirt. Neuer Zyklus."

@export_group("Memory Texts")
@export_multiline var cockpit_text: String = "Ein ganz normaler Tag im Weltraum. Ein Hilferuf kam rein. Natuerlich bin ich hingeflogen - das haette jeder getan."
@export_multiline var cave_text: String = "Die Schlucht... Ich erinnere mich an die seltsamen Kreaturen. An das Gefuehl, beobachtet zu werden."
@export_multiline var underwater_text: String = "Die Station bot Schutz. Fuer einen Moment dachte ich, hier waere ich sicher."
@export_multiline var rescue_text: String = "Der Hilferuf... den ich geschrieben habe. Derselbe, den ich empfangen habe. Ein Kreislauf."

@export_group("Outro")
@export_multiline var outro_text: String = "Ein neuer Tag im Weltraum. Ein neuer Tag im Kuiper-Guertel.\n\nAber irgendetwas fuehlt sich anders an. Vertraut. Als haette ich das alles schon einmal erlebt..."
@export var engine_audio: AudioStream
@export var modem_audio: AudioStream

var _skip_pressed := false
var _finished := false
var _waiting_for_input := false

signal _pressed_continue

@onready var _cockpit_bg: Sprite2D = $Backgrounds/CockpitBg
@onready var _cave_bg: Sprite2D = $Backgrounds/CaveBg
@onready var _underwater_bg: Sprite2D = $Backgrounds/UnderwaterBg
@onready var _rescue_bg: Sprite2D = $Backgrounds/RescueBg
@onready var _alien_bg: Sprite2D = $Backgrounds/AlienBg

@onready var _universe: Sprite2D = $Outro/UniversePure
@onready var _planet: Sprite2D = $Outro/PlanetPure
@onready var _cockpit_overlay: Sprite2D = $Outro/CockpitPixelart

@onready var _glitch_overlay: ColorRect = $UI/GlitchOverlay
@onready var _glitch_text_label: Label = $UI/GlitchTextLabel
@onready var _subtitle_label: Label = $UI/SubtitleLabel
@onready var _subtitle_continue_label: Label = $UI/SubtitleContinueLabel
@onready var _skip_label: Label = $UI/SkipLabel
@onready var _ende_label: Label = $UI/EndeLabel

@onready var _camera: Camera2D = $Camera2D
@onready var _glitch_player: AudioStreamPlayer = $GlitchPlayer
@onready var _engine_player: AudioStreamPlayer = $EnginePlayer
@onready var _sos_label: Label = $ScreenTarget/SOSLabel
@onready var _sos_continue_label: Label = $ScreenTarget/ContinueLabel
@onready var _screen_target: Marker2D = $ScreenTarget

var _all_backgrounds: Array[Sprite2D] = []


func _ready() -> void:
	_all_backgrounds = [_cockpit_bg, _cave_bg, _underwater_bg, _rescue_bg, _alien_bg]
	_hide_all()
	_run_cutscene()


func _hide_all() -> void:
	for bg in _all_backgrounds:
		bg.visible = false
	_glitch_overlay.visible = false
	_glitch_text_label.visible = false
	_subtitle_label.visible = false
	_subtitle_continue_label.visible = false
	_ende_label.visible = false
	_sos_label.visible = false
	_sos_continue_label.visible = false
	_universe.visible = false
	_planet.visible = false
	_cockpit_overlay.visible = false


func _run_cutscene() -> void:
	await _do_glitch(glitch_text_1)
	await _show_memory(_cockpit_bg, cockpit_text)

	await _do_glitch(glitch_text_2)
	await _show_memory(_cave_bg, cave_text)

	await _do_glitch(glitch_text_3)
	await _show_memory(_underwater_bg, underwater_text)

	await _do_glitch(glitch_text_4)
	await _show_memory(_rescue_bg, rescue_text)

	await _do_glitch(glitch_text_5)

	await _run_outro()

	_go_to_next_scene()


# -- Glitch effect -------------------------------------------------------------

func _do_glitch(text: String) -> void:
	_hide_all_backgrounds()
	_subtitle_label.visible = false
	_subtitle_continue_label.visible = false

	_glitch_overlay.visible = true
	_glitch_overlay.color = Color.BLACK

	if glitch_audio:
		_glitch_player.stream = glitch_audio
		_glitch_player.play()

	# Flicker alien image
	await get_tree().create_timer(0.3).timeout
	for i in range(8):
		_alien_bg.visible = not _alien_bg.visible
		await get_tree().create_timer(0.05 + randf() * 0.1).timeout
	_alien_bg.visible = true

	# Show glitch text page by page
	if not text.is_empty():
		var pages := text.split("\n\n")
		for page in pages:
			var t := page.strip_edges()
			if t.is_empty():
				continue
			_glitch_text_label.text = t
			_glitch_text_label.visible = true
			_subtitle_continue_label.visible = true
			await _wait_for_input()
			_subtitle_continue_label.visible = false
		_glitch_text_label.visible = false

	_alien_bg.visible = false
	_glitch_overlay.visible = false
	_glitch_player.stop()


# -- Memory pages --------------------------------------------------------------

func _show_memory(bg: Sprite2D, text: String) -> void:
	_hide_all_backgrounds()
	bg.visible = true

	if text.is_empty():
		return

	var pages := text.split("\n\n")
	for page in pages:
		var t := page.strip_edges()
		if t.is_empty():
			continue
		_subtitle_label.text = t
		_subtitle_label.visible = true
		_subtitle_continue_label.visible = true
		await _wait_for_input()
		_subtitle_continue_label.visible = false
	_subtitle_label.visible = false


func _hide_all_backgrounds() -> void:
	for bg in _all_backgrounds:
		bg.visible = false


# -- Outro ---------------------------------------------------------------------

func _run_outro() -> void:
	_hide_all_backgrounds()
	_glitch_overlay.visible = false
	_glitch_text_label.visible = false

	# Show cockpit view like in intro
	_universe.visible = true
	_cockpit_overlay.visible = true

	# Outro text
	if not outro_text.is_empty():
		var pages := outro_text.split("\n\n")
		for page in pages:
			var t := page.strip_edges()
			if t.is_empty():
				continue
			_subtitle_label.text = t
			_subtitle_label.visible = true
			_subtitle_continue_label.visible = true
			await _wait_for_input()
			_subtitle_continue_label.visible = false
		_subtitle_label.visible = false

	# SOS on screen - zoom camera to monitor
	_sos_label.visible = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_camera, "global_position",
		_screen_target.global_position, 3.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_camera, "zoom",
		Vector2(1.8, 1.8), 3.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

	if modem_audio:
		_glitch_player.stream = modem_audio
		_glitch_player.play()
	await _sos_label.play_typewriter()
	_glitch_player.stop()
	_sos_continue_label.visible = true
	await _sos_label.wait_for_input()
	_sos_continue_label.visible = false

	# Zoom back out, bring planet into view
	_sos_label.visible = false
	_planet.visible = true

	var center := Vector2(960, 540)
	var planet_offset := _planet.position - _universe.position
	var universe_target := center - planet_offset

	var tween2 := create_tween().set_parallel(true)
	tween2.tween_property(_camera, "global_position", center, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween2.tween_property(_camera, "zoom", Vector2.ONE, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween2.tween_property(_universe, "position", universe_target, 3.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween2.tween_property(_planet, "position", center, 3.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween2.finished

	# Planet approach with shake
	if engine_audio:
		_engine_player.stream = engine_audio
		_engine_player.play()

	_shake_camera(8.0, 2.0, 10.0)

	var tween3 := create_tween()
	tween3.tween_property(_planet, "scale", Vector2(4.0, 4.0), 8.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	await tween3.finished
	_camera.offset = Vector2.ZERO

	# Fade to black
	_glitch_overlay.visible = true
	_glitch_overlay.color = Color(0, 0, 0, 0)
	var tween4 := create_tween()
	tween4.tween_property(_glitch_overlay, "color", Color.BLACK, 2.0)
	await tween4.finished

	# ENDE
	_ende_label.visible = true
	await get_tree().create_timer(4.0).timeout


# -- Camera shake --------------------------------------------------------------

func _shake_camera(duration: float, min_strength: float, max_strength: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		var t := elapsed / duration
		var strength := lerpf(min_strength, max_strength, t * t)
		_camera.offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength),
		)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_camera.offset = Vector2.ZERO


# -- Input / skip --------------------------------------------------------------

func _wait_for_input() -> void:
	_waiting_for_input = true
	await _pressed_continue
	_waiting_for_input = false


func _input(event: InputEvent) -> void:
	if not _waiting_for_input:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_pressed_continue.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_pressed_continue.emit()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
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


func _go_to_next_scene() -> void:
	if _finished:
		return
	_finished = true

	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
