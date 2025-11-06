shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float distortion_strength : hint_range(0.0, 5.0) = 2.0;
uniform float spiral_strength : hint_range(0.0, 2.0) = 0.8;

varying vec2 sphere_center_screen; // Screen position of sphere center
varying float vertex_distance_normalized; // Distance from vertex to center in model space (0-1)

void vertex() {
	// Calculate sphere center in screen space (origin of model)
	vec4 center_clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	sphere_center_screen = (center_clip.xy / center_clip.w) * 0.5 + 0.5;

	// Calculate distance in MODEL SPACE (before scaling)
	// This makes the falloff independent of the sphere's scale
	// VERTEX is in model space, so length(VERTEX) gives distance from origin
	vertex_distance_normalized = length(VERTEX);
}

void fragment() {
	vec2 screen_uv = SCREEN_UV;

	// Calculate distance from this pixel to the sphere's center on screen
	vec2 to_center = screen_uv - sphere_center_screen;
	float screen_dist = length(to_center);

	// Use model-space distance for scale-independent falloff
	// vertex_distance_normalized is already 0 at center, 1 at sphere surface
	// This makes the effect consistent regardless of sphere scale

	// Very smooth radial falloff - imperceptible edge transition
	// Key: Remap the range so distortion reaches near-zero BEFORE mesh edge
	// Map 0.0-0.8 to 1.0-0.0, so the last 20% of sphere has almost no distortion
	float adjusted_dist = vertex_distance_normalized / 0.85; // Start fading at 85% radius
	float radial_mask = 1.0 - clamp(adjusted_dist, 0.0, 1.0);
	radial_mask = smoothstep(0.0, 1.0, radial_mask); // First smooth curve
	radial_mask = smoothstep(0.0, 1.0, radial_mask); // Second smooth curve for extra softness
	radial_mask = pow(radial_mask, 3.5); // Very steep falloff near edges

	// Create spiral distortion
	vec2 radial_dir = normalize(to_center); // Direction away from center
	vec2 tangent_dir = vec2(-radial_dir.y, radial_dir.x); // Perpendicular (creates rotation)

	// Combine radial pull with spiral rotation
	// Spiral is stronger at center (where radial_mask is higher)
	vec2 distort_dir = radial_dir + (tangent_dir * spiral_strength * radial_mask);
	distort_dir = normalize(distort_dir);

	// Apply distortion with stronger multiplier at center
	// radial_mask keeps soft edges, but distortion_strength amplifies center effect
	vec2 distortion_offset = distort_dir * radial_mask * distortion_strength * 0.15;

	// Sample screen with distortion - using nearest mipmap to reduce shimmer
	vec3 screen_color = texture(SCREEN_TEXTURE, screen_uv + distortion_offset).rgb;

	ALBEDO = screen_color;
	ALPHA = 1.0;
}
