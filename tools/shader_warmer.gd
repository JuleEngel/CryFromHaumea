extends Node

## Briefly renders all custom shaders off-screen on startup so that
## their pipelines are compiled before gameplay begins, avoiding stutter.

const SHADERS: Array[String] = [
	"res://game_objects/alien1/swim_wave.gdshader",
	"res://game_objects/rocket/trajectory_dash.gdshader",
	"res://game_objects/iceblock/ice_crumble.gdshader",
	"res://game_objects/plants/water_sway.gdshader",
	"res://visual_effects/underwater.gdshader",
	"res://levels/cutscenes/base_station/outline.gdshader",
	"res://levels/tilesets/ice_edge_smooth.gdshader",
]

var _frames_remaining := 2


func _ready() -> void:
	var canvas := SubViewport.new()
	canvas.size = Vector2i(2, 2)
	canvas.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(canvas)

	for path in SHADERS:
		var shader := load(path) as Shader
		if shader == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var rect := ColorRect.new()
		rect.material = mat
		rect.size = Vector2(1, 1)
		canvas.add_child(rect)


func _process(_delta: float) -> void:
	_frames_remaining -= 1
	if _frames_remaining <= 0:
		queue_free()
