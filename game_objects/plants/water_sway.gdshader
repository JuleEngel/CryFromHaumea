shader_type canvas_item;

uniform float sway_amplitude : hint_range(0.0, 20.0) = 6.0;
uniform float sway_speed : hint_range(0.0, 5.0) = 1.5;
uniform float sway_frequency : hint_range(0.0, 10.0) = 2.0;

void vertex() {
	// Sway increases from bottom (UV.y=1) to top (UV.y=0)
	float mask = 1.0 - UV.y;
	float sway = sin(TIME * sway_speed + UV.y * sway_frequency * TAU) * sway_amplitude;
	VERTEX.x += sway * mask * mask;
}
