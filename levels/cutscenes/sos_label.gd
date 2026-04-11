extends Node2D

@export var text: String = "S.O.S."
@export var font_size: int = 32


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, Vector2(-text_size.x / 2.0, text_size.y / 2.0), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
