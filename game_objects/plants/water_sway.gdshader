shader_type canvas_item;

global uniform vec2 submarine_position;

uniform float sway_amplitude : hint_range(0.0, 20.0) = 6.0;
uniform float sway_speed : hint_range(0.0, 5.0) = 1.5;
uniform float sway_frequency : hint_range(0.0, 10.0) = 2.0;
uniform float brush_radius : hint_range(50.0, 600.0) = 300.0;
uniform float brush_strength : hint_range(0.0, 60.0) = 30.0;

void vertex() {
	// Sway increases from bottom (UV.y=1) to top (UV.y=0)
	float mask = 1.0 - UV.y;
	float sway = sin(TIME * sway_speed + UV.y * sway_frequency * TAU) * sway_amplitude;
	VERTEX.x += sway * mask * mask;

	// Submarine brush: push plant away when sub is nearby
	vec2 world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float dist = distance(world_pos, submarine_position);
	float brush = 1.0 - clamp(dist / brush_radius, 0.0, 1.0);
	vec2 push_dir = normalize(world_pos - submarine_position + vec2(0.001, 0.0));
	VERTEX.x += push_dir.x * brush * brush * brush_strength * mask * mask;
}
