extends CanvasLayer

const SECONDS_PER_CHAR := 0.045
const MIN_DISPLAY_TIME := 2.0
const FADE_DURATION := 0.4

@onready var label: Label = %DialogLabel
@onready var panel: PanelContainer = %Panel

func _ready() -> void:
	panel.modulate.a = 0.0

func show_text(text: String) -> void:
	label.text = text
	var display_time := maxf(text.length() * SECONDS_PER_CHAR, MIN_DISPLAY_TIME)

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_interval(display_time)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(queue_free)


func dismiss() -> void:
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(queue_free)
