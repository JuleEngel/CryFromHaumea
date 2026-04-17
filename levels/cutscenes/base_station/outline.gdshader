shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 5.0) = 3.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (tex.a > 0.1) {
		// Interior pixels are invisible (the base image already shows them)
		COLOR = vec4(0.0);
	} else {
		// Find closest opaque neighbor distance for a smooth falloff
		float closest = outline_width + 1.0;
		for (float x = -5.0; x <= 5.0; x += 1.0) {
			for (float y = -5.0; y <= 5.0; y += 1.0) {
				if (abs(x) > outline_width || abs(y) > outline_width) {
					continue;
				}
				vec2 offset = vec2(x, y) * TEXTURE_PIXEL_SIZE;
				if (texture(TEXTURE, UV + offset).a > 0.1) {
					closest = min(closest, length(vec2(x, y)));
				}
			}
		}
		float glow = 1.0 - smoothstep(0.0, outline_width, closest);
		COLOR = vec4(outline_color.rgb, glow * outline_color.a);
	}
}
