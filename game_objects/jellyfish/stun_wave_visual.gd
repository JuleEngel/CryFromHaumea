extends Node2D

var radius: float = 0.0
var max_radius: float = 350.0

func _draw() -> void:
	if not visible or radius <= 0.0:
		return
	var alpha := clampf(1.0 - (radius / max_radius), 0.0, 1.0) * 0.6
	var color := Color(1.0, 1.0, 0.3, alpha)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, color, 4.0, true)
	# Inner glow ring
	var inner_alpha := alpha * 0.4
	draw_arc(Vector2.ZERO, radius * 0.85, 0, TAU, 48, Color(1.0, 1.0, 0.5, inner_alpha), 8.0, true)

func _process(_delta: float) -> void:
	var parent := get_parent()
	if parent and "_stun_wave_radius" in parent:
		radius = parent._stun_wave_radius
		max_radius = parent.stun_radius
		queue_redraw()
