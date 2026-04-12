extends CanvasLayer

const SECONDS_PER_WORD := 0.4
const MIN_DISPLAY_TIME := 2.0
const FADE_DURATION := 0.4
const SEGMENT_SEPARATOR := "<next>"

@onready var label: Label = %DialogLabel
@onready var panel: PanelContainer = %Panel

func _ready() -> void:
	panel.modulate.a = 0.0

func _display_time_for(segment: String) -> float:
	var word_count := segment.split(" ", false).size()
	return maxf(word_count * SECONDS_PER_WORD, MIN_DISPLAY_TIME)

func show_text(text: String) -> void:
	var segments := text.split(SEGMENT_SEPARATOR)
	var tween := create_tween()

	for i in segments.size():
		var segment := segments[i].strip_edges()
		var display_time := _display_time_for(segment)

		if i == 0:
			tween.tween_callback(label.set_text.bind(segment))
			tween.tween_property(panel, "modulate:a", 1.0, FADE_DURATION)
		else:
			tween.tween_property(panel, "modulate:a", 0.0, FADE_DURATION)
			tween.tween_callback(label.set_text.bind(segment))
			tween.tween_property(panel, "modulate:a", 1.0, FADE_DURATION)

		tween.tween_interval(display_time)

	tween.tween_property(panel, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(queue_free)


func dismiss() -> void:
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(queue_free)
