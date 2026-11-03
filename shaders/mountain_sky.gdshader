shader_type sky;
// A sky with a huge mountain range all around the horizon, for big maps. It's part of the sky,
// so it's infinitely far away: free to draw, never pops in, and never covers anything in the world.
// Three ranges, farthest first: each farther one is paler and bluer (haze), and the tallest peaks
// carry snow. Low-poly peaks (straight slopes) to match the retro look. No texture needed.

uniform vec3 sky_top : source_color = vec3(0.38, 0.58, 0.78);
uniform vec3 sky_horizon : source_color = vec3(0.74, 0.82, 0.7);
uniform vec3 ground_color : source_color = vec3(0.2, 0.28, 0.16);
uniform vec3 far_range : source_color = vec3(0.6, 0.68, 0.76);
uniform vec3 mid_range : source_color = vec3(0.44, 0.52, 0.6);
uniform vec3 near_range : source_color = vec3(0.3, 0.38, 0.36);
uniform vec3 snow : source_color = vec3(0.93, 0.95, 0.98);
uniform float height = 1.0; // Scales every range (1 = peaks about 20 degrees up).

// Sharp, uneven peaks from a few triangle waves: straight slopes like low-poly mountains.
float tri(float x) {
	return abs(fract(x) - 0.5) * 2.0;
}

float ridge(float azimuth, float seed, float scale) {
	float a = azimuth / 6.2831853;
	float h = 0.55 * (1.0 - tri(a * 5.0 + seed));
	h += 0.3 * (1.0 - tri(a * 11.0 + seed * 1.7));
	h += 0.15 * (1.0 - tri(a * 23.0 + seed * 2.3));
	return h * scale * height;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float elevation = asin(clamp(dir.y, -1.0, 1.0));
	float azimuth = atan(dir.x, -dir.z) + 3.14159265;
	float up = clamp(dir.y, 0.0, 1.0);
	vec3 color = mix(sky_horizon, sky_top, pow(up, 0.6));
	if (elevation < 0.0) {
		color = ground_color;
	}
	// A simple sun disc where the scene's sun is.
	if (LIGHT0_ENABLED) {
		float sun = dot(dir, LIGHT0_DIRECTION);
		color = mix(color, vec3(1.0, 0.96, 0.85), smoothstep(0.9994, 0.9997, sun));
	}
	// Farthest range: tall, pale, snowy.
	float far_h = 0.05 + ridge(azimuth, 0.13, 0.32);
	if (elevation < far_h) {
		color = far_range;
		if (elevation > far_h - 0.045 && far_h > 0.22) {
			color = mix(far_range, snow, 0.85);
		}
	}
	// Middle range.
	float mid_h = 0.03 + ridge(azimuth, 0.57, 0.2);
	if (elevation < mid_h) {
		color = mid_range;
		if (elevation > mid_h - 0.025 && mid_h > 0.15) {
			color = mix(mid_range, snow, 0.7);
		}
	}
	// Nearest range: low, dark, forested hills.
	float near_h = 0.015 + ridge(azimuth, 0.91, 0.08);
	if (elevation < near_h) {
		color = near_range;
	}
	COLOR = color;
}
