extends Area2D

enum Action {
	SPEECH_TEXT,
}

const DialogTextScene := preload("res://ui_scenes/dialog_text/dialog_text.tscn")

@export var action: Action = Action.SPEECH_TEXT
@export_multiline var speech_text: String = "Hello, explorer!"
@export var one_shot := true

var _triggered := false
var _time := 0.0

@onready var glow_light: PointLight2D = $GlowLight
@onready var pickup_sound: AudioStreamPlayer2D = $PickupSound

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	glow_light.energy = 3.0 + 1.5 * sin(_time * 2.5)
	glow_light.texture_scale = 10.0 + 2.0 * sin(_time * 2.5)

func _on_body_entered(body: Node2D) -> void:
	if one_shot and _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	pickup_sound.play()
	_execute_action()

func _execute_action() -> void:
	match action:
		Action.SPEECH_TEXT:
			_show_speech_text()

func _show_speech_text() -> void:
	var dialog := DialogTextScene.instantiate()
	get_tree().current_scene.add_child(dialog)
	dialog.show_text(speech_text)
