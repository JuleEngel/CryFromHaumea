class_name TriggerOrb
extends Area2D

signal collected

enum Action {
	SPEECH_TEXT,
	INFO_SCREEN,
}

const DialogTextScene := preload("res://ui_scenes/dialog_text/dialog_text.tscn")
const InfoScreenScene := preload("res://ui_scenes/info_screen/info_screen.tscn")

@export var action: Action = Action.SPEECH_TEXT
@export_multiline var text: String = "Hallo, Entdecker!"
@export var image: Texture2D
@export var one_shot := true
@export var set_invisible := false
@export var required_for_next_level := false

var _triggered := false
var _time := 0.0

@onready var glow_light: PointLight2D = $GlowLight
@onready var pickup_sound: AudioStreamPlayer2D = $PickupSound
@onready var sparkle_particles: CPUParticles2D = $SparkleParticles
@onready var core_glow: CPUParticles2D = $CoreGlow

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visible = not(set_invisible)

func _process(delta: float) -> void:
	_time += delta
	glow_light.energy = 4.5 + 2.5 * sin(_time * 2.5)
	glow_light.texture_scale = 14.0 + 4.0 * sin(_time * 2.5)

func _on_body_entered(body: Node2D) -> void:
	if one_shot and _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	pickup_sound.play()
	_execute_action(body)
	collected.emit()
	if one_shot:
		_burst_and_free()

func _execute_action(body: Node2D) -> void:
	match action:
		Action.SPEECH_TEXT:
			_show_speech_text()
		Action.INFO_SCREEN:
			_show_info_screen(body, image)

func _burst_and_free() -> void:
	glow_light.visible = false
	core_glow.emitting = false
	sparkle_particles.one_shot = true
	sparkle_particles.explosiveness = 1.0
	sparkle_particles.amount = 40
	sparkle_particles.initial_velocity_min = 40.0
	sparkle_particles.initial_velocity_max = 100.0
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, sparkle_particles.color)
	gradient.add_point(0.6, sparkle_particles.color)
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(sparkle_particles.color, 0.0))
	sparkle_particles.color_ramp = gradient
	sparkle_particles.restart()
	set_process(false)
	await get_tree().create_timer(sparkle_particles.lifetime, false).timeout
	queue_free()


func _show_speech_text() -> void:
	var dialog := DialogTextScene.instantiate()
	get_tree().current_scene.add_child(dialog)
	dialog.show_text(text)

func _show_info_screen(body: Node2D, img: Texture2D = null) -> void:
	await get_tree().create_timer(0.2).timeout
	var info := InfoScreenScene.instantiate()
	info.info_text = text
	if img:
		info.info_image = img
	get_tree().current_scene.add_child(info)
	info._on_body_entered(body)
