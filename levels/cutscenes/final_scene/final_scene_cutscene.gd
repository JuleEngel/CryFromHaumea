extends Node2D

const EXPLORATION_MUSIC := preload("res://audio/music/exploration_track.ogg")
const CUTSCENE_ENV := preload("res://levels/cutscenes/cutscene_environment.tres")

@export var next_scene: PackedScene

@export_group("Glitch Audio")
@export var glitch_audio: AudioStream

@export_group("Dialogs")
## Each line: "A: ..." for Alien (red) or "E: ..." for Eryk (white). One line = one keypress.
@export_multiline var dialog_1: String = "A: Verbindung... hergestellt.\nA: Gedaechtnis... wird ausgelesen."
@export_multiline var dialog_2: String = "A: Erinnerung gefunden.\nA: Ankunft. Neugier. Naivitaet.\nE: Was... was passiert mit mir? Wo bin ich?"
@export_multiline var dialog_3: String = "A: Erinnerung gefunden.\nA: Entdeckung. Angst. Flucht.\nE: Diese Kreaturen... ich erinnere mich..."
@export_multiline var dialog_4: String = "A: Erinnerung gefunden.\nA: Verzweiflung. Hilferuf. Hoffnung.\nE: Der Hilferuf... das war ICH!"
@export_multiline var dialog_5: String = "A: Uebernahme... abgeschlossen.\nA: Neuer Wirt.\nA: Neuer Zyklus.\nE: Nein... NEIN!"
@export_multiline var dialog_6: String = ""
@export_multiline var dialog_7: String = ""
@export_multiline var dialog_8: String = ""
@export_multiline var dialog_9: String = ""

@export_group("Memory Texts")
@export_multiline var cockpit_text: String = "Ein ganz normaler Tag im Weltraum. Ein Hilferuf kam rein. Natuerlich bin ich hingeflogen - das haette jeder getan."
@export_multiline var cave_text: String = "Die Schlucht... Ich erinnere mich an die seltsamen Kreaturen. An das Gefuehl, beobachtet zu werden."
@export_multiline var underwater_text: String = "Die Station bot Schutz. Fuer einen Moment dachte ich, hier waere ich sicher."
@export_multiline var rescue_text: String = "Der Hilferuf... den ich geschrieben habe. Derselbe, den ich empfangen habe. Ein Kreislauf."

@export_group("Outro")
@export_multiline var outro_text: String = "Ein neuer Tag im Weltraum. Ein neuer Tag im Kuiper-Guertel.\n\nAber irgendetwas fuehlt sich anders an. Vertraut. Als haette ich das alles schon einmal erlebt..."
@export var modem_audio: AudioStream

var _skip_pressed := false
var _finished := false
var _waiting_for_input := false
var _dialog_container: VBoxContainer
var _fade_overlay: ColorRect
var _music_player: AudioStreamPlayer

signal _pressed_continue

@onready var _cockpit_bg: Sprite2D = $Backgrounds/CockpitBg
@onready var _cockpit_universe_bg: Sprite2D = $Backgrounds/CockpitUniverseBg
@onready var _cave_bg: Sprite2D = $Backgrounds/CaveBg
@onready var _underwater_bg: Sprite2D = $Backgrounds/UnderwaterBg
@onready var _rescue_bg: Sprite2D = $Backgrounds/RescueBg

@onready var _universe: Sprite2D = $Outro/UniversePure
@onready var _planet: Sprite2D = $Outro/PlanetPure
@onready var _cockpit_overlay: Sprite2D = $Outro/CockpitPixelart

@onready var _glitch_overlay: ColorRect = $UI/GlitchOverlay
@onready var _subtitle_label: Label = $UI/SubtitleLabel
@onready var _subtitle_continue_label: Label = $UI/SubtitleContinueLabel
@onready var _skip_label: Label = $UI/SkipLabel
@onready var _ende_label: Label = $UI/EndeLabel

@onready var _camera: Camera2D = $Camera2D
@onready var _glitch_player: AudioStreamPlayer = $GlitchPlayer
@onready var _sos_label: Label = $ScreenTarget/SOSLabel
@onready var _sos_continue_label: Label = $ScreenTarget/ContinueLabel
@onready var _screen_target: Marker2D = $ScreenTarget

var _all_backgrounds: Array[Sprite2D] = []


func _ready() -> void:
	_all_backgrounds = [_cockpit_bg, _cockpit_universe_bg, _cave_bg, _underwater_bg, _rescue_bg]
	_create_dialog_ui()
	_hide_all()
	_create_fade_overlay()
	_create_world_environment()
	_start_label_pulse(_subtitle_continue_label)
	_start_label_pulse(_sos_continue_label)
	_start_music()
	_run_cutscene()


