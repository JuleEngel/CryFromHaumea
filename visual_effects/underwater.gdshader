shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float distortion_strength : hint_range(0.0, 0.01) = 0.002;
uniform float distortion_speed : hint_range(0.0, 2.0) = 0.3;
uniform float distortion_scale : hint_range(1.0, 50.0) = 12.0;
uniform float caustic_strength : hint_range(0.0, 0.2) = 0.06;
uniform float caustic_speed : hint_range(0.0, 2.0) = 0.4;
uniform float caustic_scale : hint_range(1.0, 30.0) = 8.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;
uniform vec4 tint_color : source_color = vec4(0.05, 0.12, 0.22, 0.25);
uniform vec2 camera_offset = vec2(0.0);
uniform vec2 screen_pixel_size = vec2(0.0005);
uniform vec2 light_position_screen = vec2(0.5);
uniform vec2 light_direction = vec2(1.0, 0.0);
uniform float light_cone_angle = 0.44; // ~25 degrees in radians
uniform float light_range = 0.4;
uniform float light_intensity : hint_range(0.0, 1.0) = 0.15;
uniform vec4 light_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);

uniform vec2 search_position_screen = vec2(0.5);
uniform vec2 search_direction = vec2(1.0, 0.0);
uniform float search_cone_angle = 0.44;
uniform float search_range = 0.2;
uniform float search_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 search_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);

// Shockwave ripple (texture-based, propagates through water around terrain)
uniform sampler2D shockwave_texture : filter_linear, repeat_disable;
uniform vec2 shockwave_rect_origin = vec2(-2.0);
uniform vec2 shockwave_rect_size = vec2(1.0);
uniform float shockwave_strength : hint_range(0.0, 0.1) = 0.0015;
uniform float shockwave_brightness : hint_range(0.0, 0.5) = 0.04;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float caustics(vec2 uv, float time) {
	float c = 0.0;
	c += noise(uv * caustic_scale + vec2(time, time * 0.7)) * 0.5;
	c += noise(uv * caustic_scale * 1.8 - vec2(time * 0.6, time * 1.1)) * 0.3;
	c += noise(uv * caustic_scale * 3.2 + vec2(time * 0.3, -time * 0.5)) * 0.2;
	return c;
}

void fragment() {
	float time = TIME;

	// World-space UV so effects don't move with camera
	vec2 world_uv = SCREEN_UV + camera_offset * screen_pixel_size;

	// Wavy distortion
	vec2 distorted_uv = SCREEN_UV;
	distorted_uv.x += sin(world_uv.y * distortion_scale + time * distortion_speed) * distortion_strength;
	distorted_uv.y += cos(world_uv.x * distortion_scale * 1.3 + time * distortion_speed * 0.8) * distortion_strength;

	// Shockwave ripple distortion (propagates through water around terrain)
	vec2 shock_uv = (SCREEN_UV - shockwave_rect_origin) / shockwave_rect_size;
	if (shock_uv.x > 0.0 && shock_uv.x < 1.0 && shock_uv.y > 0.0 && shock_uv.y < 1.0) {
		float st = 1.0 / float(textureSize(shockwave_texture, 0).x);
		float wr = texture(shockwave_texture, shock_uv + vec2(st, 0.0)).r;
		float wl = texture(shockwave_texture, shock_uv - vec2(st, 0.0)).r;
		float wu = texture(shockwave_texture, shock_uv + vec2(0.0, st)).r;
		float wd = texture(shockwave_texture, shock_uv - vec2(0.0, st)).r;
		distorted_uv += vec2(wr - wl, wu - wd) * shockwave_strength;
	}

	vec4 screen_color = textureLod(screen_texture, distorted_uv, 0.0);

	// Shockwave visible ring (bright edge at wavefront)
	if (shock_uv.x > 0.0 && shock_uv.x < 1.0 && shock_uv.y > 0.0 && shock_uv.y < 1.0) {
		float wave = texture(shockwave_texture, shock_uv).r;
		screen_color.rgb += vec3(0.6, 0.8, 1.0) * wave * shockwave_brightness;
	}

	// Caustic light patterns
	float c = caustics(world_uv, time * caustic_speed);
	screen_color.rgb += vec3(c * caustic_strength);

	// Deep water tint
	screen_color.rgb = mix(screen_color.rgb, tint_color.rgb, tint_color.a);

	// Headlight cone illumination on the water
	vec2 to_pixel = SCREEN_UV - light_position_screen;
	float dist = length(to_pixel);
	vec2 dir_to_pixel = normalize(to_pixel);
	float angle = acos(clamp(dot(dir_to_pixel, normalize(light_direction)), -1.0, 1.0));
	float in_cone = step(angle, light_cone_angle);
	float angle_fade = 1.0 - smoothstep(light_cone_angle * 0.5, light_cone_angle, angle);
	float dist_fade = 1.0 - smoothstep(0.0, light_range, dist);
	float light = in_cone * angle_fade * dist_fade * dist_fade * light_intensity;
	screen_color.rgb += light_color.rgb * light;

	// Searchlight cone
	vec2 search_to_pixel = SCREEN_UV - search_position_screen;
	float search_dist = length(search_to_pixel);
	vec2 search_dir_to_pixel = normalize(search_to_pixel);
	float search_angle = acos(clamp(dot(search_dir_to_pixel, normalize(search_direction)), -1.0, 1.0));
	float search_in_cone = step(search_angle, search_cone_angle);
	float search_angle_fade = 1.0 - smoothstep(search_cone_angle * 0.5, search_cone_angle, search_angle);
	float search_dist_fade = 1.0 - smoothstep(0.0, search_range, search_dist);
	float search_light = search_in_cone * search_angle_fade * search_dist_fade * search_dist_fade * search_intensity;
	screen_color.rgb += search_color.rgb * search_light;

	// Vignette
	vec2 center = SCREEN_UV - 0.5;
	float vignette = 1.0 - dot(center, center) * vignette_strength * 2.0;
	screen_color.rgb *= vignette;

	COLOR = screen_color;
}
