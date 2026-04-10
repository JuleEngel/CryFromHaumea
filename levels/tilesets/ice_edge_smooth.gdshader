shader_type canvas_item;

// Per-tile shader: blurs the alpha edges within each tile for softer
// transitions, then adds a glow halo around the ice boundary.

uniform float blur_radius : hint_range(1.0, 8.0) = 5.0;
uniform float glow_radius : hint_range(1.0, 8.0) = 4.0;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.6;
uniform vec4 glow_color : source_color = vec4(0.48, 0.72, 0.88, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;

	float radius = max(blur_radius, glow_radius);

	// Blur alpha and find nearest opaque color in one pass
	float alpha_sum = 0.0;
	float weight_sum = 0.0;
	vec3 nearest_color = tex.rgb;
	float best_cw = 0.0;

	for (float dy = -radius; dy <= radius; dy += 1.0) {
		for (float dx = -radius; dx <= radius; dx += 1.0) {
			float dist = length(vec2(dx, dy));
			if (dist > radius) continue;

			vec4 s = texture(TEXTURE, UV + vec2(dx, dy) * px);

			// Alpha blur with quadratic falloff
			float bw = max(1.0 - dist / blur_radius, 0.0);
			bw *= bw;
			alpha_sum += s.a * bw;
			weight_sum += bw;

			// Track nearest opaque pixel color
			if (s.a > 0.5) {
				float cw = 1.0 - dist / radius;
				cw *= cw;
				if (cw > best_cw) {
					best_cw = cw;
					nearest_color = s.rgb;
				}
			}
		}
	}

	float smooth_alpha = alpha_sum / weight_sum;

	if (tex.a > 0.5) {
		// Opaque ice pixel — blend slightly with blurred alpha for softer edges
		float edge_softness = smoothstep(0.4, 0.8, smooth_alpha);
		COLOR = vec4(tex.rgb, mix(smooth_alpha, tex.a, edge_softness));
	} else if (smooth_alpha > 0.15) {
		// Semi-transparent zone: smoothed ice fill
		float fill = smoothstep(0.15, 0.5, smooth_alpha);
		vec3 col = mix(glow_color.rgb, nearest_color, fill * 0.6 + 0.3);
		COLOR = vec4(col, fill * 0.9);
	} else {
		// Glow halo
		float glow = smoothstep(0.0, 0.15, smooth_alpha) * glow_strength;
		vec3 col = mix(glow_color.rgb, nearest_color, 0.4);
		COLOR = vec4(col, glow);
	}
}
