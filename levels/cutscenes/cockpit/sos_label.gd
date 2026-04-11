extends Node2D

@export var text: String = "S.O.S."
@export var font_size: int = 32

var font: Font


func _ready() -> void:
	font = load("res://ui_scenes/fonts/Orbitron-VariableFont_wght.ttf")


func _draw() -> void:
	var resolved_text := text.replace("\\n", "\n")
	var lines := resolved_text.split("\n")
	var line_height := font.get_height(font_size)
	var total_height := line_height * lines.size()
	var y_offset := -total_height / 2.0 + line_height
	for line in lines:
		var text_size := font.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, Vector2(-text_size.x / 2.0, y_offset), line,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		y_offset += line_height
