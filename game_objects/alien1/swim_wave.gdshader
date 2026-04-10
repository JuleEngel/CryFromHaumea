shader_type canvas_item;

uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.03;
uniform float wave_frequency : hint_range(1.0, 10.0) = 3.0;
uniform float wave_speed : hint_range(0.0, 10.0) = 4.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	// Wave increases toward the tail (UV.x = 0 is head, 1 is tail)
	float wave = sin(UV.x * wave_frequency * TAU - TIME * wave_speed) * wave_amplitude;
	float mask = UV.x * UV.x; // Stronger at the tail
	VERTEX.y += wave * mask * intensity * 100.0;
}
