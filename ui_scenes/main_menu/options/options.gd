extends VBoxContainer

@onready var music_slide = %Music_Slide
@onready var music_val = %MusicValueLabel
@onready var sound_slide = %Sound_Slide
@onready var sound_val = %SoundValueLabel


func _ready() -> void:
	AudioServer.add_bus(1)
	music_slide.value = get_music_volume() * 100
	sound_slide.value = get_sound_volume() * 100


func get_music_volume():
	return AudioServer.get_bus_volume_linear(0)
	
	
func set_music_volume(value):
	AudioServer.set_bus_volume_linear(0, value)
	
	
func get_sound_volume():
	return AudioServer.get_bus_volume_linear(1)
	
	
func set_sound_volume(value):
	AudioServer.set_bus_volume_linear(1, value)


func _on_sound_slide_value_changed(value: float) -> void:
	sound_val.text = "%d" % (value)
	set_sound_volume(value / 100)


func _on_music_slide_value_changed(value: float) -> void:
	music_val.text = "%d" % (value)
	set_music_volume(value / 100)


func _on_sound_slide_drag_ended(_value_changed: bool) -> void:
	pass