func _start_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = EXPLORATION_MUSIC
	_music_player.volume_db = -40.0
	add_child(_music_player)
	_music_player.play()
	create_tween().tween_property(_music_player, "volume_db", 0.0, 1.5)


func _create_dialog_ui() -> void:
	_dialog_container = VBoxContainer.new()
	_dialog_container.anchor_left = 0.15
	_dialog_container.anchor_right = 0.85
	_dialog_container.anchor_top = 0.1
	_dialog_container.anchor_bottom = 0.85
	_dialog_container.offset_left = 0
	_dialog_container.offset_right = 0
	_dialog_container.offset_top = 0
	_dialog_container.offset_bottom = 0
	_dialog_container.alignment = BoxContainer.ALIGNMENT_END
	_dialog_container.add_theme_constant_override("separation", 20)
	_dialog_container.clip_contents = true
	_dialog_container.visible = false
	_dialog_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_dialog_container)


func _hide_all() -> void:
	for bg in _all_backgrounds:
		bg.visible = false
	_glitch_overlay.visible = false
	_subtitle_label.visible = false
	_subtitle_continue_label.visible = false
	_ende_label.visible = false
	_sos_label.visible = false
	_sos_continue_label.visible = false
	_universe.visible = false
	_planet.visible = false
	_cockpit_overlay.visible = false
	_dialog_container.visible = false


func _run_cutscene() -> void:
	# Alien intro
	await _transition_to_alien()
	await _do_alien_dialog(dialog_1)

	# Memory 1: Cockpit (with universe behind it)
	await _transition_to_memory(_cockpit_bg, true)
	await _show_memory(cockpit_text)

	# Alien reaction to memory 1
	await _transition_to_alien()
	await _do_alien_dialog(dialog_2)

	# Memory 2: Cave
	await _transition_to_memory(_cave_bg)
	await _show_memory(cave_text)

	# Alien reaction to memory 2
	await _transition_to_alien()
	await _do_alien_dialog(dialog_3)

	# Memory 3: Underwater
	await _transition_to_memory(_underwater_bg)
	await _show_memory(underwater_text)

	# Alien reaction to memory 3
	await _transition_to_alien()
	await _do_alien_dialog(dialog_4)

	# Memory 4: Rescue
	await _transition_to_memory(_rescue_bg)
	await _show_memory(rescue_text)

	# Alien reaction to memory 4
	await _transition_to_alien()
	await _do_alien_dialog(dialog_5)

	# Alien continues
	await _do_alien_dialog(dialog_6)

	# Alien continues
	await _do_alien_dialog(dialog_7)

	# Alien continues
	await _do_alien_dialog(dialog_8)
	
	# Final alien scene
	await _do_alien_dialog(dialog_9)

	# Longer transition to outro
	await _transition_to_outro()
	await _run_outro()

	_go_to_next_scene()


# -- Transitions ---------------------------------------------------------------

func _do_glitch_effect() -> void:
	if glitch_audio:
		_glitch_player.stream = glitch_audio
		_glitch_player.play()

	_glitch_overlay.visible = true

	# Mystical matrix-like glitch: subtle alpha pulses with faint green tint
	for i in range(10):
		var alpha := randf_range(0.15, 0.85)
		var green := randf_range(0.0, 0.05)
		_glitch_overlay.color = Color(0.0, green, 0.0, alpha)
		await get_tree().create_timer(0.05 + randf() * 0.1).timeout

	# Settle to solid black
	_glitch_overlay.color = Color.BLACK


func _transition_to_alien() -> void:
	_subtitle_label.visible = false
	_subtitle_continue_label.visible = false

	await _do_glitch_effect()

	_hide_all_backgrounds()
	await get_tree().create_timer(0.3).timeout


