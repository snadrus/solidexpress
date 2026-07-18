shader_type sky;

// Map the workplane (sky horizon) to the bottom of the equirectangular image so
// almost all canyon/sky detail sits above the active plane. The geometric
// underside only samples the stretched nadir strip (little usable detail).

uniform sampler2D source_panorama : filter_linear, source_color, hint_default_black;
uniform float energy_multiplier : hint_range(0.0, 16.0) = 1.0;
/// Vertical fraction of the panorama reserved for below the ground plane.
/// Larger values push the stretched nadir further under the workplane.
uniform float underside_v_frac : hint_range(0.01, 0.50) = 0.32;

void sky() {
	float u = SKY_COORDS.x;
	// SKY_COORDS.y: 0 = zenith, 0.5 = horizon (active plane), 1 = nadir.
	float y = clamp(SKY_COORDS.y, 0.0, 1.0);
	float v;
	if (y <= 0.5) {
		v = (y / 0.5) * (1.0 - underside_v_frac);
	} else {
		float t = (y - 0.5) / 0.5;
		v = (1.0 - underside_v_frac) + t * underside_v_frac;
	}
	COLOR = texture(source_panorama, vec2(u, v)).rgb * energy_multiplier;
}
