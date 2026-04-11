shader_type canvas_item;

uniform float dash_count : hint_range(1.0, 50.0) = 15.0;
uniform float dash_ratio : hint_range(0.1, 0.9) = 0.5;

void fragment() {
	float pattern = fract(UV.x * dash_count);
	if (pattern > dash_ratio) {
		discard;
	}
}