func _transition_to_memory(bg: Sprite2D, show_universe: bool = false) -> void:
	_dialog_container.visible = false

	await _do_glitch_effect()
	_glitch_player.stop()

	# Prepare memory background behind the black overlay
	_hide_all_backgrounds()
	if show_universe:
		_cockpit_universe_bg.visible = true
	bg.visible = true

	# Soft fade: black overlay fades out to reveal memory
	_glitch_overlay.color = Color.BLACK
	var tween := create_tween()
	tween.tween_property(_glitch_overlay, "color:a", 0.0, 2.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	_glitch_overlay.visible = false


func _transition_to_outro() -> void:
	# Fade out dialog messages slowly
	if _dialog_container.visible:
		var tween := create_tween()
		tween.tween_property(_dialog_container, "modulate:a", 0.0, 2.0)
		await tween.finished
	_dialog_container.visible = false
	_dialog_container.modulate.a = 1.0

	_glitch_player.stop()

	# Brief black pause
	_glitch_overlay.visible = true
	_glitch_overlay.color = Color.BLACK
	await get_tree().create_timer(2.0).timeout

	# Prepare outro: cockpit + universe + moon visible in window
	_hide_all_backgrounds()
	_universe.visible = true
	_planet.visible = true
	_planet.position = Vector2(960, 450)
	_planet.scale = Vector2(0.3, 0.3)
	_cockpit_overlay.visible = true

	# Slow fade in to outro
	var tween2 := create_tween()
	tween2.tween_property(_glitch_overlay, "color:a", 0.0, 3.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween2.finished
	_glitch_overlay.visible = false


# -- Alien dialog (chat-like) --------------------------------------------------

func _do_alien_dialog(dialog_text: String) -> void:
	# Clear previous messages
	for child in _dialog_container.get_children():
		child.queue_free()

	_dialog_container.visible = true

	var lines := dialog_text.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue

		var speaker := ""
		var message := line
		if line.begins_with("A: "):
			speaker = "A"
			message = line.substr(3)
		elif line.begins_with("E: "):
			speaker = "E"
			message = line.substr(3)

		_add_dialog_message(speaker, message)
		await get_tree().process_frame

		_fade_in_label(_subtitle_continue_label)
		await _wait_for_input()
		_subtitle_continue_label.visible = false


func _add_dialog_message(speaker: String, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 28)

	if speaker == "A":
		label.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	else:
		label.add_theme_color_override("font_color", Color.WHITE)

	# Fade in the message
	label.modulate.a = 0.0
	_dialog_container.add_child(label)
	create_tween().tween_property(label, "modulate:a", 1.0, 0.4)


# -- Memory pages --------------------------------------------------------------

func _show_memory(text: String) -> void:
	if text.is_empty():
		return

	var pages := text.split("\n\n")
	for page in pages:
		var t := page.strip_edges()
		if t.is_empty():
			continue
		_subtitle_label.text = t
		_fade_in_label(_subtitle_label)
		_fade_in_label(_subtitle_continue_label)
		await _wait_for_input()
		_subtitle_continue_label.visible = false
	_subtitle_label.visible = false


func _hide_all_backgrounds() -> void:
	for bg in _all_backgrounds:
		bg.visible = false


# -- Outro ---------------------------------------------------------------------

func _run_outro() -> void:
	# Start slow moon approach from the very beginning (runs in background)
	var moon_tween := create_tween()
	moon_tween.tween_property(_planet, "scale", Vector2(1.5, 1.5), 60.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# Outro text
	if not outro_text.is_empty():
		var pages := outro_text.split("\n\n")
		for page in pages:
			var t := page.strip_edges()
			if t.is_empty():
				continue
			_subtitle_label.text = t
			_fade_in_label(_subtitle_label)
			_fade_in_label(_subtitle_continue_label)
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
	_fade_in_label(_sos_continue_label)
	await _sos_label.wait_for_input()
	_sos_continue_label.visible = false

	# Zoom back out
	_sos_label.visible = false
	var center := Vector2(960, 540)
	var tween2 := create_tween().set_parallel(true)
	tween2.tween_property(_camera, "global_position", center, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween2.tween_property(_camera, "zoom", Vector2.ONE, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween2.finished

	# Stop slow approach, accelerate moon from current scale
	moon_tween.kill()
	var fast_tween := create_tween()
	fast_tween.tween_property(_planet, "scale", Vector2(5.0, 5.0), 10.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	await fast_tween.finished

	# Fade to black
	_glitch_overlay.visible = true
	_glitch_overlay.color = Color(0, 0, 0, 0)
	var tween4 := create_tween()
	tween4.tween_property(_glitch_overlay, "color", Color.BLACK, 3.0)
	await tween4.finished

	# Brief pause
	await get_tree().create_timer(1.5).timeout

	# ENDE fades in slowly and stays longer
	_ende_label.modulate.a = 0.0
	_ende_label.visible = true
	var tween5 := create_tween()
	tween5.tween_property(_ende_label, "modulate:a", 1.0, 3.0) \
		.set_ease(Tween.EASE_IN_OUT)
	await tween5.finished
	await get_tree().create_timer(6.0).timeout


# -- Input / skip --------------------------------------------------------------

func _wait_for_input() -> void:
	_waiting_for_input = true
	await _pressed_continue
	_waiting_for_input = false


func _input(event: InputEvent) -> void:
	if not _waiting_for_input:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode != KEY_ESCAPE:
		_pressed_continue.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_pressed_continue.emit()
		get_viewport().set_input_as_handled()


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


# -- Fade helpers -----------------------------------------------------------

func _create_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0, 0, 0, 0)
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


func _start_label_pulse(label: Label) -> void:
	var base_color := Color(0.7, 0.7, 0.7, 1.0)
	var pulse_color := Color(1.0, 0.85, 0.2, 1.0)
	var tween := create_tween().set_loops()
	tween.tween_property(label, "theme_override_colors/font_color", pulse_color, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "theme_override_colors/font_color", base_color, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


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
