shader_type canvas_item;

uniform float damage_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float crumble_progress : hint_range(0.0, 1.0) = 0.0;
uniform float cell_scale : hint_range(2.0, 20.0) = 6.0;
uniform float spread : hint_range(0.0, 1.0) = 0.5;
uniform float gravity_strength : hint_range(0.0, 1.0) = 0.3;

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Find the Voronoi cell for a UV position.
// Returns the cell seed point in UV space; cell_grid is the integer grid coordinate.
vec2 voronoi(vec2 uv, out vec2 cell_grid) {
	vec2 scaled = uv * cell_scale;
	vec2 base = floor(scaled);
	vec2 f = fract(scaled);

	float min_dist = 10.0;
	vec2 closest_point = vec2(0.0);
	vec2 closest_cell = vec2(0.0);

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 cell = base + neighbor;
			vec2 jitter = hash22(cell);
			vec2 diff = neighbor + jitter - f;
			float dist = dot(diff, diff);
			if (dist < min_dist) {
				min_dist = dist;
				closest_point = (cell + jitter) / cell_scale;
				closest_cell = cell;
			}
		}
	}

	cell_grid = closest_cell;
	return closest_point;
}

void fragment() {
	vec2 sample_uv = UV;

	if (crumble_progress >= 0.001) {
		// Find which Voronoi cell owns this pixel
		vec2 cell_grid;
		vec2 cell_center = voronoi(UV, cell_grid);

		// Per-cell random direction and spin
		vec2 rnd = hash22(cell_grid + 100.0);
		vec2 dir = normalize(cell_center - vec2(0.5) + (rnd - 0.5) * 0.4);

		float t = crumble_progress * crumble_progress;

		vec2 offset = dir * t * spread;
		offset.y += t * gravity_strength;

		float angle = (rnd.y - 0.5) * 8.0 * t;

		// Reverse transform to find original texel
		vec2 p = UV - cell_center - offset;
		float c = cos(-angle);
		float s = sin(-angle);
		sample_uv = vec2(p.x * c - p.y * s, p.x * s + p.y * c) + cell_center;

		// Verify the reverse-mapped position still belongs to the same cell
		vec2 check_grid;
		voronoi(sample_uv, check_grid);

		if (distance(check_grid, cell_grid) > 0.5
			|| sample_uv.x < 0.0 || sample_uv.x > 1.0
			|| sample_uv.y < 0.0 || sample_uv.y > 1.0) {
			discard;
		}
	}

	vec4 color = texture(TEXTURE, sample_uv);
	if (color.a < 0.01) {
		discard;
	}

	// Desaturation based on damage
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(color.rgb, vec3(gray) * 0.65, damage_ratio);

	// Fade out during crumble
	color.a *= 1.0 - crumble_progress;

	COLOR = color;
}
